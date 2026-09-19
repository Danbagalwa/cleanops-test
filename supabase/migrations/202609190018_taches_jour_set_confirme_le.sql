-- ============================================================================
-- taches_jour.confirmé_le : enregistrer l'heure à laquelle une tâche est traitée
-- ============================================================================
-- PROBLÈME
--   La colonne taches_jour."confirmé_le" existe mais n'a JAMAIS été écrite :
--   0 sur 39 tâches « Fait » l'ont renseignée (l'application ne met à jour que
--   statut et motif_absent). La vue Réception doit afficher « Effectué
--   aujourd'hui à [heure] » : sans cette valeur, l'heure n'a aucune source
--   (seule date_mise_a_jour bougerait, et elle change à n'importe quelle
--   modification, pas seulement à la confirmation).
--
-- CORRECTIF
--   Trigger BEFORE UPDATE OF statut :
--     * le statut passe à autre chose que 'NonCommencé' (Fait, Absent, Refus,
--       Annulé) -> confirmé_le = maintenant ;
--     * le statut revient à 'NonCommencé' (correction) -> confirmé_le = NULL.
--   Un changement qui ne touche pas au statut ne modifie pas confirmé_le.
--
-- PORTÉE / LIMITES
--   * Les 39 tâches déjà « Fait » n'ont pas d'heure et n'en auront pas : il
--     n'existe aucune source fiable pour la reconstituer. Sans effet pour la
--     vue Réception, qui ne s'intéresse qu'au jour courant.
--   * confirmé_par n'est pas renseigné : le serveur ne connaît pas l'utilisateur
--     (l'application accède aux tables avec la clé publique, sans identité).
--   * La colonne est aussi remplie pour Absent / Refus / Annulé ; elle n'est
--     jamais exposée à la Réception avec le motif.
--
-- POUR ANNULER :
--   DROP TRIGGER taches_jour_set_confirme_le ON public.taches_jour;
--   DROP FUNCTION public.set_confirme_le_tache();
-- ============================================================================

CREATE OR REPLACE FUNCTION public.set_confirme_le_tache()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.statut IS DISTINCT FROM OLD.statut THEN
    IF NEW.statut::text = 'NonCommencé' THEN
      NEW."confirmé_le" := NULL;
    ELSE
      NEW."confirmé_le" := now();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS taches_jour_set_confirme_le ON public.taches_jour;
CREATE TRIGGER taches_jour_set_confirme_le
BEFORE UPDATE OF statut ON public.taches_jour
FOR EACH ROW
EXECUTE FUNCTION public.set_confirme_le_tache();
