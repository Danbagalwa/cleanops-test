-- Complète les événements de notification qui ne sont pas déjà gérés
-- directement par l'application.

-- Ajoute les nouvelles valeurs aux enums réellement utilisés par les colonnes.
DO $$
DECLARE
  v_type regtype;
  v_value text;
BEGIN
  SELECT a.atttypid::regtype
    INTO v_type
  FROM pg_attribute a
  WHERE a.attrelid = 'public.notifications'::regclass
    AND a.attname = 'type'
    AND NOT a.attisdropped;

  FOREACH v_value IN ARRAY ARRAY[
    'ChangementPlace',
    'TacheAjoutee',
    'Annulation',
    'PresenceNonConfirmee'
  ]
  LOOP
    EXECUTE format(
      'ALTER TYPE %s ADD VALUE IF NOT EXISTS %L',
      v_type,
      v_value
    );
  END LOOP;

  SELECT a.atttypid::regtype
    INTO v_type
  FROM pg_attribute a
  WHERE a.attrelid = 'public.notifications_residents'::regclass
    AND a.attname = 'type'
    AND NOT a.attisdropped;

  FOREACH v_value IN ARRAY ARRAY[
    'PresenceConfirmee',
    'Remplacement',
    'MenageEnAttente',
    'Absence'
  ]
  LOOP
    EXECUTE format(
      'ALTER TYPE %s ADD VALUE IF NOT EXISTS %L',
      v_type,
      v_value
    );
  END LOOP;
END
$$;

