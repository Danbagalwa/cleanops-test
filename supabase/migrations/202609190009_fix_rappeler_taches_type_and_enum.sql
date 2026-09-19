-- ============================================================================
-- rappeler_taches_non_confirmees() : correction de deux défauts bloquants
-- ============================================================================
-- ⚠ ATTENTION — CHANGEMENT DE COMPORTEMENT VISIBLE
--   Cette fonction n'a JAMAIS fonctionné (aucune notification « Rappel » n'a
--   jamais été créée). Une fois cette migration appliquée, le job pg_cron
--   rappel-taches-non-confirmees (toutes les heures, exécuté par postgres)
--   enverra DE VRAIS RAPPELS aux préposées dès son prochain passage à
--   12 h (tâches du matin) ou 17 h (tâches de l'après-midi), heure locale
--   America/Toronto, pour les tâches encore « NonCommencé » du jour.
--   À n'appliquer qu'après avoir prévenu la porteuse du produit.
--
-- POURQUOI LA FONCTION ÉCHOUAIT À CHAQUE PASSAGE (12 h et 17 h)
--   Le contrôle d'heure (v_heure_est = 12 ou 17) sort de la fonction sans rien
--   faire aux 22 autres heures : l'erreur n'apparaissait donc qu'à 12 h et à
--   17 h, ce qui l'a rendue facile à manquer. cron.job_run_details montre un
--   échec à chacun de ces passages depuis la création du job.
--
--   Défaut 1 — comparaison enum / texte
--     « tj.periode = v_periode » : taches_jour.periode est de type
--     periode_type (enum AM / PM) et v_periode est une variable text.
--     PostgreSQL n'a pas d'opérateur « periode_type = text » :
--     ERROR: operator does not exist: periode_type = text.
--     Correction : « tj.periode = v_periode::public.periode_type ».
--     (v_periode ne vaut jamais que 'AM' ou 'PM' : le cast est sûr et laisse
--     la comparaison porter sur la colonne, sans fonction appliquée dessus.)
--
--   Défaut 2 — valeur d'enum inexistante
--     entity_type reçoit 'TachesJour', qui n'existe pas dans l'enum
--     entity_type (valeurs : TacheJour, Appartement, PlanningTemplate, Memo,
--     Chat, Transfert, Demande, Presence, Employe, Resident).
--     ERROR: invalid input value for enum entity_type: "TachesJour".
--     Ce défaut restait MASQUÉ par le premier (l'erreur de type arrive plus tôt
--     dans la même requête) : corriger le seul défaut 1 aurait simplement
--     déplacé l'échec. Correction : 'TacheJour'.
--
-- INCHANGÉ : fenêtre 12 h / 17 h, sélection des tâches, texte du message,
-- dédoublonnage de la migration 202609190008, SECURITY INVOKER, droits
-- (CREATE OR REPLACE conserve l'ACL {postgres, service_role}), job pg_cron.
--
-- NOTE (sans conséquence visible, non modifié) : entity_id contient
-- l'identifiant de l'EMPLOYÉ alors que entity_type vaut 'TacheJour'. L'application
-- ne se sert pas de entity_type / entity_id pour naviguer (stockés seulement).
--
-- POUR ANNULER : ré-appliquer la version de 202609190008 (la fonction échoue de
-- nouveau à chaque passage et n'envoie plus rien).
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
