import '../../domain/entities/resident.dart';

class ResidentModel extends Resident {
  const ResidentModel({
    required super.id,
    required super.appartementId,
    required super.nom,
    required super.prenom,
    super.hasPin,
    required super.aApplication,
    required super.isActif,
    super.desactiveParId,
    super.dateDesactivation,
    required super.dateCreation,
    required super.dateMiseAJour,
    super.numeroAppartement,
    super.tailleAppartement,
  });

  // .select('id, appartement_id, nom, prenom, has_pin, a_application,
  //          is_actif, desactive_par, date_desactivation,
  //          date_creation, date_mise_a_jour,
  //          appartements(numero, taille)')
  factory ResidentModel.fromJson(Map<String, dynamic> json) {
    final apt = json['appartements'] as Map<String, dynamic>?;
    return ResidentModel(
      id: json['id'] as String,
      appartementId: json['appartement_id'] as String,
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      hasPin: json['has_pin'] as bool? ?? false,
      aApplication: json['a_application'] as bool? ?? false,
      isActif: json['is_actif'] as bool? ?? true,
      desactiveParId: json['desactive_par'] as String?,
      dateDesactivation: json['date_desactivation'] != null
          ? DateTime.parse(json['date_desactivation'] as String)
          : null,
      dateCreation: DateTime.parse(json['date_creation'] as String),
      dateMiseAJour: DateTime.parse(json['date_mise_a_jour'] as String),
      numeroAppartement: apt?['numero'] as String?,
      tailleAppartement: apt?['taille']?.toString(),
    );
  }
}
