import 'package:equatable/equatable.dart';

enum AuteurType { employe, employeur }

class Memo extends Equatable {
  final String id;
  final String employeeId;
  final String message;
  final AuteurType auteur;
  final String auteurId;
  final String? auteurPrenom;
  final DateTime? tacheJourDate;
  final int? numeroSemaine;
  final bool isLu;
  final DateTime? dateLu;
  final DateTime dateEnvoi;

  const Memo({
    required this.id,
    required this.employeeId,
    required this.message,
    required this.auteur,
    required this.auteurId,
    this.auteurPrenom,
    this.tacheJourDate,
    this.numeroSemaine,
    required this.isLu,
    this.dateLu,
    required this.dateEnvoi,
  });

  bool get estDeEmployeur => auteur == AuteurType.employeur;
  bool get estDeEmploye => auteur == AuteurType.employe;

  @override
  List<Object?> get props => [id];
}

// Résumé préposée pour la liste (responsable)
class PreposeeResume {
  final String employeeId;
  final String prenom;
  final String? dernierMessage;
  final DateTime? dernierEnvoi;
  final int nonLusCount;

  const PreposeeResume({
    required this.employeeId,
    required this.prenom,
    this.dernierMessage,
    this.dernierEnvoi,
    this.nonLusCount = 0,
  });
}
