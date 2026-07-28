-- Refuser la migration sans supprimer de données si des doublons existent.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.planning_templates
    GROUP BY appartement_id, numero_semaine, jour
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Doublons détectés dans planning_templates pour (appartement_id, numero_semaine, jour).';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.taches_jour
    WHERE planning_template_id IS NOT NULL
    GROUP BY planning_template_id, semaine_reelle
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Doublons détectés dans taches_jour pour (planning_template_id, semaine_reelle).';
  END IF;
END
$$;

ALTER TABLE public.planning_templates
ADD CONSTRAINT planning_appartement_semaine_jour_key
UNIQUE (appartement_id, numero_semaine, jour);

-- PostgreSQL autorise plusieurs NULL dans une contrainte UNIQUE :
-- les tâches ajoutées manuellement sans planning_template_id restent permises.
ALTER TABLE public.taches_jour
ADD CONSTRAINT taches_jour_template_date_key
UNIQUE (planning_template_id, semaine_reelle);
