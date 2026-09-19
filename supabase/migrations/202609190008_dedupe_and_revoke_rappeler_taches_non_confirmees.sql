-- ============================================================================
-- rappeler_taches_non_confirmees() : dédoublonnage + retrait des droits publics
-- ============================================================================
-- RISQUES CORRIGÉS
--   1. Exécutable par PUBLIC, anon et authenticated, donc appelable en RPC avec
--      la clé publique de l'application.
--   2. Aucun dédoublonnage : à 12 h et 17 h heure locale, chaque appel
--      insérait une nouvelle notification « Rappel » par employé, sans limite.
--      Quiconque appelait la fonction en boucle pendant ces heures multipliait
--      les notifications.
--
-- CORRECTIF
--   1. REVOKE EXECUTE de PUBLIC, anon et authenticated (anon hérite de PUBLIC).
--      postgres (propriétaire, utilisateur du job pg_cron
--      rappel-taches-non-confirmees) et service_role conservent le droit :
--      le cron n'est pas affecté.
--   2. Dédoublonnage sur le même principe que notifier_presences_non_confirmees
--      (destinataire, type, entité, JOUR LOCAL America/Toronto), avec UNE
--      précision propre à cette fonction : le rappel a deux créneaux légitimes
--      dans la journée (12 h pour le matin, 17 h pour l'après-midi) qui ont
--      le même destinataire, le même type et la même entité. Le créneau est
--      donc distingué par l'HEURE LOCALE d'envoi : il y a au plus un rappel
--      par employé, par jour local et par créneau. Le rappel de 17 h n'est
--      pas bloqué par celui de 12 h.
--
--   Granularité : la notification est AGRÉGÉE (« Vous avez N tâches non
--   confirmées… », entity_id = l'employé), il n'existe pas de notification
--   par tâche. Le dédoublonnage est donc par employé / créneau / jour, pas par
--   tâche : c'est ce que la structure actuelle permet sans nouveau mécanisme.
--
-- NON MODIFIÉ (comportement inchangé au-delà de ce qui est décrit) : fenêtre
-- horaire 12 h / 17 h, sélection des tâches, texte du message, SECURITY
-- INVOKER, absence de search_path.
--
-- ============================================================================
-- DEUX DÉFAUTS PRÉEXISTANTS, VOLONTAIREMENT NON CORRIGÉS ICI
-- ============================================================================
-- La fonction ÉCHOUE à chaque passage à 12 h et 17 h depuis sa création
-- (cron.job_run_details : erreur à chaque passage, aucune notification
-- « Rappel » n'a jamais été créée). Le dédoublonnage ci-dessous est donc en
-- place mais ne produira d'effet qu'une fois ces deux défauts corrigés :
--
--   a) « tj.periode = v_periode » : periode_type (enum) comparé à du texte
--      -> ERROR: operator does not exist: periode_type = text.
--      Correction d'une ligne : « tj.periode::text = v_periode ».
--
--   b) L'entity_type 'TachesJour' n'existe pas dans l'enum entity_type
--      (valeurs : TacheJour, Appartement, PlanningTemplate, Memo, Chat,
--      Transfert, Demande, Presence, Employe, Resident).
--      Correction d'une ligne : 'TacheJour'.
--
-- Corriger a) et b) fera envoyer pour la première fois de vrais rappels aux
-- employés à 12 h et 17 h : c'est un changement de comportement visible, à
-- décider séparément. Cette migration n'y touche pas.
--
-- Le filtre « tj.semaine_reelle = CURRENT_DATE » utilise la date UTC ; à 12 h
-- et 17 h heure locale elle coïncide avec la date locale, en été comme en
-- hiver (voir 202609190004). Non modifié.
--
-- POUR ANNULER : recréer la fonction sans le bloc NOT EXISTS et
--   GRANT EXECUTE ON FUNCTION public.rappeler_taches_non_confirmees()
--   TO PUBLIC, anon, authenticated;  (déconseillé)
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
    'TachesJour'
  FROM public.taches_jour tj
  WHERE tj.semaine_reelle = CURRENT_DATE
    AND tj.periode = v_periode
    AND tj.statut = 'NonCommencé'
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

REVOKE EXECUTE ON FUNCTION public.rappeler_taches_non_confirmees()
  FROM PUBLIC, anon, authenticated;
