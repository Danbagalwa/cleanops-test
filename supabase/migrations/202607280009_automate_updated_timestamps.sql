CREATE OR REPLACE FUNCTION public.set_date_mise_a_jour()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.date_mise_a_jour := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS config_set_date_mise_a_jour ON public.config;
CREATE TRIGGER config_set_date_mise_a_jour
BEFORE UPDATE ON public.config
FOR EACH ROW
EXECUTE FUNCTION public.set_date_mise_a_jour();

DROP TRIGGER IF EXISTS employees_set_date_mise_a_jour ON public.employees;
CREATE TRIGGER employees_set_date_mise_a_jour
BEFORE UPDATE ON public.employees
FOR EACH ROW
EXECUTE FUNCTION public.set_date_mise_a_jour();

DROP TRIGGER IF EXISTS appartements_set_date_mise_a_jour
ON public.appartements;
CREATE TRIGGER appartements_set_date_mise_a_jour
BEFORE UPDATE ON public.appartements
FOR EACH ROW
EXECUTE FUNCTION public.set_date_mise_a_jour();

DROP TRIGGER IF EXISTS planning_templates_set_date_mise_a_jour
ON public.planning_templates;
CREATE TRIGGER planning_templates_set_date_mise_a_jour
BEFORE UPDATE ON public.planning_templates
FOR EACH ROW
EXECUTE FUNCTION public.set_date_mise_a_jour();

DROP TRIGGER IF EXISTS taches_jour_set_date_mise_a_jour
ON public.taches_jour;
CREATE TRIGGER taches_jour_set_date_mise_a_jour
BEFORE UPDATE ON public.taches_jour
FOR EACH ROW
EXECUTE FUNCTION public.set_date_mise_a_jour();

DROP TRIGGER IF EXISTS residents_set_date_mise_a_jour ON public.residents;
CREATE TRIGGER residents_set_date_mise_a_jour
BEFORE UPDATE ON public.residents
FOR EACH ROW
EXECUTE FUNCTION public.set_date_mise_a_jour();
