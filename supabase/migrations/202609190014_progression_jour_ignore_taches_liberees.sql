-- ============================================================================
-- vue_progression_jour : ne plus compter les tâches libérées à l'équipe
-- ============================================================================
-- RÈGLE MÉTIER (décision du responsable du projet)
--   Une tâche LIBÉRÉE à l'équipe (dans le pool, statut 'Disponible', en attente
--   d'être prise) n'est plus celle de la préposée : elle ne doit ni apparaître
--   dans sa liste ni être comptée pour elle. L'écran « Ma Journée » et les
--   rappels (202609190013) suivent déjà cette règle.
--
-- PROBLÈME
--   vue_progression_jour (progression du jour du responsable) comptait encore
--   ces tâches dans le total et dans les tâches non confirmées de la préposée
--   dont elles restent formellement la propriété (employee_id) jusqu'à leur
--   prise. La progression d'une absente était donc calculée sur des tâches
--   qu'elle ne peut plus voir.
--
-- CORRECTIF (une condition ajoutée à la jointure, rien d'autre)
--   Exclure les tâches présentes dans le pool avec le statut 'Disponible' :
--   même critère que l'écran et que le rappel.
--     * 'Prise'   : employee_id a changé, la tâche est comptée pour la préposée
--                   qui l'a prise.
--     * 'Expiree' : la tâche redevient visible dans la liste, donc comptée.
--
-- ⚠ CONSÉQUENCE POUR LE RESPONSABLE
--   Les tâches libérées non encore prises n'apparaissent plus dans la
--   progression d'AUCUNE préposée : elles sont du travail non fait qui ne figure
--   plus dans ces chiffres tant que personne ne les prend. À garder en tête en
--   lisant le pourcentage.
--
-- INCHANGÉ : colonnes, types et ordre de la vue, date locale
-- (202609190004), droits, propriétaire et options (CREATE OR REPLACE VIEW).
--
-- POUR ANNULER : ré-appliquer la version de 202609190004.
-- ============================================================================

CREATE OR REPLACE VIEW public.vue_progression_jour AS
SELECT e.id AS employee_id,
    e.prenom,
    count(tj.id) AS total_taches,
    count(tj.id) FILTER (WHERE tj.statut <> 'NonCommencé'::public.statut_tache) AS taches_confirmees,
    count(tj.id) FILTER (WHERE tj.statut = 'Fait'::public.statut_tache) AS total_fait,
    count(tj.id) FILTER (WHERE tj.statut = 'Absent'::public.statut_tache) AS total_absent,
    count(tj.id) FILTER (WHERE tj.statut = 'Refus'::public.statut_tache) AS total_refus,
    count(tj.id) FILTER (WHERE tj.statut = 'Annulé'::public.statut_tache) AS total_annule,
    COALESCE(round(count(tj.id) FILTER (WHERE tj.statut <> 'NonCommencé'::public.statut_tache)::numeric * 100.0 / NULLIF(count(tj.id), 0)::numeric, 1), 0::numeric) AS pourcentage
   FROM public.employees e
     LEFT JOIN public.taches_jour tj ON tj.employee_id = e.id
       AND tj.semaine_reelle = (now() AT TIME ZONE 'America/Toronto')::date
       AND NOT EXISTS (
         SELECT 1
         FROM public.taches_disponibles td
         WHERE td.tache_jour_id = tj.id
           AND td.statut = 'Disponible'
       )
  WHERE e.role = 'Employé'::public.role_type AND e.is_actif = true
  GROUP BY e.id, e.prenom;
