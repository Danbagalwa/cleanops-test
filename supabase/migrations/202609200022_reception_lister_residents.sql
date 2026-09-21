-- ============================================================================
-- Vue Réception, section Résidents : liste des résidents et de leur appartement
-- ============================================================================
-- OBJECTIF
--   La section Résidents s'ouvre sur un TABLEAU (un résident actif par ligne,
--   avec son appartement). Les actions (fiche, impression du calendrier,
--   message) partent de ce tableau.
--
-- CE QUI EST RENVOYÉ : une liste blanche de champs, rien de plus.
--   resident_id, prenom, nom, appartement_id, numero, etage.
--   Ni PIN, ni indicateur d'application, ni tâche, ni motif : la Réception ne
--   lit rien d'autre par cette fonction. (La gestion des PIN est un autre
--   chantier.)
--
-- PORTÉE
--   * Résidents ACTIFS seulement ; les inactifs n'apparaissent pas.
--   * Appartements de type 'Appartement' seulement (pas les aires communes).
--   * Un appartement à deux résidents donne deux lignes (une par résident).
--   * Tri : nom, prénom.
--
-- ⚠ Limite habituelle : tant que la RLS n'est pas activée (chantier séparé), la
-- table residents reste lisible en entier avec la clé publique. Cette fonction
-- garantit ce que la vue Réception DEMANDE et AFFICHE.
--
-- POUR ANNULER :
--   DROP FUNCTION public.reception_lister_residents();
-- ============================================================================

CREATE OR REPLACE FUNCTION public.reception_lister_residents()
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
        'etage', a.etage
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

REVOKE ALL ON FUNCTION public.reception_lister_residents() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reception_lister_residents()
  TO anon, authenticated;
