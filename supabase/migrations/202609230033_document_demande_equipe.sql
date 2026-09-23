-- ============================================================================
-- Document joint à une demande d'équipe : Supabase Storage + métadonnées
-- ============================================================================
-- OBJECTIF
--   Une préposée peut joindre UN document (PDF ou image) à sa demande de congé
--   ou d'absence planifiée (ex. billet médical). Le responsable qui traite la
--   demande peut le consulter.
--
-- STOCKAGE : les OCTETS vont dans Supabase Storage (bucket
--   "documents-demandes-equipe", séparé du bucket des photos : deux types de
--   fichiers différents, deux buckets). Seules les MÉTADONNÉES (nom, type,
--   taille) restent dans une table Postgres, pour être embarquées dans la
--   liste des demandes sans exposer le contenu ni alourdir la base avec des
--   fichiers binaires (même décision que pour les photos de profil, voir la
--   migration 202609210032).
--
--   Chemin d'un objet : "{demande_id}" (pas d'extension : le type réel est
--   dans les métadonnées Storage, pas dans le nom du fichier).
--
-- CE QUI EST CRÉÉ
--   Le bucket "documents-demandes-equipe" (privé, 5 Mo max, PDF/JPEG/PNG).
--   demandes_equipe_documents : métadonnées seulement (une ligne par demande).
--   enregistrer_document_demande(demande_id, employee_id, chemin, nom)
--     -> valide la demande (appartient à l'employé, encore EnAttente), relit la
--        taille et le type RÉELS que Storage a enregistrés pour ce chemin (pas
--        ce que le client prétend), puis enregistre les métadonnées.
--
-- FLUX CÔTÉ APPLICATION
--   1. l'app envoie les octets directement à Storage (chemin = id de la
--      demande) ;
--   2. l'app appelle enregistrer_document_demande, qui valide et enregistre ;
--   3. si l'étape 2 échoue, l'app retire le fichier déjà envoyé (best effort)
--      pour ne pas laisser un fichier orphelin sans ligne de métadonnées.
--
-- ⚠ LIMITES
--   * Storage vérifie le type déclaré (Content-Type) et la taille à l'envoi,
--     mais ne relit pas le contenu du fichier : contrairement à l'ancienne
--     version (table + fonction), la signature du fichier (« est-ce VRAIMENT
--     un PDF ? ») n'est plus vérifiée côté serveur. Vérification côté
--     application seulement (garde-fou, pas une preuve).
--   * Comme le reste de l'application (clé publique, sans identité serveur),
--     rien n'empêche techniquement un appel d'utiliser un autre employee_id
--     que le sien pour cette fonction — même limite que partout ailleurs.
--   * Un seul document par demande (le chemin est fixe : renvoyer remplace).
--   * Pas de suppression par l'employé une fois joint.
--   * Le document ne peut être enregistré que pour une demande encore
--     EnAttente : une fois traitée, elle n'en accepte plus.
--   * Un fichier peut rester orphelin dans Storage si l'étape 3 (nettoyage
--     après échec) elle-même échoue (ex. app fermée entre-temps) : rare et
--     sans conséquence (invisible tant qu'aucune ligne de métadonnées n'y
--     pointe).
--
-- POUR ANNULER :
--   DROP FUNCTION public.enregistrer_document_demande(uuid, uuid, text, text);
--   DROP TABLE public.demandes_equipe_documents;
--   DROP POLICY "documents_demandes_remplacement" ON storage.objects;
--   DROP POLICY "documents_demandes_ecriture" ON storage.objects;
--   DROP POLICY "documents_demandes_lecture" ON storage.objects;
--   DELETE FROM storage.buckets WHERE id = 'documents-demandes-equipe';
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('documents-demandes-equipe', 'documents-demandes-equipe', false, 5242880,
        ARRAY['application/pdf', 'image/jpeg', 'image/png'])
ON CONFLICT (id) DO UPDATE
SET file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE POLICY "documents_demandes_lecture" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'documents-demandes-equipe');

