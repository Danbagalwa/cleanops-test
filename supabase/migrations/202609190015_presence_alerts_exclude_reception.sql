-- ============================================================================
-- notifier_presences_non_confirmees() : ne plus notifier la Réception
-- ============================================================================
-- CONTEXTE
--   Chantier « sortir Réception du booléen isResponsable ». La fonction
--   prévient les « responsables » qu'une préposée n'a pas confirmé sa présence.
--   Sa liste de destinataires était définie par exclusion : tout rôle sauf
--   Employé et Résident. Elle incluait donc la Réception, qui n'a pas à recevoir
--   ces alertes.
--
-- CORRECTIF (une valeur ajoutée à une liste d'exclusion, rien d'autre)
--   'Reception' est ajouté à la liste des rôles exclus des destinataires.
--   Destinataires après correctif : Admin, Direction, SuperviseurMenage et le
--   rôle historique Employeur (inchangés ; leur fusion dans Admin est un chantier
--   séparé).
--
-- INCHANGÉ : fenêtre 09:00-12:00 America/Toronto, filtre week-end
-- (202609190003), sélection des employés à surveiller, dédoublonnage, message,
-- SECURITY DEFINER, search_path, droits (CREATE OR REPLACE conserve l'ACL),
-- job pg_cron.
--
-- LIMITE : la liste reste définie par EXCLUSION. Un futur rôle ajouté à l'enum
-- serait notifié par défaut. À remplacer par une liste explicite lors du
-- chantier de fusion Admin / Responsable.
--
-- POUR ANNULER : ré-appliquer la version de 202609190003.
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
        AND e.role::text NOT IN ('Employé', 'Résident', 'Resident', 'Reception')
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
