import '../../reception/domain/reception_messages_models.dart';

/// Côté RESPONSABLE : les messages que la Réception lui transmet (demandes des
/// résidents qu'elle ne peut pas traiter elle-même, comme annuler ou reprogrammer
/// un ménage).
///
/// Le responsable peut y répondre (statut « Répondue », l'horaire n'a pas changé)
/// et les résoudre (statut « Résolue », l'horaire a vraiment été modifié). Ni
/// l'un ni l'autre ne modifie un planning : il le fait lui-même avant de
/// confirmer.
abstract class MessagesReceptionResponsableRepository {
  /// Tous les messages, les plus récents d'abord.
  Future<List<MessageTransmis>> messages();

  /// Répond au message (ou modifie la réponse déjà donnée). Statut : Répondue.
  Future<void> repondre({
    required String messageId,
    required String auteurId,
    required String reponse,
  });

  /// Marque le message comme résolu : l'horaire a été modifié.
  Future<void> resoudre({
    required String messageId,
    required String auteurId,
  });
}
