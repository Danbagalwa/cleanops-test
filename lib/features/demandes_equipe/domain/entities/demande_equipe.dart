import 'package:equatable/equatable.dart';
import '../../../auth/domain/entities/employee.dart';

enum TypeDemandeEquipe {
  conge,
  absencePlanifiee,
  autre;

  String get label => switch (this) {
        TypeDemandeEquipe.conge => 'Conge',
        TypeDemandeEquipe.absencePlanifiee => 'AbsencePlanifiee',
        TypeDemandeEquipe.autre => 'Autre',
      };

  String get libelle => switch (this) {
        TypeDemandeEquipe.conge => 'Congé',
        TypeDemandeEquipe.absencePlanifiee => 'Absence planifiée',
        TypeDemandeEquipe.autre => 'Autre',
      };

  static TypeDemandeEquipe fromString(String v) => switch (v) {
        'AbsencePlanifiee' => TypeDemandeEquipe.absencePlanifiee,
        'Autre' => TypeDemandeEquipe.autre,
        _ => TypeDemandeEquipe.conge,
      };
}

enum StatutDemandeEquipe {
  enAttente,
  repondue,
  resolue;

  String get label => switch (this) {
        StatutDemandeEquipe.enAttente => 'EnAttente',
        StatutDemandeEquipe.repondue => 'Repondue',
        StatutDemandeEquipe.resolue => 'Resolue',
      };

  static StatutDemandeEquipe fromString(String v) => switch (v) {
        'Repondue' => StatutDemandeEquipe.repondue,
        'Resolue' => StatutDemandeEquipe.resolue,
        _ => StatutDemandeEquipe.enAttente,
      };
}

class DemandeEquipe extends Equatable {
  final String id;
  final String employeeId;
  final TypeDemandeEquipe type;
  final DateTime dateDebut;
  final DateTime? dateFin;
  final String motif;
  final StatutDemandeEquipe statut;
  final bool? approuve;
  final String? traiteParId;
  final String? noteResponsable;
  final DateTime createdAt;
  final DateTime? dateTraitement;

  // Relations (chargées via JOIN)
  final Employee? employee;
  final Employee? traitePar;

  // Document joint (métadonnées seulement — le contenu se lit à part, sur
  // demande : voir DemandeEquipeRepository.lireDocument).
  final String? documentNom;
  final String? documentTypeMime;
  final int? documentTaille;

  // Preuve de traitement jointe par le responsable (facultative ; même
  // principe : métadonnées seulement, fichier dans Storage).
  final String? preuveNom;
  final String? preuveTypeMime;
  final int? preuveTaille;

  const DemandeEquipe({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.dateDebut,
    this.dateFin,
    required this.motif,
    required this.statut,
    this.approuve,
    this.traiteParId,
    this.noteResponsable,
    required this.createdAt,
    this.dateTraitement,
    this.employee,
    this.traitePar,
    this.documentNom,
    this.documentTypeMime,
    this.documentTaille,
    this.preuveNom,
    this.preuveTypeMime,
    this.preuveTaille,
  });

  bool get enAttente => statut == StatutDemandeEquipe.enAttente;
  bool get resolue => statut == StatutDemandeEquipe.resolue;
  bool get estApprouvee => resolue && approuve == true;
  bool get estRefusee => resolue && approuve == false;

  /// Une demande "Autre" ne se traite pas par approbation/refus : elle est
  /// seulement marquée comme vue par le responsable (approuve reste null).
  bool get estVue => resolue && approuve == null;

  bool get aDocument => documentNom != null;
  bool get aPreuve => preuveNom != null;

  /// Emplacement Storage de la preuve (voir la migration 202609240038).
  String get cheminPreuve => 'preuves/$id';

  /// Copie portant les métadonnées d'un document tout juste joint (mise à jour
  /// locale après un envoi réussi, sans recharger toute la demande).
  DemandeEquipe avecDocument({
    required String nom,
    required String typeMime,
    required int taille,
  }) =>
      DemandeEquipe(
        id: id,
        employeeId: employeeId,
        type: type,
        dateDebut: dateDebut,
        dateFin: dateFin,
        motif: motif,
        statut: statut,
        approuve: approuve,
        traiteParId: traiteParId,
        noteResponsable: noteResponsable,
        createdAt: createdAt,
        dateTraitement: dateTraitement,
        employee: employee,
        traitePar: traitePar,
        documentNom: nom,
        documentTypeMime: typeMime,
        documentTaille: taille,
        preuveNom: preuveNom,
        preuveTypeMime: preuveTypeMime,
        preuveTaille: preuveTaille,
      );

  /// Copie portant les métadonnées d'une preuve tout juste jointe.
  DemandeEquipe avecPreuve({
    required String nom,
    required String typeMime,
    required int taille,
  }) =>
      DemandeEquipe(
        id: id,
        employeeId: employeeId,
        type: type,
        dateDebut: dateDebut,
        dateFin: dateFin,
        motif: motif,
        statut: statut,
        approuve: approuve,
        traiteParId: traiteParId,
        noteResponsable: noteResponsable,
        createdAt: createdAt,
        dateTraitement: dateTraitement,
        employee: employee,
        traitePar: traitePar,
        documentNom: documentNom,
        documentTypeMime: documentTypeMime,
        documentTaille: documentTaille,
        preuveNom: nom,
        preuveTypeMime: typeMime,
        preuveTaille: taille,
      );

  @override
  List<Object?> get props =>
      [id, statut, approuve, noteResponsable, documentNom, preuveNom];
}
