import 'package:equatable/equatable.dart';

class ProgressionJour extends Equatable {
  final String employeeId;
  final String prenom;
  final int totalTaches;
  final int tachesConfirmees;
  final int totalFait;
  final int totalAbsent;
  final int totalRefus;
  final int totalAnnule;
  final double pourcentage;

  const ProgressionJour({
    required this.employeeId,
    required this.prenom,
    required this.totalTaches,
    required this.tachesConfirmees,
    required this.totalFait,
    required this.totalAbsent,
    required this.totalRefus,
    required this.totalAnnule,
    required this.pourcentage,
  });

  @override
  List<Object?> get props => [employeeId];
}
