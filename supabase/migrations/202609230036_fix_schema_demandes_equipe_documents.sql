-- ============================================================================
-- Correctif : demandes_equipe_documents avait encore l'ancien schéma
-- ============================================================================
-- BUG : la migration 202609230033 visait à remplacer l'ancienne table
--   (contenu bytea + taille GENERATED ALWAYS AS (octet_length(contenu))) par
--   la nouvelle (Storage + métadonnées seulement, taille en colonne normale).
--   Mais son "CREATE TABLE IF NOT EXISTS" ne fait rien quand la table existe
--   déjà — l'ancien schéma est resté en place. Résultat : chaque appel à
--   enregistrer_document_demande échouait avec 428C9 « cannot insert a
--   non-DEFAULT value into column "taille" » (colonne générée), affiché à
--   l'utilisateur comme « Nous n'avons pas pu terminer cette action ».
--
--   Aucune ligne n'existait dans la table (elle n'a jamais fonctionné), donc
--   aucune donnée à migrer.
-- ============================================================================

ALTER TABLE public.demandes_equipe_documents
  ALTER COLUMN taille DROP EXPRESSION;

ALTER TABLE public.demandes_equipe_documents
  DROP CONSTRAINT IF EXISTS demandes_equipe_documents_taille;

ALTER TABLE public.demandes_equipe_documents
  DROP COLUMN IF EXISTS contenu;

ALTER TABLE public.demandes_equipe_documents
  ALTER COLUMN taille SET NOT NULL;

ALTER TABLE public.demandes_equipe_documents
  ADD CONSTRAINT demandes_equipe_documents_taille
  CHECK (taille BETWEEN 1 AND 5242880);
