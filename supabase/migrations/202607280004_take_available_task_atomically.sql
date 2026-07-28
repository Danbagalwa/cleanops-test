CREATE OR REPLACE FUNCTION public.take_available_task(
  p_tache_disponible_id uuid,
  p_employee_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tache_jour_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.employees
    WHERE id = p_employee_id
      AND is_actif = true
      AND role::text = 'Employé'
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'Employé invalide ou inactif.';
  END IF;

  UPDATE public.taches_disponibles
  SET statut = 'Prise',
      prise_par = p_employee_id,
      date_prise = now()
  WHERE id = p_tache_disponible_id
    AND statut::text = 'Disponible'
    AND (
      visibilite::text = 'TouteEquipe'
      OR employee_visible_id = p_employee_id
    )
    AND (date_expiration IS NULL OR date_expiration >= current_date)
  RETURNING tache_jour_id INTO v_tache_jour_id;

  IF v_tache_jour_id IS NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'Cette tâche n''est plus disponible.';
  END IF;

  UPDATE public.taches_jour
  SET employee_id = p_employee_id,
      is_transfert_temp = true,
      date_mise_a_jour = now()
  WHERE id = v_tache_jour_id
    AND employee_id <> p_employee_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'Cette tâche ne peut pas être prise en charge.';
  END IF;

  RETURN p_tache_disponible_id;
END;
$$;

REVOKE ALL ON FUNCTION public.take_available_task(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.take_available_task(uuid, uuid)
TO anon, authenticated;
