-- ============================================================================
-- Planification mensuelle de l'archivage : archive_old_historique()
-- ============================================================================
-- CONTEXTE
--   archive_old_historique() supprime les lignes de plus d'un an de
--   historique_actions ET de notifications. Elle n'était planifiée nulle part :
--   l'archivage n'a jamais eu lieu automatiquement. Son droit d'exécution
--   public a été retiré par 202609190007 ; le job pg_cron s'exécute en tant que
--   postgres, qui conserve ce droit.
--
-- TÂCHE PG_CRON (heures en UTC ; pg_cron de Supabase tourne en GMT)
--   cleanops-archive-historique   « 0 8 1 * * »
--   Le 1er de chaque mois à 08:00 UTC, soit 04:00 (heure d'été) ou 03:00
--   (heure d'hiver) à Toronto, avant le début de journée. La fonction compare
--   des dates avec NOW() et un intervalle d'un an : elle ne dépend d'aucun
--   fuseau, aucun contrôle d'heure locale n'est nécessaire.
--
-- CONSERVATION (décision du responsable du projet : activer)
--   Un an, pour l'historique d'actions ET pour les notifications. Aucune ligne
--   n'a un an aujourd'hui (le projet date de mai 2026) : le premier effet réel
--   ne peut se produire qu'à partir de mai 2027.
--
-- Même schéma que 202607290002 et 202609190001 : le job du même nom est
-- remplacé, jamais dupliqué.
--
-- POUR DÉSACTIVER : SELECT cron.unschedule('cleanops-archive-historique');
-- ============================================================================

DO $$
DECLARE
  v_job_id bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    FOR v_job_id IN
      SELECT jobid FROM cron.job WHERE jobname = 'cleanops-archive-historique'
    LOOP
      PERFORM cron.unschedule(v_job_id);
    END LOOP;

    PERFORM cron.schedule(
      'cleanops-archive-historique',
      '0 8 1 * *',
      'SELECT public.archive_old_historique();'
    );
  END IF;
END
$$;
