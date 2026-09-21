import 'reception_messages_models.dart';

/// Accès de la Réception aux messages qu'elle a transmis. Lecture seule : la
/// Réception ne modifie ni le statut ni la réponse.
abstract class ReceptionMessagesRepository {
  Future<List<MessageTransmis>> messages();
}
