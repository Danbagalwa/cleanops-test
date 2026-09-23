-- ============================================================================
-- Vue Réception, section Équipe : ramenée à la spécification
-- ============================================================================
-- CORRECTION D'UNE ERREUR (migration 202609210023)
--   La spécification limite l'onglet Équipe à TROIS informations :
--     le nom de l'employé · sa présence du jour · son horaire du jour.
--   « Rien d'autre. » La fonction de 202609210023 renvoyait en plus la liste des
--   tâches de chaque employé (appartements, périodes, état) et les ménages en
--   attente d'attribution. Elle est REMPLACÉE : ces données ne sortent plus du
--   serveur vers la Réception.
--
-- POURQUOI CETTE LIMITE (raisonnement de la spécification)
--   La Réception ne confirme rien, ne réassigne rien, ne traite aucune tâche. Un
--   indicateur de charge de travail deviendrait une information sur la
--   performance de collègues, visible depuis un comptoir. L'unique chose utile :
--   l'horaire du jour, pour répondre honnêtement à un résident qui appelle
--   (« non, elle a terminé sa journée »).
--
-- JAMAIS RENVOYÉ : tâches, compteurs, pourcentages, progression, ménages,
--   appartements, motif d'une absence, horaire d'un autre jour. Seule la table
--   presences (aujourd'hui) est lue ; taches_jour, taches_disponibles et
--   motif_absent ne sont PLUS touchées.
--
-- CE QUI EST RENVOYÉ
--   {
--     "date": "2026-09-21",
--     "employes": [{
--        "id", "prenom", "nom",
--        "presence": "presente" | "absente" | "non_confirmee",
--        "journee":  "complete" | "matin" | "apres_midi" | null,
--        "heure_debut": "08:00" | null, "heure_fin": "13:00" | null
--     }]
--   }
--
-- RÈGLES DE PRÉSENCE (enum presence_statut)
--   aucune ligne aujourd'hui  -> non_confirmee
--   Absente                   -> absente (journee, heures : null)
--   TouteJournee              -> presente, journee « complete »
--   AM (absente le matin)     -> presente, journee « apres_midi » (elle travaille
--                                l'après-midi seulement)
--   PM (absente l'après-midi) -> presente, journee « matin »
--   heure_debut / heure_fin : les heures précisées par l'employé (informatives),
--   renvoyées seulement s'il est présent au moins une partie de la journée.
--
-- PORTÉE : employés ACTIFS de rôle 'Employé'. Tri : prénom, nom.
-- FUSEAU : America/Toronto. DROITS : anon et authenticated.
--
-- ORDRE DE DÉPLOIEMENT : appliquer cette migration AVANT de pousser le client qui
-- lit ces nouveaux champs (le client remplacé lisait aussi « taches », qu'il
-- tolère absent, mais pas les nouveaux codes de présence).
--
-- POUR ANNULER : ré-appliquer 202609210023 (qui rétablit l'ancienne fonction).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.reception_equipe_du_jour()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT jsonb_build_object(
    'date', (now() AT TIME ZONE 'America/Toronto')::date,
    'employes', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', e.id,
          'prenom', e.prenom,
          'nom', e.nom,
          'presence',
            CASE
              WHEN p.id IS NULL THEN 'non_confirmee'
              WHEN p.statut::text = 'Absente' THEN 'absente'
              ELSE 'presente'
            END,
          'journee',
            CASE
              WHEN p.id IS NULL OR p.statut::text = 'Absente' THEN NULL
              WHEN p.statut::text = 'AM' THEN 'apres_midi'
              WHEN p.statut::text = 'PM' THEN 'matin'
              ELSE 'complete'
            END,
          'heure_debut',
            CASE WHEN p.statut::text IN ('TouteJournee', 'AM', 'PM')
                 THEN left(p.heure_debut::text, 5) END,
          'heure_fin',
            CASE WHEN p.statut::text IN ('TouteJournee', 'AM', 'PM')
                 THEN left(p.heure_fin::text, 5) END
        )
        ORDER BY e.prenom, e.nom
      ),
      '[]'::jsonb
    )
  )
  FROM public.employees e
  LEFT JOIN public.presences p
    ON p.employee_id = e.id
   AND p.date = (now() AT TIME ZONE 'America/Toronto')::date
  WHERE e.is_actif
    AND e.role::text = 'Employé';
$$;

REVOKE ALL ON FUNCTION public.reception_equipe_du_jour() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reception_equipe_du_jour()
  TO anon, authenticated;
