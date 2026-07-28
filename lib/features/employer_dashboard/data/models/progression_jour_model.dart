import '../../domain/entities/progression_jour.dart';

class ProgressionJourModel extends ProgressionJour {
  const ProgressionJourModel({
    required super.employeeId,
    required super.prenom,
    required super.totalTaches,
    required super.tachesConfirmees,
    required super.totalFait,
    required super.totalAbsent,
    required super.totalRefus,
    required super.totalAnnule,
    required super.pourcentage,
  });

  factory ProgressionJourModel.fromJson(Map<String, dynamic> json) {
    return ProgressionJourModel(
      employeeId: json['employee_id'] as String,
      prenom: json['prenom'] as String? ?? '',
      totalTaches: (json['total_taches'] as num?)?.toInt() ?? 0,
      tachesConfirmees: (json['taches_confirmees'] as num?)?.toInt() ?? 0,
      totalFait: (json['total_fait'] as num?)?.toInt() ?? 0,
      totalAbsent: (json['total_absent'] as num?)?.toInt() ?? 0,
      totalRefus: (json['total_refus'] as num?)?.toInt() ?? 0,
      // "total_annulé" avec accent dans le JSON Supabase
      totalAnnule: (json['total_annulé'] as num?)?.toInt() ?? 0,
      pourcentage: (json['pourcentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
