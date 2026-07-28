import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final String id;
  final String auteurId;
  final String prenomAuteur;
  final String message;
  final DateTime dateEnvoi;
  final bool isEpingle;
  final String? epingleParId;
  final DateTime? epingleLe;
  final bool isSupprime;
  final String? supprimeParId;
  final DateTime? supprimeLe;

  const ChatMessage({
    required this.id,
    required this.auteurId,
    required this.prenomAuteur,
    required this.message,
    required this.dateEnvoi,
    required this.isEpingle,
    this.epingleParId,
    this.epingleLe,
    required this.isSupprime,
    this.supprimeParId,
    this.supprimeLe,
  });

  bool get estVisible => !isSupprime;
  bool get estEpingle => isEpingle;

  @override
  List<Object?> get props => [id];
}
