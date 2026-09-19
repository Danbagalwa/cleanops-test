-- ============================================================================
-- Correctif : fuseau horaire de notifier_presences_non_confirmees()
-- ============================================================================
-- PROBLÈME
-- La fonction (créée par 202607290002) calculait l'heure locale avec
-- « Europe/Paris ». La résidence est au Québec : la fenêtre 09:00–12:00 de la
-- fonction tombait donc à 03:00–06:00 (heure du Québec), et les responsables
-- recevaient l'alerte « n'a pas confirmé sa présence ce matin » en pleine nuit,
-- avant que quiconque ait pu confirmer. Constaté en base : les notifications
-- PresenceNonConfirmee des 2026-09-18 et 2026-09-19 sont parties à 03:00,
-- heure du Québec.
--
-- CORRECTIF
-- « Europe/Paris » est remplacé par « America/Toronto » aux deux endroits où il
-- apparaissait dans la fonction :
--   1. v_now : heure locale servant à la fenêtre 09:00–12:00 et à v_date ;
--   2. le dédoublonnage : jour local de la notification déjà envoyée.
-- Rien d'autre n'est modifié (logique, message, droits, search_path).
--
-- TÂCHE PG_CRON : AUCUN CHANGEMENT
--   cleanops-presences-non-confirmees   « */15 * * * * »
-- Cette expression ne dépend d'aucun fuseau : le job se réveille toutes les
-- 15 minutes, et la fenêtre en heure locale est appliquée dans la fonction avec
-- AT TIME ZONE. C'est le même mécanisme que rappeler_taches_non_confirmees()
-- (cron toutes les heures, filtre sur l'heure de Toronto) et que la date locale
-- de 202609190001. Aucun décalage UTC fixe n'est écrit nulle part : le passage
-- à l'heure d'été / d'hiver est donc géré automatiquement.
--
-- HORAIRE RÉEL APRÈS CORRECTIF (heure du Québec = America/Toronto)
--   Fenêtre d'envoi : de 09:00 inclus à 12:00 exclu, un passage toutes les 15 min.
--   Premier passage utile : 09:00, soit
--     - 13:00 UTC en heure d'été (EDT, UTC-4, ~8 mars → ~1er novembre) ;
--     - 14:00 UTC en heure d'hiver (EST, UTC-5).
--   Dernier passage : 11:45 locale (15:45 UTC en été, 16:45 UTC en hiver).
--   Comme le dédoublonnage est par responsable / employé / jour local, une
--   personne n'est notifiée qu'une fois par jour ; les passages suivants ne
--   servent que de rattrapage si celui de 09:00 a échoué. Le seuil 09:00
--   correspond à config heure_alerte_responsable = '09:00'.
--
-- NOTE : le passage de 09:00 du jour de l'application de cette migration ne
-- renverra pas de doublon pour les notifications déjà parties à 03:00 le même
-- jour local : le dédoublonnage compare désormais des jours du Québec.
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
