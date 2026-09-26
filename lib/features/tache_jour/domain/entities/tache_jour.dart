import 'package:equatable/equatable.dart';
import '../../../appartements/domain/entities/appartement.dart';
import '../../../auth/domain/entities/employee.dart';

enum StatutTache {
  nonCommence,
  fait,
  absent,
  refus,
  annule;

  String get label {
    switch (this) {
      case StatutTache.nonCommence:
        return 'NonCommencé';
      case StatutTache.fait:
        return 'Fait';
      case StatutTache.absent:
        return 'Absent';
      case StatutTache.refus:
        return 'Refus';
      case StatutTache.annule:
        return 'Annulé';
    }
  }

  /// Libellé à AFFICHER (`label` est la valeur en base, ex. « NonCommencé »).
  String get libelle => switch (this) {
        StatutTache.nonCommence => 'À faire',
        StatutTache.fait => 'Fait',
        StatutTache.absent => 'Absent',
        StatutTache.refus => 'Refus',
        StatutTache.annule => 'Annulé',
      };

  static StatutTache fromString(String value) {
    switch (value) {
      case 'Fait':
        return StatutTache.fait;
      case 'Absent':
        return StatutTache.absent;
      case 'Refus':
        return StatutTache.refus;
      case 'Annulé':
        return StatutTache.annule;
      default:
        return StatutTache.nonCommence;
    }
  }
}

enum PeriodeType { am, pm }

extension PeriodeTypeExtension on PeriodeType {
  String get label => this == PeriodeType.am ? 'AM' : 'PM';

  static PeriodeType fromString(String value) =>
      value == 'PM' ? PeriodeType.pm : PeriodeType.am;
}

class TacheJour extends Equatable {
  final String id;
  final String? planningTemplateId;
  final String employeeId;
  final String appartementId;
  final int numeroSemaine; // 1-4
  final DateTime semaineReelle; // date RÉELLE de la tâche (voir dateDuJour)
  final String jour; // 'Lundi', 'Mardi'...
  final PeriodeType periode; // AM ou PM
  final int numeroTache; // 1-8
  final int? minutesFinales; // calculé via JOIN sur apartments
  final StatutTache statut;
  final String? motifAbsent; // obligatoire si statut = Absent
  final String? confirmeParId;
  final DateTime? confirmedLe;
  final bool isTransfertTemp;
  final bool isAjoutee;

  // Relations (optionnelles — chargées via JOIN)
  final Appartement? appartement;
  final Employee? employee;

  const TacheJour({
    required this.id,
    this.planningTemplateId,
    required this.employeeId,
    required this.appartementId,
    required this.numeroSemaine,
    required this.semaineReelle,
    required this.jour,
    required this.periode,
    required this.numeroTache,
    this.minutesFinales,
    required this.statut,
    this.motifAbsent,
    this.confirmeParId,
    this.confirmedLe,
    this.isTransfertTemp = false,
    this.isAjoutee = false,
    this.appartement,
    this.employee,
  });

  // Minutes toujours via appartement (JOIN) — jamais stockées directement
  int get minutesEstimees => appartement?.minutesBase ?? minutesFinales ?? 0;

  String get displayTaille => appartement?.taille ?? '?';

  /// Date du ménage, sans l'heure. `semaine_reelle` contient déjà la date
  /// RÉELLE de la tâche (génération serveur : lundi + décalage du jour),
  /// malgré son nom.
  DateTime? get dateDuJour =>
      DateTime(semaineReelle.year, semaineReelle.month, semaineReelle.day);

  bool get estConfirmee => statut != StatutTache.nonCommence;

  bool get peutEtreModifiee =>
      statut == StatutTache.nonCommence || statut == StatutTache.fait;

  @override
  List<Object?> get props => [
        id,
        employeeId,
        appartementId,
        numeroSemaine,
        semaineReelle,
        jour,
        periode,
        numeroTache,
        statut,
      ];
}
