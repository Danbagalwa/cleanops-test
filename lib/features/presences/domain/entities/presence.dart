import 'package:equatable/equatable.dart';
import '../../../auth/domain/entities/employee.dart';

enum StatutPresence {
  present,
  absent,
  absentMatin,
  absentApresMidi;

  // Valeurs exactes de l'enum presence_statut en base
  String get label => switch (this) {
        StatutPresence.present => 'TouteJournee',
        StatutPresence.absent => 'Absente',
        StatutPresence.absentMatin => 'AM',
        StatutPresence.absentApresMidi => 'PM',
      };

  String get libelle => switch (this) {
        StatutPresence.present => 'Présente — toute la journée',
        StatutPresence.absent => 'Absente — toute la journée',
        StatutPresence.absentMatin => 'Absente — matin (AM)',
        StatutPresence.absentApresMidi => 'Absente — après-midi (PM)',
      };

  bool get estAbsent => this != StatutPresence.present;

  static StatutPresence fromString(String v) => switch (v) {
        'TouteJournee' => StatutPresence.present,
        'AM' => StatutPresence.absentMatin,
        'PM' => StatutPresence.absentApresMidi,
        _ => StatutPresence.absent,
      };
}

class Presence extends Equatable {
  final String id;
  final String employeeId;
  final DateTime date;
  final StatutPresence statut;
  final DateTime? confirmedLe;
  final bool alerteEnvoyee;
  final String? valideParId;
  final Employee? employee;

  const Presence({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.statut,
    this.confirmedLe,
    this.alerteEnvoyee = false,
    this.valideParId,
    this.employee,
  });

  bool get estConfirmee => confirmedLe != null;

  @override
  List<Object?> get props =>
      [id, employeeId, date, statut, alerteEnvoyee, valideParId];
}
