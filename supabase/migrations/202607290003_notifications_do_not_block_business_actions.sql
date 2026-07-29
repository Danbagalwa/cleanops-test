-- Une notification est un effet secondaire : son échec ne doit jamais
-- annuler une opération métier valide (planning, présence, transfert, etc.).

CREATE OR REPLACE FUNCTION public.app_notifier_employee(
  p_employee_id uuid,
  p_type text,
  p_message text,
  p_entity_id uuid,
  p_entity_type text DEFAULT 'Tache'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_employee_id IS NULL OR EXISTS (
    SELECT 1
    FROM public.notifications n
    WHERE n.destinataire_id = p_employee_id
      AND n.type::text = p_type
      AND n.entity_id IS NOT DISTINCT FROM p_entity_id
      AND n.date_envoi > now() - interval '10 seconds'
  ) THEN
    RETURN;
  END IF;

  BEGIN
    EXECUTE format(
      'INSERT INTO public.notifications
        (destinataire_id, type, message, entity_id, entity_type, is_lue)
       VALUES ($1, %L, $2, $3, %L, false)',
      p_type,
      p_entity_type
    )
    USING p_employee_id, p_message, p_entity_id;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Notification employé ignorée (%): %', SQLSTATE, SQLERRM;
  END;
END
$$;

CREATE OR REPLACE FUNCTION public.app_notifier_resident(
  p_resident_id uuid,
  p_tache_id uuid,
  p_type text,
  p_message text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_resident_id IS NULL OR EXISTS (
    SELECT 1
    FROM public.notifications_residents n
    WHERE n.resident_id = p_resident_id
      AND n.type::text = p_type
      AND n.tache_jour_id IS NOT DISTINCT FROM p_tache_id
      AND n.date_envoi > now() - interval '10 seconds'
  ) THEN
    RETURN;
  END IF;

  BEGIN
    EXECUTE format(
      'INSERT INTO public.notifications_residents
        (resident_id, tache_jour_id, type, message, is_lue)
       VALUES ($1, $2, %L, $3, false)',
      p_type
    )
    USING p_resident_id, p_tache_id, p_message;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Notification résident ignorée (%): %', SQLSTATE, SQLERRM;
  END;
END
$$;
