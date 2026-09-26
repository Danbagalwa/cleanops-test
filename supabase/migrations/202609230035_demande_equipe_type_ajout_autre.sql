-- ============================================================================
-- Type de demande équipe : ajout de "Autre"
-- ============================================================================
-- OBJECTIF
--   Une préposée peut avoir une raison qui n'est ni un congé ni une absence
--   planifiée. Ajoute une troisième valeur à l'énumération demande_equipe_type.
--
-- ⚠ Postgres n'autorise pas de retirer une valeur d'un type ENUM : pas de
--   « POUR ANNULER » simple ici (il faudrait recréer le type).
-- ============================================================================

ALTER TYPE public.demande_equipe_type ADD VALUE IF NOT EXISTS 'Autre';
