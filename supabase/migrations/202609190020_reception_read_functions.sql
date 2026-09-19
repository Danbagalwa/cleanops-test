-- ============================================================================
-- Vue Réception, section Résidents : fonctions de lecture
-- ============================================================================
-- OBJECTIF
--   La Réception consulte un appartement en LECTURE SEULE : recherche, fiche,
--   statut du jour, prochaines dates. Elle passe par ces fonctions et ne lit
--   JAMAIS taches_jour directement.
--
-- RÈGLE OBLIGATOIRE : LE MOTIF D'UN NON-RÉALISÉ N'EST JAMAIS EXPOSÉ
--   Les fonctions CONSTRUISENT leur réponse à partir d'une liste blanche de
--   champs ; motif_absent n'est ni lu ni renvoyé (« non-réalisé » = simple
--   état, sans motif, sans employé, sans commentaire).
--   ⚠ Limite : tant que la RLS n'est pas activée (chantier séparé), la table
--   taches_jour reste lisible en entier avec la clé publique. Ces fonctions
--   garantissent ce que la vue Réception DEMANDE et AFFICHE, pas ce qu'un appel
--   direct à la table pourrait obtenir.
--
-- RÈGLE OBLIGATOIRE : LE NOM AFFICHÉ EST CELUI DE L'EMPLOYÉ ACTUELLEMENT
-- RESPONSABLE
--   Il est lu dans taches_jour.employee_id, que le transfert met à jour (et la
--   prise d'une tâche libérée aussi). Après un transfert : le nouveau nom, jamais
--   l'ancien.
--
-- LES 7 ÉTATS DU STATUT DU JOUR (renvoyés sous la clé « etat »)
--   aucun       Aucune tâche aujourd'hui pour cet appartement. « prochaine »
--               donne la prochaine date et la période.
--   prevu       Tâche non commencée, non transférée, non libérée, présence de
--               l'employé non confirmée.
--   confirme    Idem, mais l'employé a confirmé sa présence pour la période.
--   transfere   Tâche non commencée, transférée ou prise par un autre employé
--               (is_transfert_temp).
--   libere      Tâche dans le pool (taches_disponibles.statut = 'Disponible'),
--               pas encore prise : en attente d'attribution.
--   realise     Statut Fait ; heure = confirmé_le (heure du Québec).
--   non_realise Statut Absent, Refus ou Annulé, sans autre précision.
--   Priorité si plusieurs conditions : realise / non_realise > libere >
--   transfere > confirme > prevu.
--
-- HYPOTHÈSES À VALIDER (signalées, non tranchées par le cahier des charges)
--   * « Annulé » est rangé dans « non_realise » (aucun des 7 états n'y
--     correspond).
--   * Présence confirmée pour la période : ligne de présence du jour en
--     'TouteJournee', ou en 'AM' / 'PM' (= absence du matin / de l'après-midi)
--     pour la période OPPOSÉE. Une présence 'Absente' ne confirme rien.
--   * Un appartement a au plus une tâche par jour (contrainte du planning) ;
--     s'il y en a plusieurs (ajout manuel), la première est retenue (matin
--     avant après-midi, puis numéro de tâche).
--   * Le prénom seul de l'employé est renvoyé.
--
-- FUSEAU : America/Toronto pour « aujourd'hui », comme le reste du projet.
-- DROITS : exécutables par anon et authenticated (l'application accède à la base
-- avec la clé publique). Les deux fonctions internes ne le sont pas.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- (interne) Prochaines dates de ménage d'un appartement, après aujourd'hui
-- Tâches réelles déjà générées + projection du planning récurrent pour les
-- dates sans tâche (même logique que l'espace résident).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reception_prochaines_dates(
  p_appartement_id uuid,
  p_limite integer DEFAULT 10,
  p_horizon_jours integer DEFAULT 120
)
RETURNS TABLE (
  o_date date,
  o_jour text,
  o_periode text,
  o_employee_id uuid,
  o_employe_prenom text,
  o_libere boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'America/Toronto')::date;
BEGIN
  RETURN QUERY
  WITH reelles AS (
    SELECT tj.semaine_reelle AS dt,
           tj.periode::text AS per,
           tj.employee_id AS emp_id,
           e.prenom::text AS emp_prenom,
           (td.id IS NOT NULL) AS lib
    FROM public.taches_jour tj
    JOIN public.employees e ON e.id = tj.employee_id
    LEFT JOIN public.taches_disponibles td
      ON td.tache_jour_id = tj.id AND td.statut::text = 'Disponible'
    WHERE tj.appartement_id = p_appartement_id
      AND tj.semaine_reelle > v_today
      AND tj.statut::text = 'NonCommencé'
  ),
  jours AS (
    SELECT (v_today + n) AS dt,
           (ARRAY['Lundi','Mardi','Mercredi','Jeudi','Vendredi'])
             [extract(isodow FROM (v_today + n))::int] AS nom_jour
    FROM generate_series(1, p_horizon_jours) AS n
    WHERE extract(isodow FROM (v_today + n)) <= 5
  ),
  projetees AS (
    SELECT j.dt,
           t.periode::text AS per,
           t.employee_id AS emp_id,
           e.prenom::text AS emp_prenom,
           false AS lib
    FROM jours j
    JOIN public.planning_templates t
      ON t.appartement_id = p_appartement_id
     AND t.jour::text = j.nom_jour
     AND t.numero_semaine = public.semaine_rotation_pour_date(j.dt)
    JOIN public.employees e ON e.id = t.employee_id AND e.is_actif
    WHERE NOT EXISTS (
      SELECT 1 FROM public.taches_jour x
      WHERE x.appartement_id = p_appartement_id AND x.semaine_reelle = j.dt
    )
  ),
  toutes AS (
    SELECT * FROM reelles
    UNION ALL
    SELECT * FROM projetees
  )
  SELECT tt.dt,
         (ARRAY['Lundi','Mardi','Mercredi','Jeudi','Vendredi'])
           [extract(isodow FROM tt.dt)::int],
         tt.per,
         tt.emp_id,
         CASE WHEN tt.lib THEN NULL ELSE tt.emp_prenom END,
         tt.lib
  FROM toutes tt
  ORDER BY tt.dt, tt.per
  LIMIT p_limite;
END;
$$;


-- ----------------------------------------------------------------------------
-- (interne) Employé concerné par l'appartement : celui de la tâche du jour
-- (si elle n'est pas libérée), sinon celui de la prochaine date connue.
-- Sert à « Transmettre aussi à l'employé ».
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reception_employe_concerne(
  p_appartement_id uuid
)
RETURNS TABLE (o_id uuid, o_prenom text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'America/Toronto')::date;
BEGIN
  RETURN QUERY
  SELECT tj.employee_id, e.prenom::text
  FROM public.taches_jour tj
  JOIN public.employees e ON e.id = tj.employee_id
  WHERE tj.appartement_id = p_appartement_id
    AND tj.semaine_reelle = v_today
    AND NOT EXISTS (
      SELECT 1 FROM public.taches_disponibles td
      WHERE td.tache_jour_id = tj.id AND td.statut::text = 'Disponible'
    )
  ORDER BY tj.periode NULLS LAST, tj.numero_tache
  LIMIT 1;

  IF FOUND THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT d.o_employee_id, d.o_employe_prenom
  FROM public.reception_prochaines_dates(p_appartement_id, 20, 120) d
  WHERE d.o_employee_id IS NOT NULL AND NOT d.o_libere
  ORDER BY d.o_date, d.o_periode
  LIMIT 1;
END;
$$;


-- ----------------------------------------------------------------------------
-- Recherche d'un appartement : par numéro OU par nom / prénom d'un résident
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reception_rechercher_appartements(
  p_recherche text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_q text := lower(btrim(coalesce(p_recherche, '')));
BEGIN
  IF length(v_q) < 1 THEN
    RETURN '[]'::jsonb;
  END IF;

  -- strpos plutôt que LIKE : aucun caractère saisi (% _) n'est interprété.
  RETURN (
    SELECT coalesce(
      jsonb_agg(s.item ORDER BY s.commence DESC, s.longueur, s.numero),
      '[]'::jsonb
    )
    FROM (
      SELECT jsonb_build_object(
               'id', a.id,
               'numero', a.numero,
               'etage', a.etage,
               'residents', (
                 SELECT coalesce(
                   jsonb_agg(r.prenom || ' ' || r.nom ORDER BY r.nom, r.prenom),
                   '[]'::jsonb)
                 FROM public.residents r
                 WHERE r.appartement_id = a.id AND r.is_actif
               )
             ) AS item,
             (left(lower(a.numero), length(v_q)) = v_q) AS commence,
             length(a.numero) AS longueur,
             a.numero AS numero
      FROM public.appartements a
      WHERE a.type::text = 'Appartement'
        AND (
          strpos(lower(a.numero), v_q) > 0
          OR EXISTS (
            SELECT 1 FROM public.residents r
            WHERE r.appartement_id = a.id
              AND r.is_actif
              AND strpos(lower(r.prenom || ' ' || r.nom), v_q) > 0
          )
        )
      ORDER BY (left(lower(a.numero), length(v_q)) = v_q) DESC,
               length(a.numero), a.numero
      LIMIT 20
    ) s
  );
END;
$$;


-- ----------------------------------------------------------------------------
-- Fiche d'un appartement (lecture seule)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reception_fiche_appartement(
  p_appartement_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'America/Toronto')::date;
  v_apt record;
  v_tache record;
  v_trouve boolean;
  v_etat text;
  v_pool boolean := false;
  v_presence_ok boolean := false;
  v_residents jsonb;
  v_dates jsonb;
  v_statut jsonb;
  v_concerne jsonb;
BEGIN
  SELECT a.id, a.numero, a.etage, a.taille
  INTO v_apt
  FROM public.appartements a
  WHERE a.id = p_appartement_id AND a.type::text = 'Appartement';

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT coalesce(
           jsonb_agg(jsonb_build_object('prenom', r.prenom, 'nom', r.nom)
                     ORDER BY r.nom, r.prenom),
           '[]'::jsonb)
  INTO v_residents
  FROM public.residents r
  WHERE r.appartement_id = v_apt.id AND r.is_actif;

  -- Tâche du jour. AUCUNE colonne de motif n'est lue.
  SELECT tj.id,
         tj.periode::text AS periode,
         tj.statut::text AS statut,
         tj.is_transfert_temp AS transfere,
         tj."confirmé_le" AS confirme_le,
         tj.employee_id AS emp_id,
         e.prenom::text AS emp_prenom
  INTO v_tache
  FROM public.taches_jour tj
  JOIN public.employees e ON e.id = tj.employee_id
  WHERE tj.appartement_id = v_apt.id AND tj.semaine_reelle = v_today
  ORDER BY tj.periode NULLS LAST, tj.numero_tache
  LIMIT 1;
  v_trouve := FOUND;

  SELECT coalesce(
           jsonb_agg(jsonb_build_object(
                       'date', d.o_date,
                       'jour', d.o_jour,
                       'periode', d.o_periode,
                       'employe_prenom', d.o_employe_prenom)
                     ORDER BY d.o_date, d.o_periode),
           '[]'::jsonb)
  INTO v_dates
  FROM public.reception_prochaines_dates(v_apt.id, 10, 120) d;

  IF NOT v_trouve THEN
    v_statut := jsonb_build_object(
      'etat', 'aucun',
      'prochaine', coalesce(v_dates -> 0, 'null'::jsonb)
    );
  ELSE
    v_pool := EXISTS (
      SELECT 1 FROM public.taches_disponibles td
      WHERE td.tache_jour_id = v_tache.id AND td.statut::text = 'Disponible'
    );
    v_presence_ok := EXISTS (
      SELECT 1 FROM public.presences p
      WHERE p.employee_id = v_tache.emp_id
        AND p.date = v_today
        AND (
          p.statut::text = 'TouteJournee'
          OR (p.statut::text = 'AM' AND v_tache.periode = 'PM')
          OR (p.statut::text = 'PM' AND v_tache.periode = 'AM')
        )
    );

    v_etat := CASE
      WHEN v_tache.statut = 'Fait' THEN 'realise'
      WHEN v_tache.statut IN ('Absent', 'Refus', 'Annulé') THEN 'non_realise'
      WHEN v_pool THEN 'libere'
      WHEN v_tache.transfere THEN 'transfere'
      WHEN v_presence_ok THEN 'confirme'
      ELSE 'prevu'
    END;

    IF v_etat = 'non_realise' THEN
      -- Ni employé, ni période, ni motif, ni commentaire.
      v_statut := jsonb_build_object('etat', 'non_realise');
    ELSE
      v_statut := jsonb_build_object(
        'etat', v_etat,
        'periode', v_tache.periode,
        'employe_prenom',
          CASE WHEN v_etat = 'libere' THEN NULL ELSE v_tache.emp_prenom END,
        'heure',
          CASE WHEN v_etat = 'realise' AND v_tache.confirme_le IS NOT NULL
               THEN to_char(v_tache.confirme_le AT TIME ZONE 'America/Toronto',
                            'HH24:MI')
          END
      );
    END IF;
  END IF;

  SELECT jsonb_build_object('id', c.o_id, 'prenom', c.o_prenom)
  INTO v_concerne
  FROM public.reception_employe_concerne(v_apt.id) c;

  RETURN jsonb_build_object(
    'appartement', jsonb_build_object(
      'id', v_apt.id,
      'numero', v_apt.numero,
      'etage', v_apt.etage,
      'taille', v_apt.taille
    ),
    'residents', v_residents,
    'statut_du_jour', v_statut,
    'prochaines_dates', v_dates,
    'employe_concerne', v_concerne
  );
END;
$$;


-- ----------------------------------------------------------------------------
-- Droits : les deux fonctions publiques pour l'application ; les internes non.
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.reception_prochaines_dates(uuid, integer, integer)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reception_employe_concerne(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reception_rechercher_appartements(text)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reception_fiche_appartement(uuid)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.reception_rechercher_appartements(text)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reception_fiche_appartement(uuid)
  TO anon, authenticated;
