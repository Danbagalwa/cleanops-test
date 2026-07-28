import '../../domain/entities/message_semaine.dart';

class MessageSemaineModel extends MessageSemaine {
  const MessageSemaineModel({
    required super.id,
    required super.contenu,
    required super.type,
    required super.isActif,
    required super.creePar,
    super.prenomCreePar,
    required super.dateCreation,
    super.dateDesactivation,
  });

  factory MessageSemaineModel.fromJson(Map<String, dynamic> json) {
    final auteurMap = json['cree_par_employe'] as Map<String, dynamic>?;
    return MessageSemaineModel(
      id: json['id'] as String,
      contenu: json['contenu'] as String? ?? '',
      type: _parseType(json['type'] as String? ?? ''),
      isActif: json['is_actif'] as bool? ?? false,
      creePar: json['créé_par'] as String,
      prenomCreePar: auteurMap?['prenom'] as String?,
      dateCreation: DateTime.parse(json['date_creation'] as String),
      dateDesactivation: json['date_desactivation'] != null
          ? DateTime.parse(json['date_desactivation'] as String)
          : null,
    );
  }

  static MessageType _parseType(String v) => switch (v) {
        'Automatique' => MessageType.automatique,
        'Fete'        => MessageType.fete,
        _             => MessageType.personnalise,
      };
}
