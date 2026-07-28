DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.droits_acces
    GROUP BY role, action
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Doublons détectés dans droits_acces pour (role, action).';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.appartements
    WHERE numero IS NULL OR btrim(numero) = ''
  ) THEN
    RAISE EXCEPTION
      'Des appartements possèdent un numéro NULL ou vide.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.demandes_equipe
    WHERE date_fin IS NOT NULL AND date_fin < date_debut
  ) THEN
    RAISE EXCEPTION
      'Des demandes_equipe possèdent une date_fin antérieure à date_debut.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.taches_disponibles
    WHERE date_expiration IS NOT NULL
      AND date_expiration < date_liberation::date
  ) THEN
    RAISE EXCEPTION
      'Des taches_disponibles expirent avant leur date de libération.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.sessions
    WHERE niveau_auth = 2 AND date_expiration IS NULL
  ) THEN
    RAISE EXCEPTION
      'Des sessions de niveau 2 ne possèdent aucune date_expiration.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.sessions
    WHERE date_expiration IS NOT NULL
      AND date_expiration <= date_connexion
  ) THEN
    RAISE EXCEPTION
      'Des sessions expirent avant ou au moment de leur connexion.';
  END IF;
END
$$;

ALTER TABLE public.appartements
ALTER COLUMN numero SET NOT NULL;

DO $$
BEGIN
  -- Une contrainte UNIQUE crée aussi un index portant ce nom.
  IF to_regclass('public.droits_acces_role_action_key') IS NULL THEN
    ALTER TABLE public.droits_acces
    ADD CONSTRAINT droits_acces_role_action_key
    UNIQUE (role, action);
  ELSIF NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'droits_acces_role_action_key'
      AND indexdef LIKE 'CREATE UNIQUE INDEX%'
  ) THEN
    RAISE EXCEPTION
      'droits_acces_role_action_key existe mais ne constitue pas un index unique.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.appartements'::regclass
      AND conname = 'appartements_numero_non_vide'
  ) THEN
    ALTER TABLE public.appartements
    ADD CONSTRAINT appartements_numero_non_vide
    CHECK (btrim(numero) <> '');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.demandes_equipe'::regclass
      AND conname = 'demandes_equipe_dates_valides'
  ) THEN
    ALTER TABLE public.demandes_equipe
    ADD CONSTRAINT demandes_equipe_dates_valides
    CHECK (date_fin IS NULL OR date_fin >= date_debut);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.taches_disponibles'::regclass
      AND conname = 'taches_disponibles_dates_valides'
  ) THEN
    ALTER TABLE public.taches_disponibles
    ADD CONSTRAINT taches_disponibles_dates_valides
    CHECK (
      date_expiration IS NULL
      OR date_expiration >= date_liberation::date
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.sessions'::regclass
      AND conname = 'sessions_level_two_expiration_required'
  ) THEN
    ALTER TABLE public.sessions
    ADD CONSTRAINT sessions_level_two_expiration_required
    CHECK (niveau_auth <> 2 OR date_expiration IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.sessions'::regclass
      AND conname = 'sessions_expiration_after_login'
  ) THEN
    ALTER TABLE public.sessions
    ADD CONSTRAINT sessions_expiration_after_login
    CHECK (date_expiration IS NULL OR date_expiration > date_connexion);
  END IF;
END
$$;
