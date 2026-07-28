-- Une session de niveau 2 doit appartenir à exactement une identité.
-- Les sessions de niveau 1 peuvent rester sans employee_id ni resident_id.
ALTER TABLE public.sessions
ADD CONSTRAINT sessions_level_two_exactly_one_identity
CHECK (
  niveau_auth <> 2
  OR ((employee_id IS NOT NULL)::integer + (resident_id IS NOT NULL)::integer = 1)
);
