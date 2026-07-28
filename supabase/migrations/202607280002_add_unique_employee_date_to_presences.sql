-- Requis par l'upsert Flutter avec onConflict: 'employee_id,date'.
-- La migration s'arrête sans modifier les données si des doublons existent.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.presences
    GROUP BY employee_id, date
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Impossible d''ajouter presences_employee_date_key : des doublons existent pour (employee_id, date).';
  END IF;
END
$$;

ALTER TABLE public.presences
ADD CONSTRAINT presences_employee_date_key
UNIQUE (employee_id, date);
