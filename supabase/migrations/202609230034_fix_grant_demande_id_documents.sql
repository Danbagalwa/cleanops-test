-- ============================================================================
-- Correctif : accorder SELECT sur demande_id (documents des demandes équipe)
-- ============================================================================
-- BUG : la migration 202609230033 accordait SELECT (nom, type_mime, taille,
--   ajoute_le) sur demandes_equipe_documents, mais oubliait demande_id — la
--   colonne utilisée par PostgREST pour la jointure avec demandes_equipe.
--   Résultat : toute requête qui liste ou crée une demande d'équipe avec le
--   document embarqué échouait avec 42501 « permission denied for table
--   demandes_equipe_documents », affiché à l'utilisateur comme « Cette action
--   n'est pas disponible pour votre profil » (lib/core/errors/user_friendly_
--   error.dart, catégorie permission).
--
-- POUR ANNULER :
--   REVOKE SELECT (demande_id) ON public.demandes_equipe_documents FROM anon, authenticated;
-- ============================================================================

GRANT SELECT (demande_id) ON public.demandes_equipe_documents TO anon, authenticated;
