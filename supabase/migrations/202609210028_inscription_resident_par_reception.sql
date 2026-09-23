-- ============================================================================
-- Inscription d'un résident par la Réception + date d'arrivée
-- ============================================================================
-- CONTEXTE
--   Quand quelqu'un emménage et se présente au comptoir, la Réception l'inscrit
--   sur un appartement qui n'a pas d'occupant actif, À LA DEMANDE DU RESPONSABLE.
--   Elle enregistre son nom ; la date d'arrivée se remplit automatiquement ; elle
--   peut ensuite générer son PIN (reception_generer_pin, migration 202609210025).
--
-- CE QUE LA RÉCEPTION NE FAIT PAS
--   Aucune assignation : ni fréquence de ménage, ni préposée, ni jour, ni
--   période. Cela reste au responsable et à l'Admin (vérification de l'autorisation
--   d'accès et des doublons). Cette migration n'écrit rien dans planning_templates
--   ni dans taches_jour.
--
-- « À LA DEMANDE DU RESPONSABLE » — CE QUI EST ENREGISTRÉ (décision retenue)
--   L'inscription EXIGE d'indiquer quel responsable l'a demandée
--   (demande_par, obligatoire, validé : employé actif, rôle Admin / Direction /
--   SuperviseurMenage / Employeur). C'est une TRACE : ni confirmation, ni
--   blocage. Rien n'empêche techniquement une inscription sans accord réel ;
--   inscriptions_residents permet de retrouver qui a inscrit qui, à la demande de
--   qui, et quand.
--
-- DATE D'ARRIVÉE (residents.date_arrivee)
--   * Remplie AUTOMATIQUEMENT à la création d'un résident (par la Réception ou
--     par l'Admin), avec la date du jour au Québec.
--   * Les résidents EXISTANTS gardent NULL = aucune restriction : personne ne
--     perd son historique.
--   * Le portail résident masque, pour un résident qui a une date d'arrivée, tout
--     ménage antérieur (le « dernier ménage effectué » de l'ancien occupant).
--
-- FONCTIONS (toutes exécutables par anon et authenticated ; l'application accède
-- à la base avec la clé publique)
--   reception_appartements_libres() : appartements sans occupant actif.
--   reception_responsables()        : responsables qu'on peut désigner.
--   reception_inscrire_resident(...): crée le résident et écrit la trace.
--
-- ⚠ LIMITES
--   * L'auteur est un paramètre validé (actif, rôle Reception), pas authentifié
--     (clé publique, sans identité) ; sans RLS (report volontaire).
--   * Pas de contrôle des homonymes : la vérification des doublons appartient au
--     flux d'assignation du responsable.
--   * Un nouveau résident n'a AUCUN ménage planifié tant que le responsable ne
--     l'a pas assigné.
--
-- POUR ANNULER :
--   DROP FUNCTION public.reception_inscrire_resident(uuid, uuid, text, text, uuid, boolean);
--   DROP FUNCTION public.reception_responsables();
--   DROP FUNCTION public.reception_appartements_libres();
--   DROP TABLE public.inscriptions_residents;
--   DROP TRIGGER residents_set_date_arrivee ON public.residents;
--   DROP FUNCTION public.set_resident_date_arrivee();
--   ALTER TABLE public.residents DROP COLUMN date_arrivee;
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Date d'arrivée
-- ----------------------------------------------------------------------------
ALTER TABLE public.residents
  ADD COLUMN IF NOT EXISTS date_arrivee date;

CREATE OR REPLACE FUNCTION public.set_resident_date_arrivee()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.date_arrivee IS NULL THEN
    NEW.date_arrivee := (now() AT TIME ZONE 'America/Toronto')::date;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS residents_set_date_arrivee ON public.residents;
CREATE TRIGGER residents_set_date_arrivee
BEFORE INSERT ON public.residents
FOR EACH ROW
EXECUTE FUNCTION public.set_resident_date_arrivee();


-- ----------------------------------------------------------------------------
-- 2. Trace des inscriptions faites par la Réception
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inscriptions_residents (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  resident_id uuid NOT NULL REFERENCES public.residents (id),
  appartement_id uuid NOT NULL REFERENCES public.appartements (id),
  auteur_id uuid NOT NULL REFERENCES public.employees (id),
  demande_par uuid NOT NULL REFERENCES public.employees (id),
  cree_le timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inscriptions_residents_resident
  ON public.inscriptions_residents (resident_id);
CREATE INDEX IF NOT EXISTS idx_inscriptions_residents_appartement
  ON public.inscriptions_residents (appartement_id);
CREATE INDEX IF NOT EXISTS idx_inscriptions_residents_auteur
  ON public.inscriptions_residents (auteur_id);
CREATE INDEX IF NOT EXISTS idx_inscriptions_residents_demande_par
  ON public.inscriptions_residents (demande_par);


-- ----------------------------------------------------------------------------
-- 3. Appartements sans occupant actif
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reception_appartements_libres()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'appartement_id', a.id,
        'numero', a.numero,
        'etage', a.etage
      )
      ORDER BY length(a.numero), a.numero
    ),
    '[]'::jsonb
  )
  FROM public.appartements a
  WHERE a.type::text = 'Appartement'
    AND NOT EXISTS (
      SELECT 1 FROM public.residents r
      WHERE r.appartement_id = a.id AND r.is_actif
    );
