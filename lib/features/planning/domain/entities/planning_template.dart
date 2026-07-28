import 'package:equatable/equatable.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../../../appartements/domain/entities/appartement.dart';

class PlanningTemplate extends Equatable {
  final String id;
  final String employeeId;
  final String appartementId;
  final int numeroSemaine; // 1-4
  final String jour; // 'Lundi'...'Vendredi'
  final PeriodeType periode; // AM ou PM
  final int numeroTache; // 1-6
  final DateTime? dateCreation;

  // Relation (chargée via JOIN)
  final Appartement? appartement;

  const PlanningTemplate({
    required this.id,
    required this.employeeId,
    required this.appartementId,
    required this.numeroSemaine,
    required this.jour,
    required this.periode,
    required this.numeroTache,
    this.dateCreation,
    this.appartement,
  });

  // Minutes toujours via JOIN — jamais stockées ici
  int get minutesEstimees => appartement?.minutesBase ?? 0;
  String get displayTaille => appartement?.taille ?? '?';

  @override
  List<Object?> get props => [
    id,
    employeeId,
    appartementId,
    numeroSemaine,
    jour,
    periode,
    numeroTache,
  ];
}
