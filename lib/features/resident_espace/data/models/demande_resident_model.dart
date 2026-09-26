import '../../domain/entities/demande_resident.dart';

class DemandeResidentModel extends DemandeResident {
  const DemandeResidentModel({
    required super.id,
    required super.residentId,
    required super.type,
    super.tacheJourId,
    required super.motif,
    required super.statut,
    super.reponse,
    super.propositionDate,
    super.propositionPeriode,
    super.residentAccepte,
    required super.estUrgente,
    required super.createdAt,
    super.propositionNotes,
    super.propositionHasAnimal,
    super.propositionTypeAnimal,
    super.dateReponse,
    super.dateResolution,
    super.residentPrenom,
    super.residentNom,
    super.numeroAppartement,
    super.tailleAppartement,
    super.menageDate,
    super.menagePeriode,
  });

  /// [json] peut contenir, pour la vue responsable, `residents`
  /// (`prenom, nom, appartements(numero, taille)`) et `taches_jour`
  /// (`semaine_reelle, jour, periode`).
  factory DemandeResidentModel.fromJson(Map<String, dynamic> json) {
    final resident = json['residents'] as Map<String, dynamic>?;
    final appartement = resident?['appartements'] as Map<String, dynamic>?;
    final tache = json['taches_jour'] as Map<String, dynamic>?;

    // `semaine_reelle` porte la date réelle du ménage (pas le lundi).
    final semaine = tache?['semaine_reelle'] as String?;
    final menageDate = semaine == null ? null : DateTime.tryParse(semaine);
    DateTime? date(String cle) =>
        json[cle] is String ? DateTime.tryParse(json[cle] as String) : null;

    return DemandeResidentModel(
      id: json['id'] as String,
      residentId: json['resident_id'] as String,
      type: TypeDemande.fromString(json['type'] as String),
      tacheJourId: json['tache_jour_id'] as String?,
      motif: json['motif'] as String,
      statut: StatutDemande.fromString(json['statut'] as String),
      reponse: json['reponse'] as String?,
      propositionDate: json['proposition_date'] != null
          ? DateTime.parse(json['proposition_date'] as String)
          : null,
      propositionPeriode: json['proposition_periode'] as String?,
      residentAccepte: json['resident_accepte'] as bool?,
      estUrgente: json['est_urgente'] as bool? ?? false,
      createdAt: json['date_creation'] != null
          ? DateTime.parse(json['date_creation'] as String)
          : DateTime.now(),
      propositionNotes: json['proposition_notes'] as String?,
      propositionHasAnimal: json['proposition_has_animal'] as bool?,
      propositionTypeAnimal: json['proposition_type_animal'] as String?,
      dateReponse: date('date_reponse'),
      dateResolution: date('date_resolution'),
      residentPrenom: resident?['prenom'] as String?,
      residentNom: resident?['nom'] as String?,
      numeroAppartement: appartement?['numero']?.toString(),
      tailleAppartement: appartement?['taille']?.toString(),
      menageDate: menageDate,
      menagePeriode: tache?['periode'] as String?,
    );
  }
}