$$;


-- ----------------------------------------------------------------------------
-- 4. Responsables qu'on peut désigner comme demandeur
--    (même définition que les destinataires des messages de la Réception)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reception_responsables()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object('id', e.id, 'prenom', e.prenom, 'nom', e.nom)
      ORDER BY e.prenom, e.nom
    ),
    '[]'::jsonb
  )
  FROM public.employees e
  WHERE e.is_actif
    AND e.role::text NOT IN ('Employé', 'Résident', 'Resident', 'Reception');
$$;


-- ----------------------------------------------------------------------------
-- 5. Inscription
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reception_inscrire_resident(
  p_appartement_id uuid,
  p_auteur_id uuid,
  p_prenom text,
  p_nom text,
  p_demande_par uuid,
  p_a_application boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_prenom text := btrim(coalesce(p_prenom, ''));
  v_nom text := btrim(coalesce(p_nom, ''));
  v_numero text;
  v_id uuid;
  v_arrivee date;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.employees
    WHERE id = p_auteur_id AND is_actif AND role::text = 'Reception'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Auteur invalide ou inactif.';
  END IF;

  IF p_demande_par IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.employees
    WHERE id = p_demande_par
      AND is_actif
      AND role::text NOT IN ('Employé', 'Résident', 'Resident', 'Reception')
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Indiquez le responsable qui a demandé cette inscription.';
  END IF;

  IF length(v_prenom) < 1 OR length(v_prenom) > 100
     OR length(v_nom) < 1 OR length(v_nom) > 100 THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Le prénom et le nom sont obligatoires (100 caractères au plus).';
  END IF;

  -- Verrou sur l'appartement : deux inscriptions simultanées ne peuvent pas
  -- toutes deux réussir.
  SELECT a.numero INTO v_numero
  FROM public.appartements a
  WHERE a.id = p_appartement_id AND a.type::text = 'Appartement'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Appartement introuvable.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.residents r
    WHERE r.appartement_id = p_appartement_id AND r.is_actif
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Cet appartement a déjà un occupant.';
  END IF;

  -- Même insertion que l'écran de l'Admin ; date_arrivee est remplie par le
  -- déclencheur residents_set_date_arrivee.
  INSERT INTO public.residents (appartement_id, nom, prenom, a_application)
  VALUES (p_appartement_id, v_nom, v_prenom, coalesce(p_a_application, true))
  RETURNING id, date_arrivee INTO v_id, v_arrivee;

  INSERT INTO public.inscriptions_residents
    (resident_id, appartement_id, auteur_id, demande_par)
  VALUES (v_id, p_appartement_id, p_auteur_id, p_demande_par);

  RETURN jsonb_build_object(
    'resident_id', v_id,
    'numero', v_numero,
    'date_arrivee', v_arrivee
  );
END;
$$;


-- ----------------------------------------------------------------------------
-- Droits
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.reception_appartements_libres() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reception_responsables() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reception_inscrire_resident(uuid, uuid, text, text, uuid, boolean)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.reception_appartements_libres()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reception_responsables()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reception_inscrire_resident(uuid, uuid, text, text, uuid, boolean)
  TO anon, authenticated;
