-- ============================================================================
-- Vue Réception, section PIN : changer le statut d'un résident (Inscrit / Sans app)
-- ============================================================================
-- OBJECTIF
--   Dans l'onglet PIN, la Réception peut faire passer un résident de « Inscrit »
--   (il utilise l'application) à « Sans app » (il ne l'utilise pas), et
--   inversement. Le statut est residents.a_application, le même que l'Admin
--   modifie ; il décide notamment si le résident reçoit les notifications de
--   l'application ou s'il doit être prévenu à la main (onglet « À aviser »).
--
-- CE QUE FAIT CETTE MIGRATION
--   reception_changer_statut_application(resident, auteur, nouvelle valeur) :
--     * l'auteur doit être un employé ACTIF de rôle 'Reception' ;
--     * le résident doit être ACTIF, sur un appartement de type 'Appartement' ;
--     * refus si le résident a déjà ce statut (message clair) ;
--     * met à jour a_application et écrit une trace ;
--     * renvoie {"a_application": true|false}.
--
-- CE QUE CELA NE FAIT PAS (volontairement)
--   * Ne touche PAS au PIN : passer en « Sans app » ne supprime pas le PIN, et
--     passer en « Inscrit » n'en crée pas (la Réception le génère à part).
--   * Ne désactive ni ne réactive le résident (is_actif), et ne modifie aucun
--     ménage ni aucun planning.
--   * Ne ferme pas les avis « À aviser » déjà ouverts.
--
-- TRACE : journal_statut_application_residents (qui, quel résident, nouveau
--   statut, quand).
--
-- ⚠ LIMITES
--   * L'auteur est un paramètre validé, pas authentifié (clé publique, sans
--     identité) ; sans RLS (report volontaire). La table residents reste
--     modifiable directement avec la clé publique, comme pour l'Admin.
--   * Observation (hors périmètre) : authenticate_resident ne regarde pas
--     a_application. Un résident « Sans app » qui possède un PIN pourrait encore
--     se connecter au portail.
--
-- POUR ANNULER :
--   DROP FUNCTION public.reception_changer_statut_application(uuid, uuid, boolean);
--   DROP TABLE public.journal_statut_application_residents;
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.journal_statut_application_residents (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  resident_id uuid NOT NULL REFERENCES public.residents (id),
  auteur_id uuid NOT NULL REFERENCES public.employees (id),
  a_application boolean NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_journal_statut_app_residents_resident
  ON public.journal_statut_application_residents (resident_id, cree_le DESC);
CREATE INDEX IF NOT EXISTS idx_journal_statut_app_residents_auteur
  ON public.journal_statut_application_residents (auteur_id);


CREATE OR REPLACE FUNCTION public.reception_changer_statut_application(
  p_resident_id uuid,
  p_auteur_id uuid,
  p_a_application boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_actuel boolean;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.employees
    WHERE id = p_auteur_id AND is_actif AND role::text = 'Reception'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Auteur invalide ou inactif.';
  END IF;

  IF p_a_application IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Statut invalide.';
  END IF;

  SELECT coalesce(r.a_application, false)
  INTO v_actuel
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

  IF v_actuel = p_a_application THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Le résident a déjà ce statut.';
  END IF;

  UPDATE public.residents
  SET a_application = p_a_application
  WHERE id = p_resident_id;

  INSERT INTO public.journal_statut_application_residents
    (resident_id, auteur_id, a_application)
  VALUES (p_resident_id, p_auteur_id, p_a_application);

  RETURN jsonb_build_object('a_application', p_a_application);
END;
$$;

REVOKE ALL ON FUNCTION public.reception_changer_statut_application(uuid, uuid, boolean)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reception_changer_statut_application(uuid, uuid, boolean)
  TO anon, authenticated;
