-- ============================================================================
-- Photo de profil : Supabase Storage
-- ============================================================================
-- OBJECTIF
--   Chaque utilisateur (employé de tout rôle, et résident) peut téléverser une
--   photo de profil. L'application la RÉDUIT avant l'envoi (carré de 320 px au
--   plus, JPEG sous 40 Ko) pour limiter l'espace utilisé.
--
-- STOCKAGE : Supabase Storage (bucket "photos-profil"), PAS une table.
--   Une image dans une table Postgres (bytea) alourdit la base elle-même (les
--   sauvegardes grossissent avec chaque photo, chaque lecture consomme des
--   ressources de la base au lieu d'être servie directement, pas de streaming
--   ni de mise en cache). Storage est fait pour ça : bucket privé, taille et
--   type MIME plafonnés par le bucket lui-même (98 304 octets = 96 Ko, JPEG
--   uniquement) — remplace les contrôles qui étaient dans la fonction SQL.
--
--   Chemin d'un objet : "{type}/{id}.jpg" (ex. "employe/<uuid>.jpg").
--
-- SÉCURITÉ (storage.objects)
--   Comme le reste de l'application (clé publique, sans identité serveur), les
--   règles ci-dessous n'imposent qu'une seule chose : rester DANS ce bucket.
--   Rien n'empêche techniquement un appel de modifier la photo d'un AUTRE
--   utilisateur dont on connaît l'identifiant — même limite que partout
--   ailleurs dans l'app, à régler avec la RLS / les sessions serveur (chantier
--   séparé). Le bucket est privé (pas d'URL publique) : il faut la clé anon
--   pour lire, comme pour tout le reste de l'app.
--
-- ⚠ CE QUI EST PERDU EN ABANDONNANT LA TABLE
--   * La vérification « l'utilisateur existe et est actif » avant d'accepter
--     une photo (l'ancienne fonction photo_profil_proprietaire_valide) :
--     disparaît, faute d'un endroit pour la faire (Storage ne connaît pas les
--     employés/résidents).
--   * Rien d'autre : largeur/hauteur n'étaient de toute façon jamais relues
--     par l'application.
--
-- POUR ANNULER :
--   DROP POLICY "photos_profil_suppression" ON storage.objects;
--   DROP POLICY "photos_profil_remplacement" ON storage.objects;
--   DROP POLICY "photos_profil_ecriture" ON storage.objects;
--   DROP POLICY "photos_profil_lecture" ON storage.objects;
--   DELETE FROM storage.buckets WHERE id = 'photos-profil';
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('photos-profil', 'photos-profil', false, 98304, ARRAY['image/jpeg'])
ON CONFLICT (id) DO UPDATE
SET file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE POLICY "photos_profil_lecture" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'photos-profil');

CREATE POLICY "photos_profil_ecriture" ON storage.objects
  FOR INSERT TO anon, authenticated
  WITH CHECK (bucket_id = 'photos-profil');

CREATE POLICY "photos_profil_remplacement" ON storage.objects
  FOR UPDATE TO anon, authenticated
  USING (bucket_id = 'photos-profil')
  WITH CHECK (bucket_id = 'photos-profil');

CREATE POLICY "photos_profil_suppression" ON storage.objects
  FOR DELETE TO anon, authenticated
  USING (bucket_id = 'photos-profil');

-- Nettoyage de l'ancienne version (table + fonctions), au cas où une session
-- précédente les aurait créées avant ce changement de conception. Sans effet
-- si elles n'existent pas.
DROP FUNCTION IF EXISTS public.supprimer_photo_profil(text, uuid);
DROP FUNCTION IF EXISTS public.photo_profil(text, uuid);
DROP FUNCTION IF EXISTS public.definir_photo_profil(text, uuid, text, integer, integer);
DROP FUNCTION IF EXISTS public.photo_profil_proprietaire_valide(text, uuid);
DROP TABLE IF EXISTS public.photos_profil;
