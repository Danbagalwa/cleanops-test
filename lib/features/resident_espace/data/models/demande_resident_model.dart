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
  });

  factory DemandeResidentModel.fromJson(Map<String, dynamic> json) {
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
    );
  }
}
