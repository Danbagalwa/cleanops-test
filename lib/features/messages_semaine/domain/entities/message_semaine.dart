import 'package:equatable/equatable.dart';

enum MessageType {
  personnalise, // 'Personnalisé'
  automatique, // 'Automatique'
  fete, // 'Fete'
}

class MessageSemaine extends Equatable {
  final String id;
  final String contenu;
  final MessageType type;
  final bool isActif;
  final String creePar;
  final String? prenomCreePar;
  final String? nomCreePar;
  final DateTime dateCreation;
  final DateTime? dateDesactivation;

  const MessageSemaine({
    required this.id,
    required this.contenu,
    required this.type,
    required this.isActif,
    required this.creePar,
    this.prenomCreePar,
    this.nomCreePar,
    required this.dateCreation,
    this.dateDesactivation,
  });

  /// « Prénom Nom » de l'auteur, ou « Responsable » s'il n'est pas connu.
  String get auteur {
    final n = [prenomCreePar, nomCreePar]
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty)
        .join(' ');
    return n.isEmpty ? 'Responsable' : n;
  }

  /// Copie archivée (retirée du tableau de bord).
  MessageSemaine archive([DateTime? le]) => MessageSemaine(
        id: id,
        contenu: contenu,
        type: type,
        isActif: false,
        creePar: creePar,
        prenomCreePar: prenomCreePar,
        nomCreePar: nomCreePar,
        dateCreation: dateCreation,
        dateDesactivation: dateDesactivation ?? le ?? DateTime.now().toUtc(),
      );

  @override
  List<Object?> get props => [id];
}
