-- ============================================================================
-- Vue Réception, section Équipe : présence et horaire du jour
-- ============================================================================
-- OBJECTIF
--   La Réception voit QUI EST PRÉSENT aujourd'hui et L'HORAIRE DU JOUR de chaque
--   employé (les appartements à nettoyer, avec la période). Lecture seule.
--
-- CE QUI EST RENVOYÉ (liste blanche de champs, construite explicitement)
--   {
--     "date": "2026-09-21",                       -- jour du Québec
--     "employes": [{
--        "id", "prenom", "nom",
--        "presence": "presente" | "absente" | "absente_matin"
--                    | "absente_apres_midi" | "non_declaree",
--        "heure_debut": "08:00" | null, "heure_fin": "16:00" | null,
--        "taches": [{ "appartement_id", "numero", "periode", "etat" }]
--     }],
--     "en_attente": [{ "appartement_id", "numero", "periode" }]
--   }
--   etat d'une tâche : "a_faire" | "realise" | "non_realise".
--
-- RÈGLE OBLIGATOIRE : LE MOTIF D'UN NON-RÉALISÉ N'EST JAMAIS EXPOSÉ
--   taches_jour.motif_absent n'est ni lu ni renvoyé. Absent, Refus et Annulé
--   donnent le même état « non_realise », sans motif ni commentaire (même règle
--   que la fiche d'un appartement, migration 202609190020).
--   ⚠ Limite habituelle : tant que la RLS n'est pas activée (chantier séparé),
--   la table reste lisible avec la clé publique. Cette fonction garantit ce que
--   la vue Réception DEMANDE et AFFICHE.
--
-- RÈGLES DE PRÉSENCE (enum presence_statut, valeurs de l'application)
--   TouteJournee -> presente          Absente -> absente
--   AM           -> absente_matin     PM      -> absente_apres_midi
--   aucune ligne pour le jour        -> non_declaree
--   heure_debut / heure_fin sont informatives (registre du responsable).
--
-- RÈGLES DES TÂCHES (cohérentes avec le reste du projet)
--   * Le propriétaire d'une tâche est taches_jour.employee_id, que le transfert
--     met à jour : après un transfert, la tâche apparaît chez le NOUVEL employé.
--   * Une tâche LIBÉRÉE dans le pool (taches_disponibles.statut = 'Disponible')
--     n'est plus celle de l'employé : elle n'apparaît pas chez lui, elle est
--     listée à part dans « en_attente » (en attente d'attribution).
--   * Les tâches d'un employé absent restent chez lui tant qu'elles ne sont ni
--     transférées ni libérées.
--
-- PORTÉE : employés ACTIFS de rôle 'Employé' seulement (ni Admin, ni Réception,
-- ni rôles historiques). Tri : prénom, nom.
-- FUSEAU : America/Toronto pour « aujourd'hui ».
-- DROITS : exécutable par anon et authenticated (l'application accède à la base
-- avec la clé publique).
--
-- POUR ANNULER :
--   DROP FUNCTION public.reception_equipe_du_jour();
-- ============================================================================

CREATE OR REPLACE FUNCTION public.reception_equipe_du_jour()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'America/Toronto')::date;
  v_employes jsonb;
  v_attente jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(x.item ORDER BY x.prenom, x.nom), '[]'::jsonb)
  INTO v_employes
  FROM (
    SELECT
      e.prenom,
      e.nom,
      jsonb_build_object(
        'id', e.id,
        'prenom', e.prenom,
        'nom', e.nom,
        'presence', CASE p.statut::text
                      WHEN 'TouteJournee' THEN 'presente'
                      WHEN 'Absente' THEN 'absente'
                      WHEN 'AM' THEN 'absente_matin'
                      WHEN 'PM' THEN 'absente_apres_midi'
                      ELSE 'non_declaree'
                    END,
        'heure_debut', left(p.heure_debut::text, 5),
        'heure_fin', left(p.heure_fin::text, 5),
        'taches', (
          SELECT coalesce(
            jsonb_agg(
              jsonb_build_object(
                'appartement_id', a.id,
                'numero', a.numero,
                'periode', tj.periode::text,
                'etat', CASE
                          WHEN tj.statut::text = 'Fait' THEN 'realise'
                          WHEN tj.statut::text IN ('Absent', 'Refus', 'Annulé')
                            THEN 'non_realise'
                          ELSE 'a_faire'
                        END
              )
              ORDER BY tj.periode NULLS LAST, tj.numero_tache, a.numero
            ),
            '[]'::jsonb)
          FROM public.taches_jour tj
          JOIN public.appartements a ON a.id = tj.appartement_id
          WHERE tj.employee_id = e.id
            AND tj.semaine_reelle = v_today
            AND NOT EXISTS (
              SELECT 1 FROM public.taches_disponibles td
              WHERE td.tache_jour_id = tj.id AND td.statut::text = 'Disponible'
            )
        )
      ) AS item
    FROM public.employees e
    LEFT JOIN public.presences p
      ON p.employee_id = e.id AND p.date = v_today
    WHERE e.is_actif
      AND e.role::text = 'Employé'
  ) x;

  SELECT coalesce(
           jsonb_agg(
             jsonb_build_object(
               'appartement_id', a.id,
               'numero', a.numero,
               'periode', tj.periode::text
             )
             ORDER BY tj.periode NULLS LAST, a.numero),
           '[]'::jsonb)
  INTO v_attente
  FROM public.taches_jour tj
  JOIN public.appartements a ON a.id = tj.appartement_id
  WHERE tj.semaine_reelle = v_today
    AND tj.statut::text = 'NonCommencé'
    AND EXISTS (
      SELECT 1 FROM public.taches_disponibles td
      WHERE td.tache_jour_id = tj.id AND td.statut::text = 'Disponible'
    );

  RETURN jsonb_build_object(
    'date', v_today,
    'employes', v_employes,
    'en_attente', v_attente
  );
END;
$$;

REVOKE ALL ON FUNCTION public.reception_equipe_du_jour() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reception_equipe_du_jour()
  TO anon, authenticated;
