-- ============================================================================
-- rappeler_taches_non_confirmees() : ne plus compter les tâches libérées
-- ============================================================================
-- RÈGLE MÉTIER (décision du responsable du projet)
--   Une préposée déclarée absente CONTINUE de recevoir ses rappels tant qu'il
--   lui reste des tâches non transférées à une autre préposée. Mais une tâche
--   LIBÉRÉE à l'équipe (elle attend dans le pool) n'est plus la sienne : elle
--   ne doit ni apparaître dans sa liste, ni être comptée dans son rappel.
--
-- PROBLÈME
--   L'écran « Ma Journée » masque déjà les tâches du pool
--   (taches_disponibles.statut = 'Disponible'), mais le rappel, lui, les
--   comptait tant que personne ne les avait prises (employee_id reste celui de
--   la préposée jusqu'à la prise). Résultat : « Vous avez 3 tâches non
--   confirmées » alors que sa liste n'en montre que 2.
--
-- CORRECTIF (une condition ajoutée, rien d'autre)
--   Exclure du comptage les tâches qui figurent dans le pool avec le statut
--   'Disponible' : c'est exactement le critère de l'écran.
--     * 'Prise'   : employee_id a déjà changé (take_available_task) : la tâche
--                   est comptée pour la préposée qui l'a prise, pas pour
--                   l'ancienne. Non exclue ici, donc bien comptée pour la nouvelle.
--     * 'Expiree' : la tâche redevient visible dans la liste de la préposée
--                   (l'écran ne masque que 'Disponible') : elle est donc de
--                   nouveau comptée. Cohérent avec l'affichage.
--
-- INCHANGÉ : la présence n'est JAMAIS consultée (une absente reçoit toujours
-- son rappel), fenêtre 12 h / 17 h, message, dédoublonnage de 202609190008,
-- corrections de 202609190009, SECURITY INVOKER, droits (CREATE OR REPLACE
-- conserve l'ACL {postgres, service_role}), job pg_cron.
--
-- EFFET : ne peut que RÉDUIRE le nombre de rappels ou le nombre annoncé ; cette
-- migration n'en fait partir aucun de nouveau.
--
-- POUR ANNULER : ré-appliquer la version de 202609190009.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rappeler_taches_non_confirmees()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_heure_est integer;
  v_periode text;
  v_date date;
BEGIN
  v_heure_est := EXTRACT(HOUR FROM (now() AT TIME ZONE 'America/Toronto'));
  v_date := (now() AT TIME ZONE 'America/Toronto')::date;

  IF v_heure_est = 12 THEN
    v_periode := 'AM';
  ELSIF v_heure_est = 17 THEN
    v_periode := 'PM';
  ELSE
    RETURN;
  END IF;

  INSERT INTO public.notifications (destinataire_id, type, message, entity_id, entity_type)
  SELECT
    tj.employee_id,
    'Rappel',
    'Vous avez ' || COUNT(*) || ' tâche' || CASE WHEN COUNT(*) > 1 THEN 's' ELSE '' END ||
      ' non confirmée' || CASE WHEN COUNT(*) > 1 THEN 's' ELSE '' END ||
      ' pour ' || CASE WHEN v_periode = 'AM' THEN 'ce matin' ELSE 'cet après-midi' END || '.',
    tj.employee_id,
    'TacheJour'
  FROM public.taches_jour tj
  WHERE tj.semaine_reelle = CURRENT_DATE
    AND tj.periode = v_periode::public.periode_type
    AND tj.statut = 'NonCommencé'
    AND NOT EXISTS (
      SELECT 1
      FROM public.taches_disponibles td
      WHERE td.tache_jour_id = tj.id
        AND td.statut = 'Disponible'
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.notifications n
      WHERE n.destinataire_id = tj.employee_id
        AND n.type::text = 'Rappel'
        AND n.entity_id = tj.employee_id
        AND (n.date_envoi AT TIME ZONE 'America/Toronto')::date = v_date
        AND EXTRACT(HOUR FROM (n.date_envoi AT TIME ZONE 'America/Toronto')) = v_heure_est
    )
  GROUP BY tj.employee_id;
END;
$$;
