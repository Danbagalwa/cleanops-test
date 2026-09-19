-- ============================================================================
-- Génération des tâches et remise à zéro des aires communes côté serveur
-- ============================================================================
-- Avant : les tâches de la semaine (taches_jour) et les zones d'aires communes
-- (taches_aire_commune) n'étaient créées que lorsqu'un utilisateur ouvrait
-- l'écran correspondant. Une semaine sans connexion = aucune ligne en base, et
-- les écrans dépendants (progression, résidents, statistiques) restaient
-- silencieusement vides.
--
-- Maintenant : trois objets serveur, tous IDEMPOTENTS, appelés par pg_cron et,
-- pour les deux premiers, par l'application en filet de sécurité.
--
--   generer_taches_semaine(p_lundi, p_employee_id)
--       Crée les taches_jour manquantes d'une semaine depuis planning_templates.
--   generer_zones_aires_communes(p_lundi)
--       Crée les zones de la semaine si elle n'en a aucune (copie de la plus
--       récente semaine antérieure connue).
--   reset_aires_communes_auto(p_forcer, p_lundi)
--       Appelle la fonction précédente puis, si config et jour l'exigent,
--       remet les zones à « AFaire » et journalise un reset automatique.
--
-- ----------------------------------------------------------------------------
-- TÂCHES PG_CRON (heures en UTC ; pg_cron de Supabase tourne en GMT)
-- ----------------------------------------------------------------------------
--   cleanops-generer-taches-semaine   « 0 3 * * 1 »
--       Chaque lundi 03:00 UTC = dimanche 23:00 (heure d'été) / 22:00 (heure
--       d'hiver) à Toronto. Génère la semaine suivante (lundi → vendredi).
--       La date locale est encore un dimanche dans les deux cas.
--
--   cleanops-reset-aires-communes     « 0 9 * * * »
--       Chaque jour 09:00 UTC = 05:00 / 04:00 à Toronto, avant le début de
--       journée (config heure_debut = 08:00). Assure que les zones de la
--       semaine courante existent, puis, seulement si
--         - config reset_aire_commune_auto = 'true', ET
--         - le jour local = config reset_aire_commune_jour (défaut 'Lundi'), ET
--         - aucun reset automatique n'est déjà journalisé pour cette semaine,
--       remet les zones à « AFaire » et écrit une ligne resets_aire_commune
--       (automatique = true). Pas de rattrapage : si le job manque le jour
--       configuré, les zones de la semaine (créées « AFaire ») ne sont pas
--       effacées un autre jour.
--
-- FUSEAU HORAIRE : America/Toronto, comme rappeler_taches_non_confirmees().
-- NB : notifier_presences_non_confirmees() utilise Europe/Paris — incohérence
-- existante, volontairement non modifiée ici.
--
-- RÈGLES REPRODUITES DU CLIENT (employee_dashboard_datasource._genererSemaine) :
--   * une tâche par planning_template de la semaine de rotation ;
--   * champs copiés : planning_template_id, employee_id, appartement_id,
--     numero_semaine, jour, periode, numero_tache ;
--   * semaine_reelle = lundi + décalage du jour ; statut « NonCommencé » ;
--     is_transfert_temp = false ; is_ajoutee = false ; minutes_finales NULL.
-- DIFFÉRENCES VOLONTAIRES :
--   * le client ne générait que si TOUTE la semaine de l'employé était vide ;
--     ici on vérifie template par template (une tâche ajoutée à la main ou
--     transférée n'empêche plus la génération du reste) ;
--   * les employés inactifs sont ignorés (le client n'agissait qu'à leur
--     connexion, donc jamais pour eux).
-- NON REPRODUIT (le client ne le faisait pas non plus) : appartements vacants,
-- absences planifiées (demandes_equipe), présences.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Numéro de semaine de rotation (1 à 4) pour une date donnée.
-- Même formule que get_semaine_courante() (config semaine_reference_*), mais
-- pour une date quelconque et sans résultat négatif avant la date de référence.
-- Équivalent de SemaineHelper.semainePourDate() côté Dart.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.semaine_rotation_pour_date(p_date date)
RETURNS integer
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_ref_num  integer;
  v_ref_date date;
  v_semaines integer;
BEGIN
  SELECT valeur::integer INTO v_ref_num
  FROM public.config WHERE cle = 'semaine_reference_numero';

  SELECT valeur::date INTO v_ref_date
  FROM public.config WHERE cle = 'semaine_reference_date';

  IF v_ref_num IS NULL OR v_ref_date IS NULL THEN
    RAISE EXCEPTION
      'Config semaine_reference_numero / semaine_reference_date manquante.';
  END IF;

  v_semaines := floor(
    (
      (p_date - (extract(isodow FROM p_date)::integer - 1))
      - (v_ref_date - (extract(isodow FROM v_ref_date)::integer - 1))
    ) / 7.0
  )::integer;

  RETURN (((v_ref_num - 1 + v_semaines) % 4) + 4) % 4 + 1;
END
$$;


-- ----------------------------------------------------------------------------
-- Tâches de la semaine
-- p_lundi       : n'importe quelle date de la semaine visée (ramenée au lundi).
--                 NULL = semaine SUIVANTE (utilisé par le cron du dimanche soir).
-- p_employee_id : NULL = toute l'équipe active.
-- Les semaines à plus de 4 semaines dans le futur sont ignorées (statut
-- 'ignoree_hors_fenetre') pour éviter une génération illimitée.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generer_taches_semaine(
  p_lundi date DEFAULT NULL,
  p_employee_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today         date := (now() AT TIME ZONE 'America/Toronto')::date;
  v_lundi_courant date;
  v_lundi         date;
  v_rotation      integer;
  v_eligibles     integer;
  v_inactifs      integer;
  v_creees        integer;
BEGIN
  v_lundi_courant := v_today - (extract(isodow FROM v_today)::integer - 1);

  IF p_lundi IS NULL THEN
    v_lundi := v_lundi_courant + 7;
  ELSE
    v_lundi := p_lundi - (extract(isodow FROM p_lundi)::integer - 1);
  END IF;

  IF v_lundi > v_lundi_courant + 28 THEN
    RETURN jsonb_build_object(
      'statut', 'ignoree_hors_fenetre',
      'semaine_lundi', v_lundi
    );
  END IF;

  -- Sérialise les exécutions concurrentes (cron + filet de sécurité client).
  PERFORM pg_advisory_xact_lock(
    hashtext('cleanops:generer_taches_semaine'),
    v_lundi - DATE '2000-01-01'
  );

  v_rotation := public.semaine_rotation_pour_date(v_lundi);

  SELECT count(*) INTO v_eligibles
  FROM public.planning_templates t
  JOIN public.employees e ON e.id = t.employee_id
  WHERE e.is_actif
    AND t.numero_semaine = v_rotation
    AND (p_employee_id IS NULL OR t.employee_id = p_employee_id);

  SELECT count(*) INTO v_inactifs
  FROM public.planning_templates t
  JOIN public.employees e ON e.id = t.employee_id
  WHERE NOT e.is_actif
    AND t.numero_semaine = v_rotation
    AND (p_employee_id IS NULL OR t.employee_id = p_employee_id);

  -- Une tâche est « déjà là » si le template a une ligne dans la semaine,
  -- quel que soit le jour ou l'employé actuel : cela respecte un transfert,
  -- une annulation ou un déplacement, et évite de recréer un doublon.
  -- ON CONFLICT couvre la contrainte taches_jour_template_date_key en cas de
  -- concurrence résiduelle.
  INSERT INTO public.taches_jour (
    planning_template_id, employee_id, appartement_id, numero_semaine,
    semaine_reelle, jour, periode, numero_tache,
    statut, is_transfert_temp, is_ajoutee
  )
  SELECT
    t.id,
    t.employee_id,
    t.appartement_id,
    t.numero_semaine,
    v_lundi + (
      CASE t.jour::text
        WHEN 'Lundi'    THEN 0
        WHEN 'Mardi'    THEN 1
        WHEN 'Mercredi' THEN 2
        WHEN 'Jeudi'    THEN 3
        WHEN 'Vendredi' THEN 4
      END
    ),
    t.jour,
    t.periode,
    t.numero_tache,
    'NonCommencé'::public.statut_tache,
    false,
    false
  FROM public.planning_templates t
  JOIN public.employees e ON e.id = t.employee_id
  WHERE e.is_actif
    AND t.numero_semaine = v_rotation
    AND (p_employee_id IS NULL OR t.employee_id = p_employee_id)
    AND NOT EXISTS (
      SELECT 1
      FROM public.taches_jour tj
      WHERE tj.planning_template_id = t.id
        AND tj.semaine_reelle BETWEEN v_lundi AND v_lundi + 4
    )
  ON CONFLICT (planning_template_id, semaine_reelle) DO NOTHING;

  GET DIAGNOSTICS v_creees = ROW_COUNT;

  RETURN jsonb_build_object(
    'statut', 'ok',
    'semaine_lundi', v_lundi,
    'numero_rotation', v_rotation,
    'templates_eligibles', v_eligibles,
    'taches_creees', v_creees,
    'deja_presentes', v_eligibles - v_creees,
    'templates_employes_inactifs_ignores', v_inactifs
  );
END
$$;


-- ----------------------------------------------------------------------------
-- Zones d'aires communes d'une semaine
-- Crée les zones seulement si la semaine n'en a AUCUNE, en copiant la plus
-- récente semaine antérieure connue (et non plus seulement la semaine
-- précédente : l'ancienne logique cliente cassait dès qu'une semaine était
-- sautée). Les semaines à plus de 4 semaines dans le futur sont ignorées.
-- p_lundi NULL = semaine courante.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generer_zones_aires_communes(
  p_lundi date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today         date := (now() AT TIME ZONE 'America/Toronto')::date;
  v_lundi_courant date;
  v_lundi         date;
  v_source        date;
  v_creees        integer := 0;
BEGIN
  v_lundi_courant := v_today - (extract(isodow FROM v_today)::integer - 1);
  v_lundi := COALESCE(p_lundi, v_lundi_courant);
  v_lundi := v_lundi - (extract(isodow FROM v_lundi)::integer - 1);

  IF v_lundi > v_lundi_courant + 28 THEN
    RETURN jsonb_build_object(
      'statut', 'ignoree_hors_fenetre',
      'semaine_date', v_lundi
    );
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtext('cleanops:generer_zones_aires_communes'),
    v_lundi - DATE '2000-01-01'
  );

  IF EXISTS (
    SELECT 1 FROM public.taches_aire_commune WHERE semaine_date = v_lundi
  ) THEN
    RETURN jsonb_build_object(
      'statut', 'deja_presente',
      'semaine_date', v_lundi,
      'zones_creees', 0
    );
  END IF;

  SELECT max(semaine_date) INTO v_source
  FROM public.taches_aire_commune
  WHERE semaine_date < v_lundi;

  IF v_source IS NULL THEN
    RETURN jsonb_build_object(
      'statut', 'aucun_modele',
      'semaine_date', v_lundi,
      'zones_creees', 0
    );
  END IF;

  INSERT INTO public.taches_aire_commune (categorie, zone, semaine_date)
  SELECT categorie, zone, v_lundi
  FROM public.taches_aire_commune
  WHERE semaine_date = v_source
  ON CONFLICT (semaine_date, categorie, zone) DO NOTHING;

  GET DIAGNOSTICS v_creees = ROW_COUNT;

  RETURN jsonb_build_object(
    'statut', 'creee',
    'semaine_date', v_lundi,
    'modele_semaine', v_source,
    'zones_creees', v_creees
  );
END
$$;


-- ----------------------------------------------------------------------------
-- Remise à zéro automatique des aires communes (appelée par le cron quotidien)
-- p_forcer : ignore config, jour et déduplication (outil de test / reprise
--            manuelle ; efface les confirmations de la semaine visée).
-- p_lundi  : semaine visée, NULL = semaine courante.
-- Non exposée à anon / authenticated.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reset_aires_communes_auto(
  p_forcer boolean DEFAULT false,
  p_lundi date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today         date := (now() AT TIME ZONE 'America/Toronto')::date;
  v_lundi_courant date;
  v_lundi         date;
  v_jours         text[] := ARRAY[
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];
  v_jour_local    text;
  v_auto          text;
  v_jour_cfg      text;
  v_zones         jsonb;
  v_remises       integer := 0;
  v_raison        text;
BEGIN
  v_lundi_courant := v_today - (extract(isodow FROM v_today)::integer - 1);
  v_lundi := COALESCE(p_lundi, v_lundi_courant);
  v_lundi := v_lundi - (extract(isodow FROM v_lundi)::integer - 1);
  v_jour_local := v_jours[extract(isodow FROM v_today)::integer];

  PERFORM pg_advisory_xact_lock(
    hashtext('cleanops:reset_aires_communes'),
    v_lundi - DATE '2000-01-01'
  );

  -- 1. Les zones de la semaine doivent exister, quoi qu'il arrive.
  v_zones := public.generer_zones_aires_communes(v_lundi);

  -- 2. Doit-on remettre à zéro aujourd'hui ?
  SELECT valeur INTO v_auto
  FROM public.config WHERE cle = 'reset_aire_commune_auto';
  SELECT valeur INTO v_jour_cfg
  FROM public.config WHERE cle = 'reset_aire_commune_jour';
  v_auto := COALESCE(v_auto, 'true');
  v_jour_cfg := COALESCE(v_jour_cfg, 'Lundi');

  IF NOT p_forcer THEN
    IF lower(btrim(v_auto)) <> 'true' THEN
      v_raison := 'reset_automatique_desactive';
    ELSIF v_lundi <> v_lundi_courant THEN
      v_raison := 'semaine_non_courante';
    ELSIF lower(btrim(v_jour_cfg)) <> lower(v_jour_local) THEN
      v_raison := 'pas_le_jour_configure';
    ELSIF EXISTS (
      SELECT 1 FROM public.resets_aire_commune
      WHERE semaine_date = v_lundi AND automatique
    ) THEN
      v_raison := 'deja_effectue_cette_semaine';
    END IF;

    IF v_raison IS NOT NULL THEN
      RETURN jsonb_build_object(
        'statut', 'reset_non_applicable',
        'raison', v_raison,
        'semaine_date', v_lundi,
        'jour_local', v_jour_local,
        'jour_configure', v_jour_cfg,
        'zones', v_zones
      );
    END IF;
  END IF;

  -- 3. Remise à zéro (mêmes champs que la remise manuelle de l'application).
  UPDATE public.taches_aire_commune
  SET statut = 'AFaire'::public.aire_statut,
      confirme_par = NULL,
      confirme_le = NULL
  WHERE semaine_date = v_lundi
    AND (statut <> 'AFaire' OR confirme_par IS NOT NULL OR confirme_le IS NOT NULL);

  GET DIAGNOSTICS v_remises = ROW_COUNT;

  INSERT INTO public.resets_aire_commune (semaine_date, automatique)
  VALUES (v_lundi, true);

  RETURN jsonb_build_object(
    'statut', 'reset_effectue',
    'semaine_date', v_lundi,
    'zones_remises_a_afaire', v_remises,
    'forcer', p_forcer,
    'zones', v_zones
  );
END
$$;


-- ----------------------------------------------------------------------------
-- Droits d'exécution
-- Les deux générateurs sont appelables par l'application (filet de sécurité)
-- car ils sont idempotents et bornés dans le temps. La remise à zéro reste
-- réservée à pg_cron / service_role.
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.semaine_rotation_pour_date(date)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.generer_taches_semaine(date, uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.generer_zones_aires_communes(date)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reset_aires_communes_auto(boolean, date)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.generer_taches_semaine(date, uuid)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.generer_zones_aires_communes(date)
  TO anon, authenticated;


-- ----------------------------------------------------------------------------
-- Planification (même schéma que 202607290002 : on remplace le job du même nom)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_job_id bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    FOR v_job_id IN
      SELECT jobid
      FROM cron.job
      WHERE jobname IN (
        'cleanops-generer-taches-semaine',
        'cleanops-reset-aires-communes'
      )
    LOOP
      PERFORM cron.unschedule(v_job_id);
    END LOOP;

    PERFORM cron.schedule(
      'cleanops-generer-taches-semaine',
      '0 3 * * 1',
      'SELECT public.generer_taches_semaine();'
    );

    PERFORM cron.schedule(
      'cleanops-reset-aires-communes',
      '0 9 * * *',
      'SELECT public.reset_aires_communes_auto();'
    );
  END IF;
END
$$;
