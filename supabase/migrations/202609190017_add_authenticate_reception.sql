-- ============================================================================
-- authenticate_reception() : connexion dédiée au rôle Réception
-- ============================================================================
-- CONTEXTE
--   Depuis 202609190016, authenticate_employee() n'accepte plus la Réception.
--   Cette fonction lui donne son propre parcours, sur le modèle du parcours
--   « responsable » : identifiant (slug) + mot de passe, vérifiés côté serveur
--   (bcrypt, comme authenticate_employee).
--
-- COMPORTEMENT
--   Renvoie l'objet employé (mêmes champs que authenticate_employee) si un
--   employé ACTIF de rôle 'Reception' correspond au slug ET que le mot de passe
--   est correct. Renvoie NULL dans tous les autres cas, sans distinguer « slug
--   inconnu », « mauvais rôle », « compte inactif » et « mot de passe faux ».
--   Un compte Admin, Direction, Employé, etc. ne peut PAS se connecter par cette
--   fonction.
--
-- ⚠ NON UTILISÉE PAR L'APPLICATION POUR L'INSTANT
--   L'écran de connexion n'a pas encore de parcours Réception (décision de
--   destination en attente). La fonction est préparée, testée, sans effet sur
--   les parcours existants.
--
-- DROITS : même schéma que les autres fonctions d'authentification (retrait de
-- PUBLIC, exécution accordée à anon et authenticated, requise avant connexion).
-- Comme elles, elle n'a pas de limitation de tentatives : sujet de sécurité
-- séparé, déjà signalé.
--
-- POUR ANNULER : DROP FUNCTION public.authenticate_reception(text, text);
-- ============================================================================

CREATE OR REPLACE FUNCTION public.authenticate_reception(
  p_slug text,
  p_credential text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_employee public.employees%ROWTYPE;
BEGIN
  SELECT * INTO v_employee
  FROM public.employees
  WHERE slug = p_slug
    AND is_actif = true
    AND role::text = 'Reception'
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_employee.mot_de_passe IS NULL
     OR extensions.crypt(p_credential, v_employee.mot_de_passe)
        <> v_employee.mot_de_passe
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

REVOKE ALL ON FUNCTION public.authenticate_reception(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.authenticate_reception(text, text)
  TO anon, authenticated;
