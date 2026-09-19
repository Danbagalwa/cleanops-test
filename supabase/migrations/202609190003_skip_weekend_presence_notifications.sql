-- ============================================================================
-- Correctif : plus aucune notification de présence le samedi ni le dimanche
-- ============================================================================
-- PROBLÈME
-- notifier_presences_non_confirmees() n'avait aucun filtre sur le jour de la
-- semaine. Le planning ne couvre que du lundi au vendredi (jour_type ne connaît
-- pas samedi ni dimanche : aucune tâche n'existe ces jours-là), mais la fonction
-- prévenait quand même le responsable, chaque samedi et chaque dimanche, que
-- tous les employés actifs « n'avaient pas confirmé leur présence ».
--
-- CORRECTIF
-- Un seul ajout : si le jour LOCAL est un samedi (isodow 6) ou un dimanche
-- (isodow 7), la fonction retourne 0 immédiatement, sans rien insérer et sans
-- notification de remplacement. Le silence est le comportement voulu.
--
-- Le jour est calculé sur v_date, donc en heure locale America/Toronto (le
-- fuseau de la résidence), jamais en UTC. Avec la fenêtre actuelle (09:00–12:00
-- locale = 13:00–17:00 UTC), jour local et jour UTC ne divergent pas pendant un
-- passage utile ; le calcul local garde toutefois le filtre correct si la
-- fenêtre était déplacée vers la soirée ou la nuit.
--
-- Rien d'autre n'est modifié : fenêtre horaire, sélection des employés et des
-- responsables, dédoublonnage, message, droits, search_path.
--
-- TÂCHE PG_CRON : AUCUN CHANGEMENT
--   cleanops-presences-non-confirmees   « */15 * * * * »
-- Le job continue de se réveiller toutes les 15 minutes, week-end compris ; il
-- ne fait simplement plus rien ces jours-là.
--
-- DÉPENDANCE / ORDRE D'APPLICATION
-- Cette migration remplace la fonction en entier et repart de la version
-- corrigée pour le fuseau (America/Toronto) de
-- 202609190002_fix_presence_notification_timezone.sql. Elle peut donc être
-- appliquée après elle (ordre normal) ou seule : dans les deux cas la fonction
-- obtenue utilise America/Toronto ET ignore le week-end. Ne jamais la
-- rejouer AVANT une version qui réintroduirait Europe/Paris.
--
-- NOTIFICATIONS DÉJÀ ENVOYÉES LE WEEK-END : cette migration ne supprime rien.
-- Le nettoyage éventuel des lignes existantes est une décision séparée.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notifier_presences_non_confirmees()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_now timestamp;
  v_date date;
  v_employee record;
  v_responsable record;
  v_count integer := 0;
BEGIN
  v_now := now() AT TIME ZONE 'America/Toronto';
  v_date := v_now::date;
  IF extract(isodow FROM v_date) IN (6, 7) THEN
    RETURN 0;
  END IF;
  IF v_now::time < time '09:00' OR v_now::time >= time '12:00' THEN
    RETURN 0;
  END IF;

  FOR v_employee IN
    SELECT e.id, e.prenom, e.nom
    FROM public.employees e
    WHERE e.is_actif = true
      AND e.role::text = 'Employé'
      AND NOT EXISTS (
        SELECT 1
        FROM public.presences p
        WHERE p.employee_id = e.id
          AND p.date = v_date
      )
  LOOP
    FOR v_responsable IN
      SELECT e.id
      FROM public.employees e
      WHERE e.is_actif = true
        AND e.role::text NOT IN ('Employé', 'Résident', 'Resident')
    LOOP
      IF NOT EXISTS (
        SELECT 1
        FROM public.notifications n
        WHERE n.destinataire_id = v_responsable.id
          AND n.type::text = 'PresenceNonConfirmee'
          AND n.entity_id = v_employee.id
          AND (n.date_envoi AT TIME ZONE 'America/Toronto')::date = v_date
      ) THEN
        PERFORM public.app_notifier_employee(
          v_responsable.id,
          'PresenceNonConfirmee',
          format(
            '%s %s n’a pas confirmé sa présence ce matin.',
            v_employee.prenom,
            v_employee.nom
          ),
          v_employee.id,
          'Presence'
        );
        v_count := v_count + 1;
      END IF;
    END LOOP;
  END LOOP;
  RETURN v_count;
END
$$;
