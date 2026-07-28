import '../../domain/entities/memo.dart';

class MemoModel extends Memo {
  const MemoModel({
    required super.id,
    required super.employeeId,
    required super.message,
    required super.auteur,
    required super.auteurId,
    super.auteurPrenom,
    super.tacheJourDate,
    super.numeroSemaine,
    required super.isLu,
    super.dateLu,
    required super.dateEnvoi,
  });

  factory MemoModel.fromJson(Map<String, dynamic> json) {
    // JOIN: .select('*, auteur_employe:auteur_id(prenom)')
    final auteurMap = json['auteur_employe'] as Map<String, dynamic>?;
    return MemoModel(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      message: json['message'] as String? ?? '',
      auteur: _parseAuteur(json['auteur'] as String? ?? ''),
      auteurId: json['auteur_id'] as String,
      auteurPrenom: auteurMap?['prenom'] as String?,
      tacheJourDate: json['tache_jour_date'] != null
          ? DateTime.parse(json['tache_jour_date'] as String)
          : null,
      numeroSemaine: json['numero_semaine'] as int?,
      isLu: json['is_lu'] as bool? ?? false,
      dateLu: json['date_lu'] != null
          ? DateTime.parse(json['date_lu'] as String)
          : null,
      dateEnvoi: json['date_envoi'] != null
          ? DateTime.parse(json['date_envoi'] as String)
          : DateTime.now(),
    );
  }

  static AuteurType _parseAuteur(String v) => switch (v) {
        'Employeur' => AuteurType.employeur,
        _ => AuteurType.employe,
      };
}
