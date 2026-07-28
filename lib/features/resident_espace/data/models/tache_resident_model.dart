import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../../domain/entities/tache_resident.dart';

class TacheResidentModel extends TacheResident {
  const TacheResidentModel({
    required super.id,
    required super.appartementId,
    required super.semaineReelle,
    required super.jour,
    required super.periode,
    required super.statut,
    super.prenomPreposee,
  });

  factory TacheResidentModel.fromJson(Map<String, dynamic> json) {
    final emp = (json['employees!taches_jour_employee_id_fkey']
            ?? json['employees']) as Map<String, dynamic>?;
    return TacheResidentModel(
      id: json['id'] as String,
      appartementId: json['appartement_id'] as String,
      semaineReelle: DateTime.parse(json['semaine_reelle'] as String),
      jour: json['jour'] as String,
      periode: PeriodeTypeExtension.fromString(json['periode'] as String),
      statut: StatutTache.fromString(json['statut'] as String),
      prenomPreposee: emp?['prenom'] as String?,
    );
  }
}
