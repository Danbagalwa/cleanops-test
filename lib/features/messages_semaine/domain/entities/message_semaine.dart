import 'package:equatable/equatable.dart';

enum MessageType {
  personnalise, // 'Personnalisé'
  automatique,  // 'Automatique'
  fete,         // 'Fete'
}

class MessageSemaine extends Equatable {
  final String id;
  final String contenu;
  final MessageType type;
  final bool isActif;
  final String creePar;
  final String? prenomCreePar;
  final DateTime dateCreation;
  final DateTime? dateDesactivation;

  const MessageSemaine({
    required this.id,
    required this.contenu,
    required this.type,
    required this.isActif,
    required this.creePar,
    this.prenomCreePar,
    required this.dateCreation,
    this.dateDesactivation,
  });

  @override
  List<Object?> get props => [id];
}
