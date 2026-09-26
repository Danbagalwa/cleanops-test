-- ============================================================================
-- Partage d'un document de demande d'équipe par LIEN vers une page de l'app
-- ============================================================================
-- OBJECTIF
--   Depuis une demande qui a un document joint, un utilisateur connecté peut
--   « Partager le lien ». Le lien ouvre une PAGE DE L'APPLICATION
--   (/partage/{jeton}) — pas le fichier brut — qui affiche le document ET
--   l'état de la demande (en attente, approuvée, refusée, vue) avec la
--   réponse du responsable. La page fonctionne sans être connecté : c'est le
--   jeton qui donne l'accès.
--
-- CE QUI EST CRÉÉ
--   demandes_equipe_partages : un jeton aléatoire (128 bits) par partage,
--     la demande visée, l'auteur, le lien signé Storage du document (créé par
--     l'app au moment du partage, même durée) et une date d'expiration
--     (7 jours).
--   creer_partage_demande(demande_id, employee_id, url_document) -> jeton
--   lire_partage_demande(jeton) -> jsonb (NULL si inconnu ou expiré)
--     La lecture est volontairement LIMITÉE à ce que la page affiche : pas
--     d'accès direct à la table (aucun droit accordé dessus).
--
-- ⚠ LIMITES
--   * Quiconque possède le lien voit la demande et le document pendant 7 jours
--     (principe d'un lien de partage). Pas de révocation depuis l'app pour
--     l'instant : supprimer la ligne du jeton suffit à couper l'accès à la
--     page (le lien signé du fichier, lui, reste valable jusqu'à expiration).
--   * Comme le reste de l'application (clé publique, sans identité serveur),
--     rien n'empêche techniquement de passer un autre employee_id à
--     creer_partage_demande — même limite que partout ailleurs (voir la
--     sécurisation RLS prévue en fin de projet).
--
-- POUR ANNULER :
--   DROP FUNCTION public.lire_partage_demande(text);
--   DROP FUNCTION public.creer_partage_demande(uuid, uuid, text);
--   DROP TABLE public.demandes_equipe_partages;
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.demandes_equipe_partages (
  jeton text PRIMARY KEY
    DEFAULT replace(gen_random_uuid()::text, '-', ''),
  demande_id uuid NOT NULL
    REFERENCES public.demandes_equipe (id) ON DELETE CASCADE,
  cree_par uuid REFERENCES public.employees (id) ON DELETE SET NULL,
  url_document text,
  cree_le timestamptz NOT NULL DEFAULT now(),
  expire_le timestamptz NOT NULL DEFAULT now() + interval '7 days'
);

CREATE INDEX IF NOT EXISTS demandes_equipe_partages_demande
  ON public.demandes_equipe_partages (demande_id);

-- Aucun accès direct : tout passe par les deux fonctions ci-dessous.
REVOKE ALL ON public.demandes_equipe_partages FROM PUBLIC, anon, authenticated;


-- ----------------------------------------------------------------------------
-- Créer un partage (utilisateur connecté de l'app).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.creer_partage_demande(
  p_demande_id uuid,
  p_employee_id uuid,
  p_url_document text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_jeton text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.demandes_equipe WHERE id = p_demande_id) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Cette demande est introuvable.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.employees WHERE id = p_employee_id AND is_actif
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Seul un membre actif de l''équipe peut partager un document.';
  END IF;

  INSERT INTO public.demandes_equipe_partages (demande_id, cree_par, url_document)
  VALUES (p_demande_id, p_employee_id, nullif(trim(p_url_document), ''))
  RETURNING jeton INTO v_jeton;

  RETURN v_jeton;
END;
$$;

REVOKE ALL ON FUNCTION public.creer_partage_demande(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.creer_partage_demande(uuid, uuid, text)
  TO anon, authenticated;


-- ----------------------------------------------------------------------------
-- Lire un partage (page publique /partage/{jeton}).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.lire_partage_demande(p_jeton text)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'expire_le', p.expire_le,
    'url_document', p.url_document,
    'demande', jsonb_build_object(
      'id', d.id,
      'type', d.type,
      'date_debut', d.date_debut,
      'date_fin', d.date_fin,
      'motif', d.motif,
      'statut', d.statut,
      'approuve', d.approuve,
      'note_responsable', d.note_responsable,
      'date_creation', d.date_creation,
      'date_traitement', d.date_traitement
    ),
    'employe', jsonb_build_object('prenom', e.prenom, 'nom', e.nom),
    'traite_par', CASE WHEN t.id IS NULL THEN NULL
                       ELSE jsonb_build_object('prenom', t.prenom, 'nom', t.nom)
                  END,
    'document', CASE WHEN doc.demande_id IS NULL THEN NULL
                     ELSE jsonb_build_object(
                       'nom', doc.nom,
                       'type_mime', doc.type_mime,
                       'taille', doc.taille)
                END
  )
  FROM public.demandes_equipe_partages p
  JOIN public.demandes_equipe d ON d.id = p.demande_id
  LEFT JOIN public.employees e ON e.id = d.employee_id
  LEFT JOIN public.employees t ON t.id = d.traite_par
  LEFT JOIN public.demandes_equipe_documents doc ON doc.demande_id = d.id
  WHERE p.jeton = p_jeton
    AND p.expire_le > now();
$$;

REVOKE ALL ON FUNCTION public.lire_partage_demande(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lire_partage_demande(text) TO anon, authenticated;
