import 'package:equatable/equatable.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';

enum MotifDisponible {
  absence,
  transfert,
  surplus;

  String get label => switch (this) {
        MotifDisponible.absence => 'Absence',
        MotifDisponible.transfert => 'Transfert',
        MotifDisponible.surplus => 'Surplus',
      };

  static MotifDisponible fromString(String v) => switch (v) {
        'Transfert' => MotifDisponible.transfert,
        'Surplus' => MotifDisponible.surplus,
        _ => MotifDisponible.absence,
      };
}

enum VisibiliteType {
  touteEquipe,
  employeSpecifique;

  String get label => switch (this) {
        VisibiliteType.touteEquipe => 'TouteEquipe',
        VisibiliteType.employeSpecifique => 'EmployeSpecifique',
      };

  static VisibiliteType fromString(String v) => v == 'EmployeSpecifique'
      ? VisibiliteType.employeSpecifique
      : VisibiliteType.touteEquipe;
}

enum StatutDisponible {
  disponible,
  prise,
  expiree;

  String get label => switch (this) {
        StatutDisponible.disponible => 'Disponible',
        StatutDisponible.prise => 'Prise',
        StatutDisponible.expiree => 'Expirée',
      };

  static StatutDisponible fromString(String v) => switch (v) {
        'Prise' => StatutDisponible.prise,
        'Expirée' => StatutDisponible.expiree,
        _ => StatutDisponible.disponible,
      };
}

class TacheDisponible extends Equatable {
  final String id;
  final String tacheJourId;
  final MotifDisponible motif;
  final VisibiliteType visibilite;
  final String? employeeVisibleId;
  final String? priseParId;
  final DateTime? datePrise;
  final StatutDisponible statut;
  final String? libereParId;
  final DateTime? dateLiberation;
  final DateTime? dateExpiration;

  // Relations
  final TacheJour? tacheJour;
  final Employee? prisePar;

  const TacheDisponible({
    required this.id,
    required this.tacheJourId,
    required this.motif,
    this.visibilite = VisibiliteType.touteEquipe,
    this.employeeVisibleId,
    this.priseParId,
    this.datePrise,
    this.statut = StatutDisponible.disponible,
    this.libereParId,
    this.dateLiberation,
    this.dateExpiration,
    this.tacheJour,
    this.prisePar,
  });

  bool get estDisponible => statut == StatutDisponible.disponible;

  @override
  List<Object?> get props => [id, tacheJourId, motif, visibilite, statut];
}
