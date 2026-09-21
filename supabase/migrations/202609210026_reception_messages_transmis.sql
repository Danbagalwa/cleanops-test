-- ============================================================================
-- Vue Réception, section « Messages transmis » : lecture des messages envoyés
-- ============================================================================
-- OBJECTIF
--   La Réception voit, en LECTURE SEULE, les messages qu'elle a envoyés à
--   l'administration (table messages_reception, migration 202609190021), avec
--   leur statut : En attente · Répondue · Résolue.
--
-- CE QUI EST RENVOYÉ (liste blanche, construite explicitement)
--   id, appartement_id, numero, message, auteur_prenom, transmis_employe,
--   employe_prenom (seulement si le message a été transmis à l'employé), statut,
--   reponse, date_creation, date_reponse, date_resolution.
--   Les dates sont rendues à l'heure du Québec, au format
--   « AAAA-MM-JJTHH:MI:SS » (sans fuseau) pour éviter tout décalage côté client.
--
-- PORTÉE
--   Les messages de TOUTE la Réception (pas seulement de l'auteur connecté : le
--   serveur ne connaît pas l'utilisateur), du plus récent au plus ancien,
--   200 au plus.
--
-- STATUTS : EnAttente, Repondue, Resolue (enum demande_statut). Aucun statut
--   « Traitée » : ce libellé est abandonné.
--
-- ⚠ LIMITES
--   * Aucune fonction ne permet encore de répondre ou de résoudre : l'écran de
--     l'Admin qui lit ces messages n'est pas construit. Tant qu'il n'existe pas,
--     tous les messages restent « En attente ».
--   * messages_reception est sans RLS (report volontaire).
--
-- POUR ANNULER :
--   DROP FUNCTION public.reception_messages_transmis();
-- ============================================================================

CREATE OR REPLACE FUNCTION public.reception_messages_transmis()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT coalesce(jsonb_agg(x.item ORDER BY x.cree DESC), '[]'::jsonb)
  FROM (
    SELECT
      m.date_creation AS cree,
      jsonb_build_object(
        'id', m.id,
        'appartement_id', a.id,
        'numero', a.numero,
        'message', m.message,
        'auteur_prenom', au.prenom,
        'transmis_employe', m.transmettre_employe,
        'employe_prenom',
          CASE WHEN m.transmettre_employe THEN em.prenom END,
        'statut', m.statut::text,
        'reponse', m.reponse,
        'date_creation',
          to_char(m.date_creation AT TIME ZONE 'America/Toronto',
                  'YYYY-MM-DD"T"HH24:MI:SS'),
        'date_reponse',
          to_char(m.date_reponse AT TIME ZONE 'America/Toronto',
                  'YYYY-MM-DD"T"HH24:MI:SS'),
        'date_resolution',
          to_char(m.date_resolution AT TIME ZONE 'America/Toronto',
                  'YYYY-MM-DD"T"HH24:MI:SS')
      ) AS item
    FROM public.messages_reception m
    JOIN public.appartements a ON a.id = m.appartement_id
    JOIN public.employees au ON au.id = m.auteur_id
    LEFT JOIN public.employees em ON em.id = m.employee_id
    ORDER BY m.date_creation DESC
    LIMIT 200
  ) x;
$$;

REVOKE ALL ON FUNCTION public.reception_messages_transmis() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reception_messages_transmis()
  TO anon, authenticated;
