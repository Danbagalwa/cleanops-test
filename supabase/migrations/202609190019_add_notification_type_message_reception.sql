-- ============================================================================
-- Nouveau type de notification : MessageReception
-- ============================================================================
-- Sert à prévenir l'administration (et, si la Réception le demande, l'employé
-- concerné) qu'un message a été transmis depuis la vue Réception.
-- Aucun type existant n'y correspond (NouveauMemo est la conversation
-- préposée / responsable).
--
-- Côté Dart, le type est lu comme une chaîne et classé par mot-clé : « message »
-- le range dans la catégorie « message », sans changement de code.
--
-- ⚠ IRRÉVERSIBLE : PostgreSQL ne permet pas de retirer une valeur d'un enum.
-- Elle n'a aucun effet tant que rien ne l'utilise. Migration volontairement
-- isolée : une nouvelle valeur d'enum ne peut pas être utilisée dans la
-- transaction qui l'ajoute, donc la fonction d'envoi vit dans la migration
-- suivante.
-- ============================================================================

ALTER TYPE public.notification_type ADD VALUE IF NOT EXISTS 'MessageReception';
