import '../../domain/entities/demande_equipe.dart';
import '../../../auth/data/models/employee_model.dart';

class DemandeEquipeModel extends DemandeEquipe {
  const DemandeEquipeModel({
    required super.id,
    required super.employeeId,
    required super.type,
    required super.dateDebut,
    super.dateFin,
    required super.motif,
    required super.statut,
    super.approuve,
    super.traiteParId,
    super.noteResponsable,
    required super.createdAt,
    super.dateTraitement,
    super.employee,
    super.traitePar,
    super.documentNom,
    super.documentTypeMime,
    super.documentTaille,
  });

  /// PostgREST embarque une relation enfant tantôt en liste, tantôt en objet
  /// unique selon les versions : on accepte les deux formes.
  static Map<String, dynamic>? _documentJson(dynamic embed) {
    if (embed is List) {
      return embed.isEmpty ? null : embed.first as Map<String, dynamic>;
    }
    return embed as Map<String, dynamic>?;
  }

  factory DemandeEquipeModel.fromJson(Map<String, dynamic> json) {
    final document = _documentJson(json['demandes_equipe_documents']);
    return DemandeEquipeModel(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      type: TypeDemandeEquipe.fromString(json['type'] as String),
      dateDebut: DateTime.parse(json['date_debut'] as String),
      dateFin: json['date_fin'] != null
          ? DateTime.parse(json['date_fin'] as String)
          : null,
      motif: json['motif'] as String,
      statut: StatutDemandeEquipe.fromString(json['statut'] as String),
      approuve: json['approuve'] as bool?,
      traiteParId: json['traite_par'] as String?,
      noteResponsable: json['note_responsable'] as String?,
      createdAt: json['date_creation'] != null
          ? DateTime.parse(json['date_creation'] as String)
          : DateTime.now(),
      dateTraitement: json['date_traitement'] != null
          ? DateTime.parse(json['date_traitement'] as String)
          : null,
      employee: json['employees'] != null
          ? EmployeeModel.fromJson(json['employees'] as Map<String, dynamic>)
          : null,
      traitePar: json['traite_par_employee'] != null
          ? EmployeeModel.fromJson(
              json['traite_par_employee'] as Map<String, dynamic>)
          : null,
      documentNom: document?['nom'] as String?,
      documentTypeMime: document?['type_mime'] as String?,
      documentTaille: (document?['taille'] as num?)?.toInt(),
    );
  }
}
