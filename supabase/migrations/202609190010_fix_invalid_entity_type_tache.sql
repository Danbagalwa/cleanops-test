-- ============================================================================
-- Correction de la valeur d'enum inexistante 'Tache' dans les notifications
-- ============================================================================
-- ⚠ ATTENTION — CHANGEMENT DE COMPORTEMENT VISIBLE
--   Des notifications qui n'ont JAMAIS existé se mettront à être créées :
--     * « Une tâche Apt X a été ajoutée » (tâche du jour ajoutée à la main,
--       is_ajoutee = true) ;
--     * « Apt X a été déplacé… » (changement de place) ;
--     * « Apt X a été ajouté à votre planning… » et « Apt X est maintenant
--       prévu… » à chaque ajout ou modification d'un modèle de planning
--       (planning_templates) par le responsable.
--   La génération automatique hebdomadaire des tâches (is_ajoutee = false)
--   n'en produit AUCUNE : pas de rafale au passage du cron du dimanche soir.
--
-- PROBLÈME
--   'Tache' n'existe pas dans l'enum entity_type (valeurs : TacheJour,
--   Appartement, PlanningTemplate, Memo, Chat, Transfert, Demande, Presence,
--   Employe, Resident). app_notifier_employee() l'utilisait comme valeur par
--   défaut et trois fonctions de trigger le passaient explicitement. L'INSERT
--   dans notifications échouait donc à chaque fois ; comme
--   app_notifier_employee() attrape toute erreur (EXCEPTION WHEN OTHERS ->
--   simple WARNING pour ne pas bloquer l'action métier, voir 202607290003),
--   l'échec était TOTALEMENT SILENCIEUX. Preuve en base : sur 315
--   notifications, seules existent PresenceNonConfirmee (312, qui passe
--   'Presence') et DemandeRepondue (3) ; aucune TacheAjoutee ni
--   ChangementPlace n'a jamais été créée.
--
-- CORRECTIF (4 fonctions, une valeur changée dans chacune, rien d'autre)
--   app_notifier_employee        : valeur par défaut 'Tache' -> 'TacheJour'
--   trg_notify_added_daily_task  : 'Tache' -> 'TacheJour' (NEW.id = tâche du jour)
--   trg_notify_place_change      : 'Tache' -> 'TacheJour' (tache_jour_id)
--   trg_notify_planning_change   : 'Tache' -> 'PlanningTemplate' (deux appels ;
--     NEW.id est l'identifiant d'un modèle de planning, pas d'une tâche du
--     jour : 'TacheJour' aurait été sémantiquement faux)
--
-- INCHANGÉ : messages, types de notification, dédoublonnage de 10 secondes,
-- capture des erreurs (volontaire, 202607290003), SECURITY DEFINER,
-- search_path et droits (CREATE OR REPLACE conserve les ACL).
--
-- LIMITES CONNUES (non traitées ici)
--   * L'enveloppe EXCEPTION WHEN OTHERS de app_notifier_employee est ce qui a
--     masqué ce défaut ; elle est conservée à dessein.
--   * app_notifier_employee reste exécutable par anon (chantier sécurité séparé).
--   * Côté Dart, absences_screen.dart utilisait la même valeur : corrigé dans
--     un commit séparé.
--
-- POUR ANNULER : ré-appliquer les versions de 202607290002 / 202607290003 (les
-- notifications concernées cessent alors silencieusement d'être créées).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.app_notifier_employee(
  p_employee_id uuid,
  p_type text,
  p_message text,
  p_entity_id uuid,
  p_entity_type text DEFAULT 'TacheJour'
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

  BEGIN
    EXECUTE format(
      'INSERT INTO public.notifications
        (destinataire_id, type, message, entity_id, entity_type, is_lue)
       VALUES ($1, %L, $2, $3, %L, false)',
      p_type,
      p_entity_type
    )
    USING p_employee_id, p_message, p_entity_id;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Notification employé ignorée (%): %', SQLSTATE, SQLERRM;
  END;
END
$$;

CREATE OR REPLACE FUNCTION public.trg_notify_added_daily_task()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
    'TacheJour'
  );
  RETURN NEW;
END
$$;

CREATE OR REPLACE FUNCTION public.trg_notify_place_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
    'TacheJour'
  );
  RETURN NEW;
END
$$;

CREATE OR REPLACE FUNCTION public.trg_notify_planning_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
      NEW.employee_id, v_type, v_message, NEW.id, 'PlanningTemplate'
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
      NEW.employee_id, v_type, v_message, NEW.id, 'PlanningTemplate'
    );
  END IF;
  RETURN NEW;
END
$$;
