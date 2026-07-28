DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.taches_aire_commune
    GROUP BY semaine_date, categorie, zone
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Doublons détectés dans taches_aire_commune pour (semaine_date, categorie, zone).';
  END IF;
END
$$;

ALTER TABLE public.taches_aire_commune
ADD CONSTRAINT aire_commune_semaine_categorie_zone_key
UNIQUE (semaine_date, categorie, zone);
