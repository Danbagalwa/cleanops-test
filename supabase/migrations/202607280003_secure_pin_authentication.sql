CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Hacher les identifiants existants. Les valeurs déjà hachées sont conservées.
UPDATE public.config
SET valeur = extensions.crypt(valeur, extensions.gen_salt('bf', 12))
WHERE cle = 'pin_residence'
  AND valeur !~ '^\$2[aby]\$';

UPDATE public.employees
SET numero_pointeuse = extensions.crypt(
      numero_pointeuse,
      extensions.gen_salt('bf', 12)
    )
WHERE numero_pointeuse IS NOT NULL
  AND numero_pointeuse <> ''
  AND numero_pointeuse !~ '^\$2[aby]\$';

UPDATE public.employees
SET mot_de_passe = extensions.crypt(
      mot_de_passe,
      extensions.gen_salt('bf', 12)
    )
WHERE mot_de_passe IS NOT NULL
  AND mot_de_passe <> ''
  AND mot_de_passe !~ '^\$2[aby]\$';

UPDATE public.residents
SET pin_hash = extensions.crypt(pin_hash, extensions.gen_salt('bf', 12))
WHERE pin_hash IS NOT NULL
  AND pin_hash <> ''
  AND pin_hash !~ '^\$2[aby]\$';

ALTER TABLE public.residents
ADD COLUMN IF NOT EXISTS has_pin boolean
GENERATED ALWAYS AS (pin_hash IS NOT NULL AND pin_hash <> '') STORED;

-- Hacher automatiquement toute nouvelle valeur écrite par l'application.
CREATE OR REPLACE FUNCTION public.hash_employee_credentials()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF NEW.numero_pointeuse IS NOT NULL
     AND NEW.numero_pointeuse <> ''
     AND NEW.numero_pointeuse !~ '^\$2[aby]\$'
     AND (TG_OP = 'INSERT' OR NEW.numero_pointeuse IS DISTINCT FROM OLD.numero_pointeuse)
  THEN
    NEW.numero_pointeuse :=
      extensions.crypt(NEW.numero_pointeuse, extensions.gen_salt('bf', 12));
  END IF;

  IF NEW.mot_de_passe IS NOT NULL
     AND NEW.mot_de_passe <> ''
     AND NEW.mot_de_passe !~ '^\$2[aby]\$'
     AND (TG_OP = 'INSERT' OR NEW.mot_de_passe IS DISTINCT FROM OLD.mot_de_passe)
  THEN
    NEW.mot_de_passe :=
      extensions.crypt(NEW.mot_de_passe, extensions.gen_salt('bf', 12));
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS employees_hash_credentials ON public.employees;
CREATE TRIGGER employees_hash_credentials
BEFORE INSERT OR UPDATE OF numero_pointeuse, mot_de_passe
ON public.employees
FOR EACH ROW
EXECUTE FUNCTION public.hash_employee_credentials();

CREATE OR REPLACE FUNCTION public.hash_resident_pin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF NEW.pin_hash IS NOT NULL
     AND NEW.pin_hash <> ''
     AND NEW.pin_hash !~ '^\$2[aby]\$'
     AND (TG_OP = 'INSERT' OR NEW.pin_hash IS DISTINCT FROM OLD.pin_hash)
  THEN
    NEW.pin_hash :=
      extensions.crypt(NEW.pin_hash, extensions.gen_salt('bf', 12));
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS residents_hash_pin ON public.residents;
CREATE TRIGGER residents_hash_pin
BEFORE INSERT OR UPDATE OF pin_hash
ON public.residents
FOR EACH ROW
EXECUTE FUNCTION public.hash_resident_pin();

CREATE OR REPLACE FUNCTION public.hash_residence_pin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF NEW.cle = 'pin_residence'
     AND NEW.valeur <> ''
     AND NEW.valeur !~ '^\$2[aby]\$'
     AND (
       TG_OP = 'INSERT'
       OR NEW.valeur IS DISTINCT FROM OLD.valeur
       OR NEW.cle IS DISTINCT FROM OLD.cle
     )
  THEN
    NEW.valeur :=
      extensions.crypt(NEW.valeur, extensions.gen_salt('bf', 12));
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS config_hash_residence_pin ON public.config;
CREATE TRIGGER config_hash_residence_pin
BEFORE INSERT OR UPDATE OF cle, valeur
ON public.config
FOR EACH ROW
EXECUTE FUNCTION public.hash_residence_pin();

-- Niveau 1 : ne renvoie que le résultat de la vérification.
CREATE OR REPLACE FUNCTION public.verify_residence_access(
  p_id_residence text,
  p_pin_residence text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_id text;
  v_pin_hash text;
BEGIN
  SELECT valeur INTO v_id
  FROM public.config
  WHERE cle = 'id_residence';

  SELECT valeur INTO v_pin_hash
  FROM public.config
  WHERE cle = 'pin_residence';

  RETURN v_id IS NOT NULL
    AND v_pin_hash IS NOT NULL
    AND v_id = p_id_residence
    AND extensions.crypt(p_pin_residence, v_pin_hash) = v_pin_hash;
END;
$$;

-- Niveau 2 employé : vérifie côté serveur et ne renvoie aucun secret.
CREATE OR REPLACE FUNCTION public.authenticate_employee(
  p_slug text,
  p_credential text,
  p_is_responsable boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_employee public.employees%ROWTYPE;
  v_hash text;
BEGIN
  SELECT * INTO v_employee
  FROM public.employees
  WHERE slug = p_slug
    AND is_actif = true
    AND (
      (p_is_responsable AND role::text <> 'Employé')
      OR
      (NOT p_is_responsable AND role::text = 'Employé')
    )
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  v_hash := CASE
    WHEN p_is_responsable THEN v_employee.mot_de_passe
    ELSE v_employee.numero_pointeuse
  END;

  IF v_hash IS NULL
     OR extensions.crypt(p_credential, v_hash) <> v_hash
  THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'id', v_employee.id,
    'nom', v_employee.nom,
    'prenom', v_employee.prenom,
    'slug', v_employee.slug,
    'role', v_employee.role,
    'is_actif', v_employee.is_actif,
    'nom_residence', v_employee.nom_residence,
    'date_creation', v_employee.date_creation,
    'date_mise_a_jour', v_employee.date_mise_a_jour
  );
END;
$$;

-- Niveau 2 résident : vérifie côté serveur et ne renvoie aucun hash.
CREATE OR REPLACE FUNCTION public.authenticate_resident(
  p_numero_appartement text,
  p_pin text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_resident record;
BEGIN
  SELECT r.*, a.numero AS numero_appartement
  INTO v_resident
  FROM public.residents r
  JOIN public.appartements a ON a.id = r.appartement_id
  WHERE a.numero = p_numero_appartement
    AND r.is_actif = true
  LIMIT 1;

  IF NOT FOUND
     OR v_resident.pin_hash IS NULL
     OR extensions.crypt(p_pin, v_resident.pin_hash) <> v_resident.pin_hash
  THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'id', v_resident.id,
    'nom', v_resident.nom,
    'prenom', v_resident.prenom,
    'numero_appartement', v_resident.numero_appartement
  );
END;
$$;

REVOKE ALL ON FUNCTION public.verify_residence_access(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.authenticate_employee(text, text, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.authenticate_resident(text, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.verify_residence_access(text, text)
TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.authenticate_employee(text, text, boolean)
TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.authenticate_resident(text, text)
TO anon, authenticated;
