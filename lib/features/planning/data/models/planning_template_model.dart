import '../../domain/entities/planning_template.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../../../appartements/data/models/appartement_model.dart';

class PlanningTemplateModel extends PlanningTemplate {
  const PlanningTemplateModel({
    required super.id,
    required super.employeeId,
    required super.appartementId,
    required super.numeroSemaine,
    required super.jour,
    required super.periode,
    required super.numeroTache,
    super.dateCreation,
    super.appartement,
  });

  factory PlanningTemplateModel.fromJson(Map<String, dynamic> json) {
    return PlanningTemplateModel(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      appartementId: json['appartement_id'] as String,
      numeroSemaine: json['numero_semaine'] as int,
      jour: json['jour'] as String,
      periode: PeriodeTypeExtension.fromString(
        json['periode'] as String? ?? 'AM',
      ),
      numeroTache: json['numero_tache'] as int,
      dateCreation: json['date_creation'] != null
          ? DateTime.parse(json['date_creation'] as String)
          : null,
      appartement: json['appartements'] != null
          ? AppartementModel.fromJson(
              json['appartements'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'appartement_id': appartementId,
      'numero_semaine': numeroSemaine,
      'jour': jour,
      'periode': periode.label,
      'numero_tache': numeroTache,
    };
  }
}
