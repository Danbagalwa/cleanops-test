import '../../domain/entities/chat_message.dart';

class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.id,
    required super.auteurId,
    required super.prenomAuteur,
    required super.message,
    required super.dateEnvoi,
    required super.isEpingle,
    super.epingleParId,
    super.epingleLe,
    required super.isSupprime,
    super.supprimeParId,
    super.supprimeLe,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final auteur = json['auteur'] as Map<String, dynamic>?;
    return ChatMessageModel(
      id: json['id'] as String,
      auteurId: json['auteur_id'] as String,
      prenomAuteur: auteur?['prenom'] as String? ?? '',
      message: json['message'] as String,
      dateEnvoi: DateTime.parse(json['date_envoi'] as String).toLocal(),
      isEpingle: json['is_épinglé'] as bool? ?? false,
      epingleParId: json['épinglé_par'] as String?,
      epingleLe: json['épinglé_le'] != null
          ? DateTime.parse(json['épinglé_le'] as String).toLocal()
          : null,
      isSupprime: json['is_supprimé'] as bool? ?? false,
      supprimeParId: json['supprimé_par'] as String?,
      supprimeLe: json['supprimé_le'] != null
          ? DateTime.parse(json['supprimé_le'] as String).toLocal()
          : null,
    );
  }
}
