import '../../domain/entities/tache_disponible.dart';
import '../../../tache_jour/data/models/tache_jour_model.dart';
import '../../../auth/data/models/employee_model.dart';

class TacheDisponibleModel extends TacheDisponible {
  const TacheDisponibleModel({
    required super.id,
    required super.tacheJourId,
    required super.motif,
    super.visibilite,
    super.employeeVisibleId,
    super.priseParId,
    super.datePrise,
    super.statut,
    super.libereParId,
    super.dateLiberation,
    super.dateExpiration,
    super.tacheJour,
    super.prisePar,
  });

  factory TacheDisponibleModel.fromJson(Map<String, dynamic> json) {
    return TacheDisponibleModel(
      id: json['id'] as String,
      tacheJourId: json['tache_jour_id'] as String,
      motif: MotifDisponible.fromString(json['motif'] as String? ?? 'Absence'),
      visibilite: VisibiliteType.fromString(
          json['visibilite'] as String? ?? 'TouteEquipe'),
      employeeVisibleId: json['employee_visible_id'] as String?,
      priseParId: json['prise_par'] as String?,
      datePrise: json['date_prise'] != null
          ? DateTime.parse(json['date_prise'] as String)
          : null,
      statut: StatutDisponible.fromString(
          json['statut'] as String? ?? 'Disponible'),
      libereParId: json['libere_par'] as String?,
      dateLiberation: json['date_liberation'] != null
          ? DateTime.parse(json['date_liberation'] as String)
          : null,
      dateExpiration: json['date_expiration'] != null
          ? DateTime.parse(json['date_expiration'] as String)
          : null,
      tacheJour: json['taches_jour'] != null
          ? TacheJourModel.fromJson(
              json['taches_jour'] as Map<String, dynamic>)
          : null,
      prisePar: json['employees'] != null
          ? EmployeeModel.fromJson(json['employees'] as Map<String, dynamic>)
          : null,
    );
  }
}
