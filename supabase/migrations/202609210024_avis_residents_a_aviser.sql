-- ============================================================================
-- Vue Réception, section « À aviser » : prévenir les résidents SANS application
-- ============================================================================
-- PROBLÈME
--   Quand le ménage d'un résident change (préposée absente, transfert, ménage
--   annulé ou déplacé), l'application prévient automatiquement les résidents qui
--   ont l'application (table notifications_residents). Les résidents SANS
--   application ne voient jamais rien : quelqu'un doit les appeler ou passer les
--   voir. La Réception, souvent au comptoir, partage cette charge avec le
--   responsable.
--
-- CE QUE FAIT CETTE MIGRATION
--   1. avis_residents : une ligne par résident sans application à aviser.
--   2. app_creer_avis_residents_sans_app(...) : crée (ou met à jour) les avis
--      d'un appartement. Appelée par les déclencheurs ci-dessous et par
--      l'application aux endroits où elle prévient déjà les résidents.
--   3. Deux déclencheurs, INDÉPENDANTS des déclencheurs existants :
--        - presences : absence (Absente, AM, PM) -> avis « Absence » ;
--        - changements_place : ménage déplacé -> avis « Reprogrammation ».
--      Le retour à « TouteJournee » retire les avis d'absence encore ouverts.
--   4. reception_a_aviser() : la liste pour la Réception (lecture).
--   5. reception_traiter_avis(...) : Appelé(e) / Note laissée / Reporter, avec
--      un commentaire facultatif.
--
-- RÈGLES
--   * Résidents ACTIFS sans application seulement (a_application = false).
--   * Un seul avis OUVERT par résident et par tâche : un changement plus récent
--     met l'avis ouvert à jour (type, message) sans remettre son compteur à zéro.
--   * Statuts : AAviser (nouveau), Reporte (remis à plus tard, reste ouvert),
--     Appele et NoteLaissee (traités, fermés).
--   * BADGE ROUGE : avis ouvert dont le dernier départ (création, ou dernier
--     « Reporter ») date de plus de 2 heures. « Reporter » remet le compteur à
--     zéro ; la Réception ne modifie AUCUN planning.
--   * La Réception voit les avis ouverts et ceux traités AUJOURD'HUI (heure du
--     Québec).
--
-- RÈGLE OBLIGATOIRE : AUCUN MOTIF EXPOSÉ
--   Le message d'un avis est celui que reçoivent déjà les résidents avec
--   l'application (« La préposée prévue est absente… », « Votre ménage est
--   momentanément en attente… »). taches_jour.motif_absent et la note d'une
--   annulation ne sont jamais lus ni copiés.
--
-- ROBUSTESSE : rien de ce qui est ajouté ne doit bloquer une action existante.
--   Les fonctions de création d'avis et les deux déclencheurs interceptent
--   toute erreur (RAISE WARNING) et laissent l'opération d'origine aboutir.
--
-- ⚠ LIMITES
--   * Le serveur ne connaît pas l'utilisateur (clé publique, sans identité) :
--     l'auteur d'un traitement est un paramètre, validé (actif, rôle Reception)
--     mais pas authentifié. Le chantier RLS / sessions le remplacera.
--   * avis_residents est sans RLS pour l'instant (report volontaire).
--   * Les annulations et les transferts sont enregistrés par l'APPLICATION
--     (mise à jour de taches_jour depuis l'écran des absences) : ils créent leur
--     avis par un appel de l'application, au même endroit où elle prévient déjà
--     les résidents avec l'application. Un ménage annulé ou transféré par un
--     autre chemin ne crée pas d'avis.
--   * Un avis ouvert d'absence est SUPPRIMÉ si la présence repasse à
--     « TouteJournee » : il n'y a plus rien à annoncer.
--
-- POUR ANNULER :
--   DROP TRIGGER avis_residents_presence ON public.presences;
--   DROP TRIGGER avis_residents_place_change ON public.changements_place;
--   DROP FUNCTION public.trg_avis_residents_presence();
--   DROP FUNCTION public.trg_avis_residents_place_change();
--   DROP FUNCTION public.reception_traiter_avis(uuid, uuid, text, text);
--   DROP FUNCTION public.reception_a_aviser();
--   DROP FUNCTION public.app_creer_avis_residents_sans_app(uuid, uuid, text, text);
--   DROP TABLE public.avis_residents;
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.avis_residents (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  resident_id uuid NOT NULL REFERENCES public.residents (id),
  appartement_id uuid NOT NULL REFERENCES public.appartements (id),
  tache_jour_id uuid REFERENCES public.taches_jour (id) ON DELETE SET NULL,
  type text NOT NULL
    CONSTRAINT avis_residents_type
    CHECK (type IN ('Absence', 'Remplacement', 'MenageEnAttente',
                    'Reprogrammation')),
  message text NOT NULL,
  statut text NOT NULL DEFAULT 'AAviser'
    CONSTRAINT avis_residents_statut
    CHECK (statut IN ('AAviser', 'Reporte', 'Appele', 'NoteLaissee')),
  commentaire text
    CONSTRAINT avis_residents_commentaire
    CHECK (commentaire IS NULL OR length(commentaire) BETWEEN 1 AND 500),
  traite_par uuid REFERENCES public.employees (id),
  traite_le timestamptz,
  reporte_le timestamptz,
  cree_le timestamptz NOT NULL DEFAULT now(),
  mis_a_jour_le timestamptz NOT NULL DEFAULT now()
);

-- Un seul avis ouvert par résident et par tâche.
CREATE UNIQUE INDEX IF NOT EXISTS uq_avis_residents_ouvert
  ON public.avis_residents (resident_id, tache_jour_id)
  WHERE statut IN ('AAviser', 'Reporte') AND tache_jour_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_avis_residents_statut_cree
  ON public.avis_residents (statut, cree_le);
CREATE INDEX IF NOT EXISTS idx_avis_residents_resident
  ON public.avis_residents (resident_id);
CREATE INDEX IF NOT EXISTS idx_avis_residents_appartement
  ON public.avis_residents (appartement_id);
CREATE INDEX IF NOT EXISTS idx_avis_residents_tache
  ON public.avis_residents (tache_jour_id) WHERE tache_jour_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_avis_residents_traite_par
  ON public.avis_residents (traite_par) WHERE traite_par IS NOT NULL;


-- ----------------------------------------------------------------------------
-- 2. Création (ou mise à jour) des avis d'un appartement
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_creer_avis_residents_sans_app(
  p_appartement_id uuid,
  p_tache_id uuid,
  p_type text,
  p_message text
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_res record;
  v_nb integer := 0;
BEGIN
  IF p_appartement_id IS NULL OR coalesce(btrim(p_message), '') = '' THEN
    RETURN 0;
  END IF;

  FOR v_res IN
    SELECT r.id
    FROM public.residents r
    WHERE r.appartement_id = p_appartement_id
      AND r.is_actif
      AND NOT coalesce(r.a_application, false)
  LOOP
    UPDATE public.avis_residents a
    SET type = p_type,
        message = p_message,
        mis_a_jour_le = now()
    WHERE a.resident_id = v_res.id
      AND a.tache_jour_id IS NOT DISTINCT FROM p_tache_id
      AND a.statut IN ('AAviser', 'Reporte');

    IF NOT FOUND THEN
      INSERT INTO public.avis_residents
        (resident_id, appartement_id, tache_jour_id, type, message)
      VALUES
        (v_res.id, p_appartement_id, p_tache_id, p_type, p_message);
    END IF;

    v_nb := v_nb + 1;
  END LOOP;

  RETURN v_nb;
EXCEPTION WHEN OTHERS THEN
  -- Ne jamais bloquer l'action d'origine (absence, transfert, annulation…).
  RAISE WARNING 'app_creer_avis_residents_sans_app : %', SQLERRM;
  RETURN 0;
END;
$$;


-- ----------------------------------------------------------------------------
-- 3a. Déclencheur : absence d'une préposée
--     Même période que l'absence : AM -> tâches du matin, PM -> après-midi,
--     Absente -> toute la journée. Seulement les tâches non commencées.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_avis_residents_presence()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_task record;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.statut IS NOT DISTINCT FROM NEW.statut THEN
    RETURN NEW;
  END IF;

  IF NEW.statut::text = 'TouteJournee' THEN
    -- L'absence est annulée : les avis d'absence encore ouverts n'ont plus lieu
    -- d'être.
    DELETE FROM public.avis_residents a
    WHERE a.type = 'Absence'
      AND a.statut IN ('AAviser', 'Reporte')
      AND a.tache_jour_id IN (
        SELECT tj.id
        FROM public.taches_jour tj
        WHERE tj.employee_id = NEW.employee_id
          AND tj.semaine_reelle = NEW.date
      );
    RETURN NEW;
  END IF;

  IF NEW.statut::text NOT IN ('Absente', 'AM', 'PM') THEN
    RETURN NEW;
  END IF;

  FOR v_task IN
    SELECT tj.id, tj.appartement_id
    FROM public.taches_jour tj
    WHERE tj.employee_id = NEW.employee_id
      AND tj.semaine_reelle = NEW.date
      AND tj.statut::text = 'NonCommencé'
      AND (
        NEW.statut::text = 'Absente'
        OR (NEW.statut::text = 'AM' AND tj.periode::text = 'AM')
        OR (NEW.statut::text = 'PM' AND tj.periode::text = 'PM')
      )
  LOOP
    PERFORM public.app_creer_avis_residents_sans_app(
      v_task.appartement_id,
      v_task.id,
      'Absence',
      'La préposée prévue est absente. Nous vous informerons dès qu’un '
        || 'remplacement sera confirmé.'
    );
  END LOOP;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_avis_residents_presence : %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS avis_residents_presence ON public.presences;
CREATE TRIGGER avis_residents_presence
AFTER INSERT OR UPDATE OF statut ON public.presences
FOR EACH ROW
EXECUTE FUNCTION public.trg_avis_residents_presence();


-- ----------------------------------------------------------------------------
-- 3b. Déclencheur : ménage déplacé (reprogrammé)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_avis_residents_place_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_appartement uuid;
BEGIN
  SELECT tj.appartement_id INTO v_appartement
  FROM public.taches_jour tj
  WHERE tj.id = NEW.tache_jour_id;

  PERFORM public.app_creer_avis_residents_sans_app(
    v_appartement,
    NEW.tache_jour_id,
    'Reprogrammation',
    format(
      'Votre ménage a été déplacé de %s %s vers %s %s.',
      NEW.ancien_jour::text,
      coalesce(NEW.ancienne_periode::text, ''),
      NEW.nouveau_jour::text,
      coalesce(NEW.nouvelle_periode::text, '')
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_avis_residents_place_change : %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS avis_residents_place_change ON public.changements_place;
CREATE TRIGGER avis_residents_place_change
AFTER INSERT ON public.changements_place
FOR EACH ROW
EXECUTE FUNCTION public.trg_avis_residents_place_change();


-- ----------------------------------------------------------------------------
-- 4. Lecture pour la Réception
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reception_a_aviser()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT jsonb_build_object(
    'avis',
    coalesce(
      jsonb_agg(x.item ORDER BY x.ouvert DESC, x.en_retard DESC, x.debut),
      '[]'::jsonb
    )
  )
  FROM (
    SELECT
      (a.statut IN ('AAviser', 'Reporte')) AS ouvert,
      (a.statut IN ('AAviser', 'Reporte')
        AND now() - coalesce(a.reporte_le, a.cree_le) > interval '2 hours')
        AS en_retard,
      coalesce(a.reporte_le, a.cree_le) AS debut,
      jsonb_build_object(
        'id', a.id,
        'resident_id', r.id,
        'prenom', r.prenom,
        'nom', r.nom,
        'appartement_id', ap.id,
        'numero', ap.numero,
        'type', a.type,
        'message', a.message,
        'statut', a.statut,
        'commentaire', a.commentaire,
        'depuis_minutes',
          floor(extract(epoch FROM (now() - coalesce(a.reporte_le, a.cree_le)))
                / 60)::int,
        'en_retard',
          (a.statut IN ('AAviser', 'Reporte')
            AND now() - coalesce(a.reporte_le, a.cree_le) > interval '2 hours'),
        'traite_le', a.traite_le
      ) AS item
    FROM public.avis_residents a
    JOIN public.residents r ON r.id = a.resident_id
    JOIN public.appartements ap ON ap.id = a.appartement_id
    WHERE a.statut IN ('AAviser', 'Reporte')
       OR (a.traite_le AT TIME ZONE 'America/Toronto')::date
          = (now() AT TIME ZONE 'America/Toronto')::date
  ) x;
$$;


-- ----------------------------------------------------------------------------
-- 5. Traitement par la Réception : Appelé(e) / Note laissée / Reporter
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reception_traiter_avis(
  p_avis_id uuid,
  p_auteur_id uuid,
  p_action text,
  p_commentaire text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_comm text := nullif(btrim(coalesce(p_commentaire, '')), '');
  v_statut text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.employees
    WHERE id = p_auteur_id AND is_actif AND role::text = 'Reception'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Auteur invalide ou inactif.';
  END IF;

  IF p_action IS NULL OR p_action NOT IN ('Appele', 'NoteLaissee', 'Reporte') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Action inconnue.';
  END IF;

  IF v_comm IS NOT NULL AND length(v_comm) > 500 THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Le commentaire ne peut pas dépasser 500 caractères.';
  END IF;

  SELECT a.statut INTO v_statut
  FROM public.avis_residents a
  WHERE a.id = p_avis_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Avis introuvable.';
  END IF;

  IF v_statut NOT IN ('AAviser', 'Reporte') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Cet avis est déjà traité.';
  END IF;

  UPDATE public.avis_residents
  SET statut = p_action,
      commentaire = v_comm,
      traite_par = p_auteur_id,
      traite_le = now(),
      reporte_le = CASE WHEN p_action = 'Reporte' THEN now() ELSE reporte_le END,
      mis_a_jour_le = now()
  WHERE id = p_avis_id;
END;
$$;


-- ----------------------------------------------------------------------------
-- Droits : les 3 fonctions appelables par l'application ; les fonctions de
-- déclencheur ne sont pas exposées.
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.trg_avis_residents_presence()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trg_avis_residents_place_change()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.app_creer_avis_residents_sans_app(uuid, uuid, text, text)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reception_a_aviser() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reception_traiter_avis(uuid, uuid, text, text)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_creer_avis_residents_sans_app(uuid, uuid, text, text)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reception_a_aviser()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reception_traiter_avis(uuid, uuid, text, text)
  TO anon, authenticated;
