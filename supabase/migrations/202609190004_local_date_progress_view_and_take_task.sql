-- ============================================================================
-- Date du jour en heure locale (America/Toronto) au lieu de CURRENT_DATE (UTC)
-- ============================================================================
-- PROBLÈME
-- CURRENT_DATE / current_date sont évalués dans le fuseau de la session, qui
-- est UTC sur ce projet. La date bascule donc au lendemain à 20:00 heure du
-- Québec en été (UTC-4) et à 19:00 en hiver (UTC-5), au lieu de minuit. Le
-- décalage passe de 4 h à 5 h au changement d'heure du 1er novembre : le
-- comportement change alors sans qu'aucune ligne de code ne bouge.
--
-- CORRECTIF
-- Même mécanisme que generer_taches_semaine, reset_aires_communes_auto et
-- notifier_presences_non_confirmees :
--     (now() AT TIME ZONE 'America/Toronto')::date
-- Seule l'expression de la date change ; le reste de chaque objet est identique.
--
-- OBJETS CORRIGÉS (les deux sont réellement utilisés par l'application)
--   1. vue_progression_jour   — lue par le tableau de bord du responsable
--      (employer_dashboard_datasource). « Aujourd'hui » basculait à 20:00 / 19:00
--      locale : le soir, la progression affichait le lendemain (vide).
--   2. take_available_task    — appelée par « Tâches disponibles »
--      (tache_disponible_datasource). Une tâche disponible dont
--      date_expiration = aujourd'hui devenait impossible à prendre dès
--      20:00 / 19:00 au lieu de minuit.
--
-- OBJETS VOLONTAIREMENT NON MODIFIÉS
--   * get_semaine_courante, reset_aire_commune_semaine : aucun appelant (ni
--     Dart, ni SQL, ni cron, ni trigger). Fonctions mortes, non corrigées.
--   * vue_taches_aujourd_hui : aucun appelant, et son filtre est
--     date_trunc('week', CURRENT_DATE), c'est-à-dire le LUNDI de la semaine et
--     non la date du jour (défaut de logique, pas seulement de fuseau). Vue
--     morte, non corrigée : décision à prendre séparément.
--   * rappeler_taches_non_confirmees : utilise aussi CURRENT_DATE, mais aux
--     heures locales 12 h et 17 h (16:00–22:00 UTC) où la date UTC est celle du
--     Québec, en été comme en hiver. Non modifiée.
--
-- CREATE OR REPLACE conserve propriétaire, droits et options des objets.
-- Aucune donnée n'est touchée.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Progression du jour (colonnes, types et ordre inchangés)
-- ----------------------------------------------------------------------------
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
  WHERE e.role = 'Employé'::public.role_type AND e.is_actif = true
  GROUP BY e.id, e.prenom;


-- ----------------------------------------------------------------------------
-- Prise d'une tâche disponible : l'expiration se compte en jours locaux
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.take_available_task(
  p_tache_disponible_id uuid,
  p_employee_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tache_jour_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.employees
    WHERE id = p_employee_id
      AND is_actif = true
      AND role::text = 'Employé'
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'Employé invalide ou inactif.';
  END IF;

  UPDATE public.taches_disponibles
  SET statut = 'Prise',
      prise_par = p_employee_id,
      date_prise = now()
  WHERE id = p_tache_disponible_id
    AND statut::text = 'Disponible'
    AND (
      visibilite::text = 'TouteEquipe'
      OR employee_visible_id = p_employee_id
    )
    AND (
      date_expiration IS NULL
      OR date_expiration >= (now() AT TIME ZONE 'America/Toronto')::date
    )
  RETURNING tache_jour_id INTO v_tache_jour_id;

  IF v_tache_jour_id IS NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'Cette tâche n''est plus disponible.';
  END IF;

  UPDATE public.taches_jour
  SET employee_id = p_employee_id,
      is_transfert_temp = true,
      date_mise_a_jour = now()
  WHERE id = v_tache_jour_id
    AND employee_id <> p_employee_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'Cette tâche ne peut pas être prise en charge.';
  END IF;

  RETURN p_tache_disponible_id;
END;
$$;