CREATE POLICY "documents_demandes_ecriture" ON storage.objects
  FOR INSERT TO anon, authenticated
  WITH CHECK (bucket_id = 'documents-demandes-equipe');

CREATE POLICY "documents_demandes_remplacement" ON storage.objects
  FOR UPDATE TO anon, authenticated
  USING (bucket_id = 'documents-demandes-equipe')
  WITH CHECK (bucket_id = 'documents-demandes-equipe');


-- Table de métadonnées SEULEMENT : pas de contenu, pas de contrôle de taille à
-- faire ici (déjà imposé par le bucket, et de toute façon relu depuis Storage
-- par la fonction ci-dessous plutôt que déclaré par le client).
CREATE TABLE IF NOT EXISTS public.demandes_equipe_documents (
  demande_id uuid PRIMARY KEY REFERENCES public.demandes_equipe (id) ON DELETE CASCADE,
  nom text NOT NULL
    CONSTRAINT demandes_equipe_documents_nom CHECK (length(trim(nom)) BETWEEN 1 AND 150),
  type_mime text NOT NULL
    CONSTRAINT demandes_equipe_documents_mime
    CHECK (type_mime IN ('application/pdf', 'image/jpeg', 'image/png')),
  taille integer NOT NULL CHECK (taille BETWEEN 1 AND 5242880),
  ajoute_le timestamptz NOT NULL DEFAULT now()
);

-- Les octets sont dans Storage ; ici, seules nom / type_mime / taille /
-- ajoute_le restent lisibles en lecture directe (droit de COLONNE), pour être
-- embarquées dans la liste des demandes.
REVOKE ALL ON public.demandes_equipe_documents FROM PUBLIC, anon, authenticated;
GRANT SELECT (nom, type_mime, taille, ajoute_le) ON public.demandes_equipe_documents
  TO anon, authenticated;


-- ----------------------------------------------------------------------------
-- Enregistrer les métadonnées d'un document déjà envoyé dans Storage.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enregistrer_document_demande(
  p_demande_id uuid,
  p_employee_id uuid,
  p_chemin text,
  p_nom text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_statut text;
  v_type_mime text;
  v_taille bigint;
BEGIN
  SELECT statut INTO v_statut
  FROM public.demandes_equipe
  WHERE id = p_demande_id AND employee_id = p_employee_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Cette demande est introuvable.';
  END IF;

  IF v_statut <> 'EnAttente' THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Cette demande ne peut pas recevoir de document (déjà traitée).';
  END IF;

  IF length(trim(coalesce(p_nom, ''))) = 0 THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Le nom du document est obligatoire.';
  END IF;

  -- Taille et type RÉELS enregistrés par Storage pour ce chemin (pas ce que
  -- le client prétend) : Storage les renseigne depuis l'envoi effectif.
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
      MESSAGE = 'Le format du document est invalide (PDF, JPEG ou PNG uniquement).';
  END IF;

  INSERT INTO public.demandes_equipe_documents (demande_id, nom, type_mime, taille, ajoute_le)
  VALUES (p_demande_id, trim(p_nom), v_type_mime, v_taille, now())
  ON CONFLICT (demande_id) DO UPDATE
  SET nom = EXCLUDED.nom,
      type_mime = EXCLUDED.type_mime,
      taille = EXCLUDED.taille,
      ajoute_le = EXCLUDED.ajoute_le;

  RETURN jsonb_build_object('taille_octets', v_taille, 'type_mime', v_type_mime);
END;
$$;

REVOKE ALL ON FUNCTION public.enregistrer_document_demande(uuid, uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enregistrer_document_demande(uuid, uuid, text, text)
  TO anon, authenticated;

-- Nettoyage de l'ancienne version (contenu en base) : sans effet si elle
-- n'existe pas.
DROP FUNCTION IF EXISTS public.document_demande_contenu(uuid);
DROP FUNCTION IF EXISTS public.joindre_document_demande(uuid, uuid, text, text, text);
