-- ============================================================================
-- authenticate_employee() : Réception n'est plus un « responsable »
-- ============================================================================
-- PROBLÈME
--   Le mode « responsable » (p_is_responsable = true) acceptait tout rôle
--   différent de 'Employé' : Admin, Direction, SuperviseurMenage, Employeur ET
--   Reception. Une personne en Réception pouvait donc se connecter par le
--   parcours « Responsable » et obtenir toutes les permissions associées.
--
-- CORRECTIF (une valeur ajoutée à une liste d'exclusion)
--   Le mode « responsable » exclut désormais 'Reception' en plus de 'Employé'.
--   La Réception se connecte par sa propre fonction, authenticate_reception()
--   (migration 202609190017).
--
-- ⚠ EFFET APRÈS APPLICATION
--   Un compte Réception ne peut plus se connecter par le parcours « Responsable ».
--   Aucun compte Réception n'existe aujourd'hui (7 Employé et 1 Admin en base),
--   donc aucun utilisateur n'est affecté. Tant que l'écran de connexion n'offre
--   pas de parcours Réception, ce rôle ne peut pas se connecter du tout : c'est
--   voulu (accès fermé par défaut).
--
-- INCHANGÉ : mode « préposée » (Employé uniquement, numéro de pointeuse), objet
-- JSON renvoyé, hachage bcrypt, SECURITY DEFINER, search_path, droits
-- (CREATE OR REPLACE conserve l'ACL), signature.
--
-- POUR ANNULER : remettre « role::text <> 'Employé' » dans la première
-- condition (déconseillé : cela redonne l'accès responsable à la Réception).
-- ============================================================================

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
      (p_is_responsable AND role::text NOT IN ('Employé', 'Reception'))
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
