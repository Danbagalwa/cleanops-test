import '../../domain/entities/tache_jour.dart';
import '../../../appartements/data/models/appartement_model.dart';

class TacheJourModel extends TacheJour {
  const TacheJourModel({
    required super.id,
    super.planningTemplateId,
    required super.employeeId,
    required super.appartementId,
    required super.numeroSemaine,
    required super.semaineReelle,
    required super.jour,
    required super.periode,
    required super.numeroTache,
    super.minutesFinales,
    required super.statut,
    super.motifAbsent,
    super.confirmeParId,
    super.confirmedLe,
    super.isTransfertTemp,
    super.isAjoutee,
    super.appartement,
    super.employee,
  });

  factory TacheJourModel.fromJson(Map<String, dynamic> json) {
    return TacheJourModel(
      id: json['id'] as String,
      planningTemplateId: json['planning_template_id'] as String?,
      employeeId: json['employee_id'] as String,
      appartementId: json['appartement_id'] as String,
      numeroSemaine: json['numero_semaine'] as int,
      semaineReelle: DateTime.parse(json['semaine_reelle'] as String),
      jour: json['jour'] as String,
      periode: PeriodeTypeExtension.fromString(
        json['periode'] as String? ?? 'AM',
      ),
      numeroTache: json['numero_tache'] as int,
      minutesFinales: json['minutes_finales'] as int?,
      statut: StatutTache.fromString(
        json['statut'] as String? ?? 'NonCommencé',
      ),
      motifAbsent: json['motif_absent'] as String?,
      confirmeParId: json['confirme_par'] as String?,
      confirmedLe: json['confirme_le'] != null
          ? DateTime.parse(json['confirme_le'] as String)
          : null,
      isTransfertTemp: json['is_transfert_temp'] as bool? ?? false,
      isAjoutee: json['is_ajoutee'] as bool? ?? false,
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
      'semaine_reelle': semaineReelle.toIso8601String(),
      'jour': jour,
      'periode': periode.label,
      'numero_tache': numeroTache,
      if (minutesFinales != null) 'minutes_finales': minutesFinales,
      'statut': statut.label,
      if (motifAbsent != null) 'motif_absent': motifAbsent,
      'is_transfert_temp': isTransfertTemp,
      'is_ajoutee': isAjoutee,
    };
  }
}
