-- ============================================================================
-- Preuve de traitement jointe par le responsable à une demande d'équipe
-- ============================================================================
-- OBJECTIF
--   En traitant une demande (ou après), le responsable peut joindre UNE
--   preuve de traitement FACULTATIVE (PDF ou image) : formulaire signé,
--   confirmation, capture… Elle est visible par l'employé, par le
--   responsable, et sur la page publique d'un lien de partage.
--
-- STOCKAGE : même bucket que le document de l'employé
--   ("documents-demandes-equipe", mêmes limites : 5 Mo, PDF/JPEG/PNG), chemin
--   "preuves/{demande_id}" (renvoyer une preuve la remplace). Seules les
--   MÉTADONNÉES sont en base (demandes_equipe_preuves), relues depuis Storage
--   par la fonction d'enregistrement (taille et type RÉELS).
--
-- CE QUI EST CRÉÉ / MODIFIÉ
--   demandes_equipe_preuves (une ligne par demande, métadonnées seulement)
--   enregistrer_preuve_demande(demande_id, responsable_id, chemin, nom)
--   lire_partage_demande(jeton) : renvoie aussi la preuve (métadonnées +
--     chemin) ; la page de partage en crée elle-même le lien signé, pour
--     qu'une preuve ajoutée APRÈS le partage apparaisse quand même.
--
-- ⚠ LIMITES : mêmes que la migration 202609230033 (clé publique, sans
--   identité serveur : l'identifiant du responsable n'est pas prouvé).
--
-- POUR ANNULER :
--   DROP FUNCTION public.enregistrer_preuve_demande(uuid, uuid, text, text);
--   DROP TABLE public.demandes_equipe_preuves;
--   puis ré-exécuter lire_partage_demande de la migration 202609240037.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.demandes_equipe_preuves (
  demande_id uuid PRIMARY KEY
    REFERENCES public.demandes_equipe (id) ON DELETE CASCADE,
  chemin text NOT NULL,
  nom text NOT NULL
    CONSTRAINT demandes_equipe_preuves_nom CHECK (length(trim(nom)) BETWEEN 1 AND 150),
  type_mime text NOT NULL
    CONSTRAINT demandes_equipe_preuves_mime
    CHECK (type_mime IN ('application/pdf', 'image/jpeg', 'image/png')),
  taille integer NOT NULL CHECK (taille BETWEEN 1 AND 5242880),
  ajoute_par uuid REFERENCES public.employees (id) ON DELETE SET NULL,
  ajoute_le timestamptz NOT NULL DEFAULT now()
);

-- Lecture des métadonnées (embarquées dans la liste des demandes) ; écriture
-- uniquement par la fonction ci-dessous.
REVOKE ALL ON public.demandes_equipe_preuves FROM PUBLIC, anon, authenticated;
GRANT SELECT (demande_id, chemin, nom, type_mime, taille, ajoute_le)
  ON public.demandes_equipe_preuves TO anon, authenticated;


CREATE OR REPLACE FUNCTION public.enregistrer_preuve_demande(
  p_demande_id uuid,
  p_responsable_id uuid,
  p_chemin text,
  p_nom text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_type_mime text;
  v_taille bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.demandes_equipe WHERE id = p_demande_id) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Cette demande est introuvable.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.employees
    WHERE id = p_responsable_id
      AND is_actif
      AND role::text IN ('SuperviseurMenage', 'Direction', 'Admin')
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Seul un responsable peut joindre une preuve de traitement.';
  END IF;

  IF p_chemin IS DISTINCT FROM 'preuves/' || p_demande_id::text THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Emplacement de la preuve invalide.';
  END IF;

  IF length(trim(coalesce(p_nom, ''))) = 0 THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Le nom du fichier est obligatoire.';
  END IF;

  SELECT o.metadata->>'mimetype', (o.metadata->>'size')::bigint
  INTO v_type_mime, v_taille
  FROM storage.objects o
  WHERE o.bucket_id = 'documents-demandes-equipe' AND o.name = p_chemin;

  IF NOT FOUND OR v_type_mime IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Le fichier n''a pas été reçu. Réessayez.';
  END IF;

  IF v_type_mime NOT IN ('application/pdf', 'image/jpeg', 'image/png') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Le format de la preuve est invalide (PDF, JPEG ou PNG uniquement).';
  END IF;

  INSERT INTO public.demandes_equipe_preuves
    (demande_id, chemin, nom, type_mime, taille, ajoute_par, ajoute_le)
  VALUES
    (p_demande_id, p_chemin, trim(p_nom), v_type_mime, v_taille, p_responsable_id, now())
  ON CONFLICT (demande_id) DO UPDATE
  SET chemin = EXCLUDED.chemin,
      nom = EXCLUDED.nom,
      type_mime = EXCLUDED.type_mime,
      taille = EXCLUDED.taille,
      ajoute_par = EXCLUDED.ajoute_par,
      ajoute_le = EXCLUDED.ajoute_le;

  RETURN jsonb_build_object('taille_octets', v_taille, 'type_mime', v_type_mime);
END;
$$;

REVOKE ALL ON FUNCTION public.enregistrer_preuve_demande(uuid, uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enregistrer_preuve_demande(uuid, uuid, text, text)
  TO anon, authenticated;


-- ----------------------------------------------------------------------------
-- Page de partage : ajoute la preuve de traitement.
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
                END,
    'preuve', CASE WHEN pr.demande_id IS NULL THEN NULL
                   ELSE jsonb_build_object(
                     'chemin', pr.chemin,
                     'nom', pr.nom,
                     'type_mime', pr.type_mime,
                     'taille', pr.taille)
              END
  )
  FROM public.demandes_equipe_partages p
  JOIN public.demandes_equipe d ON d.id = p.demande_id
  LEFT JOIN public.employees e ON e.id = d.employee_id
  LEFT JOIN public.employees t ON t.id = d.traite_par
  LEFT JOIN public.demandes_equipe_documents doc ON doc.demande_id = d.id
  LEFT JOIN public.demandes_equipe_preuves pr ON pr.demande_id = d.id
  WHERE p.jeton = p_jeton
    AND p.expire_le > now();
$$;
