-- ============================================================================
-- Page profil : chacun change son identifiant (slug) et son mot de passe
-- ============================================================================
-- OBJECTIF
--   Depuis « Mon profil », un employé (préposée, responsable, Réception) peut :
--   - changer son IDENTIFIANT de connexion (slug) ;
--   - changer son MOT DE PASSE, sauf la préposée : elle se connecte avec son
--     numéro de pointeuse, que seul un administrateur modifie.
--   Les résidents (table residents, connexion par appartement + PIN) ne sont
--   pas concernés.
--
-- SÉCURITÉ
--   Les deux changements exigent le code ACTUEL de la personne (mot de passe,
--   ou numéro de pointeuse pour la préposée), vérifié ici en bcrypt : un
--   appel avec le seul identifiant d'un autre employé ne suffit pas.
--   Le nouveau mot de passe est haché par le déclencheur existant
--   employees_hash_credentials (migration 202607280003).
--
-- RÉSULTAT (texte) : 'ok', ou la raison du refus pour un message clair :
--   'code'     code actuel incorrect (ou compte inactif / introuvable)
--   'format'   nouvelle valeur au mauvais format
--   'pris'     identifiant déjà utilisé par un autre employé
--   'interdit' mot de passe demandé pour une préposée
--
-- ⚠ LIMITES : comme les fonctions de connexion, pas de limitation du nombre
--   de tentatives (sujet déjà signalé).
--
-- POUR ANNULER :
--   DROP FUNCTION public.changer_identifiant(uuid, text, text);
--   DROP FUNCTION public.changer_mot_de_passe(uuid, text, text);
-- ============================================================================

-- Vérifie le code actuel d'un employé actif, selon son rôle.
CREATE OR REPLACE FUNCTION public._code_employe_valide(
  p_employee public.employees,
  p_code text
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SET search_path = public, extensions
AS $$
DECLARE
  v_hash text := CASE WHEN p_employee.role::text = 'Employé'
    THEN p_employee.numero_pointeuse
    ELSE p_employee.mot_de_passe
  END;
BEGIN
  IF NOT p_employee.is_actif
     OR coalesce(v_hash, '') = ''
     OR coalesce(p_code, '') = ''
  THEN
    RETURN false;
  END IF;
  RETURN extensions.crypt(p_code, v_hash) = v_hash;
END;
$$;

REVOKE ALL ON FUNCTION public._code_employe_valide(public.employees, text)
  FROM PUBLIC, anon, authenticated;

-- ── Identifiant ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.changer_identifiant(
  p_employee_id uuid,
  p_code text,
  p_nouveau_slug text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_employee public.employees%ROWTYPE;
  v_slug text := lower(trim(coalesce(p_nouveau_slug, '')));
BEGIN
  SELECT * INTO v_employee FROM public.employees WHERE id = p_employee_id;
  IF NOT FOUND OR NOT public._code_employe_valide(v_employee, p_code) THEN
    RETURN 'code';
  END IF;

  -- Lettres minuscules et chiffres, comme les identifiants créés par l'app.
  IF v_slug !~ '^[a-z0-9]{3,30}$' THEN
    RETURN 'format';
  END IF;

  IF v_slug = v_employee.slug THEN
    RETURN 'ok';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.employees
    WHERE slug = v_slug AND id <> p_employee_id
  ) THEN
    RETURN 'pris';
  END IF;

  UPDATE public.employees
  SET slug = v_slug, date_mise_a_jour = now()
  WHERE id = p_employee_id;
  RETURN 'ok';
EXCEPTION
  WHEN unique_violation THEN
    RETURN 'pris';
END;
$$;

-- ── Mot de passe ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.changer_mot_de_passe(
  p_employee_id uuid,
  p_ancien text,
  p_nouveau text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_employee public.employees%ROWTYPE;
BEGIN
  SELECT * INTO v_employee FROM public.employees WHERE id = p_employee_id;
  IF NOT FOUND OR NOT public._code_employe_valide(v_employee, p_ancien) THEN
    RETURN 'code';
  END IF;

  -- La préposée n'a pas de mot de passe : son code est le numéro de
  -- pointeuse, réservé à l'administrateur.
  IF v_employee.role::text = 'Employé' THEN
    RETURN 'interdit';
  END IF;

  -- Même format que l'écran de connexion : 8 chiffres.
  IF coalesce(p_nouveau, '') !~ '^[0-9]{8}$' THEN
    RETURN 'format';
  END IF;

  UPDATE public.employees
  SET mot_de_passe = p_nouveau, date_mise_a_jour = now()
  WHERE id = p_employee_id;
  RETURN 'ok';
END;
$$;

REVOKE ALL ON FUNCTION public.changer_identifiant(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.changer_mot_de_passe(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.changer_identifiant(uuid, text, text)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.changer_mot_de_passe(uuid, text, text)
  TO anon, authenticated;
