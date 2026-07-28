import '../../domain/entities/presence.dart';
import '../../../auth/data/models/employee_model.dart';

class PresenceModel extends Presence {
  const PresenceModel({
    required super.id,
    required super.employeeId,
    required super.date,
    required super.statut,
    super.confirmedLe,
    super.alerteEnvoyee,
    super.valideParId,
    super.employee,
  });

  factory PresenceModel.fromJson(Map<String, dynamic> json) {
    return PresenceModel(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      date: DateTime.parse(json['date'] as String),
      statut: StatutPresence.fromString(json['statut'] as String? ?? 'Absent'),
      confirmedLe: json['confirme_le'] != null
          ? DateTime.parse(json['confirme_le'] as String)
          : null,
      alerteEnvoyee: json['alerte_responsable_envoyee'] as bool? ?? false,
      valideParId: json['valide_par'] as String?,
      employee: json['employees'] != null
          ? EmployeeModel.fromJson(json['employees'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toInsert(String employeeId, DateTime date,
      StatutPresence statut) {
    return {
      'employee_id': employeeId,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'statut': statut.label,
      'confirme_le': DateTime.now().toIso8601String(),
    };
  }
}
