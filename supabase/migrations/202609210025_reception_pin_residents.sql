-- ============================================================================
-- Vue Réception, section PIN : générer ou réinitialiser le PIN d'un résident
-- ============================================================================
-- OBJECTIF
--   La Réception génère un PIN pour un résident qui n'en a pas, ou le
--   réinitialise (un nouveau PIN remplace l'ancien). Le PIN est GÉNÉRÉ PAR LE
--   SERVEUR et renvoyé UNE SEULE FOIS à la Réception, qui le communique au
--   résident. Il n'est jamais relisible ensuite : seul son hachage est stocké.
--
-- PIN : 4 chiffres, comme le reste de l'application (connexion résident par
--   numéro d'appartement + PIN). Règles appliquées à la génération :
--     * différent du numéro d'appartement (règle de la création d'un résident) ;
--     * jamais quatre chiffres identiques (0000, 1111…) ni une suite évidente
--       (1234, 4321, 0123, 3210) ;
--     * tirage avec gen_random_bytes (pgcrypto), pas random().
--
-- CE QUI EST RENVOYÉ À LA RÉCEPTION
--   reception_residents_pin() : resident_id, prenom, nom, appartement_id,
--   numero, a_application, a_pin (booléen : un PIN existe). JAMAIS le hachage.
--   reception_generer_pin(...) : {"pin": "4821", "reinitialise": true|false}.
--
-- TRAÇABILITÉ
--   journal_pin_residents garde qui a généré ou réinitialisé le PIN de qui, et
--   quand. Le PIN n'y figure PAS.
--
-- ⚠ LIMITES
--   * Le serveur ne connaît pas l'utilisateur connecté (clé publique, sans
--     identité) : l'auteur est un paramètre, validé (actif, rôle Reception) mais
--     pas authentifié.
--   * Sans RLS (report volontaire), la table residents reste modifiable avec la
--     clé publique : l'application permet déjà à l'Admin d'écrire pin_hash
--     directement. Cette fonction n'élargit pas cette exposition ; elle sera
--     réglée avec la RLS.
--   * Le PIN circule une fois, sur une connexion chiffrée, jusqu'à l'écran de la
--     Réception. Il n'est ni journalisé ni conservé côté application.
--   * Observation (hors périmètre) : authenticate_resident retient le PREMIER
--     résident actif d'un appartement (LIMIT 1, sans tri). Dans un appartement de
--     deux résidents, le PIN de l'autre peut ne pas fonctionner à la connexion.
--
-- POUR ANNULER :
--   DROP FUNCTION public.reception_generer_pin(uuid, uuid);
--   DROP FUNCTION public.reception_residents_pin();
--   DROP TABLE public.journal_pin_residents;
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Journal
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.journal_pin_residents (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  resident_id uuid NOT NULL REFERENCES public.residents (id),
  auteur_id uuid NOT NULL REFERENCES public.employees (id),
  action text NOT NULL
    CONSTRAINT journal_pin_residents_action
    CHECK (action IN ('Genere', 'Reinitialise')),
  cree_le timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_journal_pin_residents_resident
  ON public.journal_pin_residents (resident_id, cree_le DESC);
CREATE INDEX IF NOT EXISTS idx_journal_pin_residents_auteur
  ON public.journal_pin_residents (auteur_id);


-- ----------------------------------------------------------------------------
-- Liste : un résident actif par ligne, avec « a un PIN ? » (jamais le hachage)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reception_residents_pin()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'resident_id', r.id,
        'prenom', r.prenom,
        'nom', r.nom,
        'appartement_id', a.id,
        'numero', a.numero,
        'a_application', coalesce(r.a_application, false),
        'a_pin', coalesce(r.has_pin, false)
      )
      ORDER BY r.nom, r.prenom, a.numero
    ),
    '[]'::jsonb
  )
  FROM public.residents r
  JOIN public.appartements a ON a.id = r.appartement_id
  WHERE r.is_actif
    AND a.type::text = 'Appartement';
$$;


-- ----------------------------------------------------------------------------
-- Génération / réinitialisation
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reception_generer_pin(
  p_resident_id uuid,
  p_auteur_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_numero text;
  v_avait boolean;
  v_pin text;
  v_bytes bytea;
  v_n bigint;
  v_essais integer := 0;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.employees
    WHERE id = p_auteur_id AND is_actif AND role::text = 'Reception'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Auteur invalide ou inactif.';
  END IF;

  SELECT a.numero, coalesce(r.has_pin, false)
  INTO v_numero, v_avait
  FROM public.residents r
  JOIN public.appartements a ON a.id = r.appartement_id
  WHERE r.id = p_resident_id
    AND r.is_actif
    AND a.type::text = 'Appartement'
  FOR UPDATE OF r;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Résident introuvable ou inactif.';
  END IF;

  LOOP
    v_essais := v_essais + 1;
    v_bytes := extensions.gen_random_bytes(4);
    v_n := get_byte(v_bytes, 0)::bigint * 16777216
         + get_byte(v_bytes, 1)::bigint * 65536
         + get_byte(v_bytes, 2)::bigint * 256
         + get_byte(v_bytes, 3)::bigint;
    v_pin := lpad((v_n % 10000)::text, 4, '0');

    EXIT WHEN v_pin <> v_numero
          AND v_pin !~ '^(\d)\1{3}$'
          AND v_pin NOT IN ('1234', '4321', '0123', '3210');

    IF v_essais >= 50 THEN
      RAISE EXCEPTION USING ERRCODE = 'P0001',
        MESSAGE = 'Impossible de générer un PIN. Réessayez.';
    END IF;
  END LOOP;

  -- Haché ici (le déclencheur residents_hash_pin laisse passer un hachage).
  UPDATE public.residents
  SET pin_hash = extensions.crypt(v_pin, extensions.gen_salt('bf', 12))
  WHERE id = p_resident_id;

  INSERT INTO public.journal_pin_residents (resident_id, auteur_id, action)
  VALUES (
    p_resident_id,
    p_auteur_id,
    CASE WHEN v_avait THEN 'Reinitialise' ELSE 'Genere' END
  );

  RETURN jsonb_build_object('pin', v_pin, 'reinitialise', v_avait);
END;
$$;


-- ----------------------------------------------------------------------------
-- Droits
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.reception_residents_pin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reception_generer_pin(uuid, uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.reception_residents_pin()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reception_generer_pin(uuid, uuid)
  TO anon, authenticated;
