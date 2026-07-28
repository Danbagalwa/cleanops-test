import '../../domain/entities/tache_aire_commune.dart';

class TacheAireCommuneModel extends TacheAireCommune {
  const TacheAireCommuneModel({
    required super.id,
    required super.categorie,
    required super.zone,
    required super.semaineDate,
    required super.statut,
    super.confirmeParId,
    super.confirmeParPrenom,
    super.confirmeLE,
    super.note,
  });

  factory TacheAireCommuneModel.fromJson(Map<String, dynamic> json) {
    final employeeMap = json['employees'] as Map<String, dynamic>?;
    return TacheAireCommuneModel(
      id: json['id'] as String,
      categorie: _parseCategorie(json['categorie'] as String),
      zone: json['zone'] as String,
      semaineDate: DateTime.parse(json['semaine_date'] as String),
      statut: _parseStatut(json['statut'] as String),
      confirmeParId: json['confirme_par'] as String?,
      confirmeParPrenom: employeeMap?['prenom'] as String?,
      confirmeLE: json['confirme_le'] != null
          ? DateTime.parse(json['confirme_le'] as String)
          : null,
      note: json['note'] as String?,
    );
  }

  static AireCategorie _parseCategorie(String v) => switch (v) {
        'Ascenseur' => AireCategorie.ascenseur,
        'Corridor' => AireCategorie.corridor,
        'Tapis' => AireCategorie.tapis,
        'Chute' => AireCategorie.chute,
        'Salon' => AireCategorie.salon,
        'WC' => AireCategorie.wc,
        _ => AireCategorie.corridor,
      };

  static AireStatut _parseStatut(String v) => switch (v) {
        'Fait' => AireStatut.fait,
        _ => AireStatut.aFaire,
      };
}