-- Helpers avec dédoublonnage court. Le SQL dynamique permet de conserver les
-- enums existants sans figer leur nom dans la migration.
CREATE OR REPLACE FUNCTION public.app_notifier_employee(
  p_employee_id uuid,
  p_type text,
  p_message text,
  p_entity_id uuid,
  p_entity_type text DEFAULT 'Tache'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_employee_id IS NULL OR EXISTS (
    SELECT 1
    FROM public.notifications n
    WHERE n.destinataire_id = p_employee_id
      AND n.type::text = p_type
      AND n.entity_id IS NOT DISTINCT FROM p_entity_id
      AND n.date_envoi > now() - interval '10 seconds'
  ) THEN
    RETURN;
  END IF;

  EXECUTE format(
    'INSERT INTO public.notifications
      (destinataire_id, type, message, entity_id, entity_type, is_lue)
     VALUES ($1, %L, $2, $3, %L, false)',
    p_type,
    p_entity_type
  )
  USING p_employee_id, p_message, p_entity_id;
END
$$;

CREATE OR REPLACE FUNCTION public.app_notifier_resident(
  p_resident_id uuid,
  p_tache_id uuid,
  p_type text,
  p_message text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_resident_id IS NULL OR EXISTS (
    SELECT 1
    FROM public.notifications_residents n
    WHERE n.resident_id = p_resident_id
      AND n.type::text = p_type
      AND n.tache_jour_id IS NOT DISTINCT FROM p_tache_id
      AND n.date_envoi > now() - interval '10 seconds'
  ) THEN
    RETURN;
  END IF;

  EXECUTE format(
    'INSERT INTO public.notifications_residents
      (resident_id, tache_jour_id, type, message, is_lue)
     VALUES ($1, $2, %L, $3, false)',
    p_type
  )
  USING p_resident_id, p_tache_id, p_message;
END
$$;

-- Ajout ou déplacement dans le planning récurrent.
CREATE OR REPLACE FUNCTION public.trg_notify_planning_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_numero text;
  v_type text;
  v_message text;
BEGIN
  SELECT a.numero INTO v_numero
  FROM public.appartements a
  WHERE a.id = NEW.appartement_id;

  IF TG_OP = 'INSERT' THEN
    v_type := 'TacheAjoutee';
    v_message := format(
      'Apt %s a été ajouté à votre planning — %s %s (semaine %s).',
      coalesce(v_numero, '—'),
      NEW.jour::text,
      coalesce(NEW.periode::text, ''),
      NEW.numero_semaine
    );
    PERFORM public.app_notifier_employee(
      NEW.employee_id, v_type, v_message, NEW.id, 'Tache'
    );
    RETURN NEW;
  END IF;

  IF OLD.employee_id IS DISTINCT FROM NEW.employee_id
     OR OLD.jour IS DISTINCT FROM NEW.jour
     OR OLD.periode IS DISTINCT FROM NEW.periode THEN
    v_type := 'ChangementPlace';
    v_message := format(
      'Apt %s est maintenant prévu %s %s (semaine %s).',
      coalesce(v_numero, '—'),
      NEW.jour::text,
      coalesce(NEW.periode::text, ''),
      NEW.numero_semaine
    );
    PERFORM public.app_notifier_employee(
      NEW.employee_id, v_type, v_message, NEW.id, 'Tache'
    );
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS notify_planning_change
ON public.planning_templates;
CREATE TRIGGER notify_planning_change
AFTER INSERT OR UPDATE OF employee_id, jour, periode
ON public.planning_templates
FOR EACH ROW
EXECUTE FUNCTION public.trg_notify_planning_change();

-- Tâche ponctuelle ajoutée directement dans taches_jour.
CREATE OR REPLACE FUNCTION public.trg_notify_added_daily_task()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_numero text;
BEGIN
  IF NOT coalesce(NEW.is_ajoutee, false) THEN
    RETURN NEW;
  END IF;

  SELECT a.numero INTO v_numero
  FROM public.appartements a
  WHERE a.id = NEW.appartement_id;

  PERFORM public.app_notifier_employee(
    NEW.employee_id,
    'TacheAjoutee',
    format(
      'Une tâche Apt %s a été ajoutée — %s %s.',
      coalesce(v_numero, '—'),
      NEW.jour::text,
      coalesce(NEW.periode::text, '')
    ),
    NEW.id,
    'Tache'
  );
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS notify_added_daily_task ON public.taches_jour;
CREATE TRIGGER notify_added_daily_task
AFTER INSERT ON public.taches_jour
FOR EACH ROW
EXECUTE FUNCTION public.trg_notify_added_daily_task();

-- Changement ponctuel de jour/période.
CREATE OR REPLACE FUNCTION public.trg_notify_place_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tache public.taches_jour%ROWTYPE;
  v_numero text;
BEGIN
  SELECT * INTO v_tache
  FROM public.taches_jour
  WHERE id = NEW.tache_jour_id;

  SELECT numero INTO v_numero
  FROM public.appartements
  WHERE id = v_tache.appartement_id;

  PERFORM public.app_notifier_employee(
    v_tache.employee_id,
    'ChangementPlace',
    format(
      'Apt %s a été déplacé de %s %s vers %s %s.',
      coalesce(v_numero, '—'),
      NEW.ancien_jour::text,
      coalesce(NEW.ancienne_periode::text, ''),
      NEW.nouveau_jour::text,
      coalesce(NEW.nouvelle_periode::text, '')
    ),
    NEW.tache_jour_id,
    'Tache'
  );
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS notify_place_change ON public.changements_place;
CREATE TRIGGER notify_place_change
AFTER INSERT ON public.changements_place
FOR EACH ROW
EXECUTE FUNCTION public.trg_notify_place_change();

-- Présence/absence confirmée : informe uniquement les résidents actifs qui
-- utilisent l'application et qui ont un ménage pour la date concernée.
CREATE OR REPLACE FUNCTION public.trg_notify_residents_presence()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task record;
  v_resident record;
  v_employee_name text;
  v_type text;
  v_message text;
BEGIN
  IF TG_OP = 'UPDATE'
     AND OLD.statut IS NOT DISTINCT FROM NEW.statut
     AND OLD.confirme_le IS NOT DISTINCT FROM NEW.confirme_le THEN
    RETURN NEW;
  END IF;

  SELECT trim(concat(e.prenom, ' ', e.nom))
    INTO v_employee_name
  FROM public.employees e
  WHERE e.id = NEW.employee_id;

  IF NEW.statut::text = 'TouteJournee' THEN
    v_type := 'PresenceConfirmee';
    v_message := format(
      'Votre ménage est confirmé pour aujourd’hui — préposée : %s.',
      coalesce(nullif(v_employee_name, ''), 'équipe d’entretien')
    );
  ELSE
    v_type := 'Absence';
    v_message :=
      'La préposée prévue est absente. Nous vous informerons dès qu’un remplacement sera confirmé.';
  END IF;

  FOR v_task IN
    SELECT tj.id, tj.appartement_id
    FROM public.taches_jour tj
    WHERE tj.employee_id = NEW.employee_id
      AND tj.semaine_reelle = NEW.date
      AND tj.jour::text = CASE extract(isodow FROM NEW.date)
        WHEN 1 THEN 'Lundi'
        WHEN 2 THEN 'Mardi'
        WHEN 3 THEN 'Mercredi'
        WHEN 4 THEN 'Jeudi'
        WHEN 5 THEN 'Vendredi'
        WHEN 6 THEN 'Samedi'
        ELSE 'Dimanche'
      END
  LOOP
    FOR v_resident IN
      SELECT r.id
      FROM public.residents r
      WHERE r.appartement_id = v_task.appartement_id
        AND r.is_actif = true
        AND r.a_application = true
    LOOP
      PERFORM public.app_notifier_resident(
        v_resident.id,
        v_task.id,
        v_type,
        v_message
      );
    END LOOP;
  END LOOP;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS notify_residents_presence ON public.presences;
CREATE TRIGGER notify_residents_presence
AFTER INSERT OR UPDATE OF statut, confirme_le
ON public.presences
FOR EACH ROW
EXECUTE FUNCTION public.trg_notify_residents_presence();

-- Fonction idempotente à appeler par Cron. Elle ne fait quelque chose qu'entre
-- 09:00 et 11:59, heure de Paris, et une seule fois par responsable/employé/jour.
CREATE OR REPLACE FUNCTION public.notifier_presences_non_confirmees()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now timestamp;
  v_date date;
  v_employee record;
  v_responsable record;
  v_count integer := 0;
BEGIN
  v_now := timezone('Europe/Paris', now());
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
          AND timezone('Europe/Paris', n.date_envoi)::date = v_date
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

-- Planification toutes les 15 minutes. Le contrôle d'heure et le
-- dédoublonnage sont effectués dans la fonction.
DO $$
DECLARE
  v_job_id bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    SELECT jobid INTO v_job_id
    FROM cron.job
    WHERE jobname = 'cleanops-presences-non-confirmees'
    LIMIT 1;

    IF v_job_id IS NOT NULL THEN
      PERFORM cron.unschedule(v_job_id);
    END IF;

    PERFORM cron.schedule(
      'cleanops-presences-non-confirmees',
      '*/15 * * * *',
      'SELECT public.notifier_presences_non_confirmees();'
    );
  END IF;
END
$$;
