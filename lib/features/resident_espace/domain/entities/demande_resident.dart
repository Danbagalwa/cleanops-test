import 'package:equatable/equatable.dart';

enum TypeDemande {
  reprogrammer,
  annuler,
  commentaire,
  infoAppartement;

  String get label {
    switch (this) {
      case TypeDemande.reprogrammer:
        return 'Reprogrammer';
      case TypeDemande.annuler:
        return 'Annuler';
      case TypeDemande.commentaire:
        return 'Commentaire';
      case TypeDemande.infoAppartement:
        return 'InfoAppartement';
    }
  }

  static TypeDemande fromString(String v) {
    switch (v) {
      case 'Annuler':
        return TypeDemande.annuler;
      case 'Commentaire':
        return TypeDemande.commentaire;
      case 'InfoAppartement':
        return TypeDemande.infoAppartement;
      default:
        return TypeDemande.reprogrammer;
    }
  }
}

enum StatutDemande {
  enAttente,
  repondue,
  resolue;

  String get label {
    switch (this) {
      case StatutDemande.enAttente:
        return 'EnAttente';
      case StatutDemande.repondue:
        return 'Repondue';
      case StatutDemande.resolue:
        return 'Resolue';
    }
  }

  static StatutDemande fromString(String v) {
    switch (v) {
      case 'Repondue':
        return StatutDemande.repondue;
      case 'Resolue':
        return StatutDemande.resolue;
      default:
        return StatutDemande.enAttente;
    }
  }
}

class DemandeResident extends Equatable {
  final String id;
  final String residentId;
  final TypeDemande type;
  final String? tacheJourId;
  final String motif;
  final StatutDemande statut;
  final String? reponse;
  final DateTime? propositionDate;
  final String? propositionPeriode;
  final bool? residentAccepte;
  final bool estUrgente;
  final DateTime createdAt;

  // Proposition résident — type infoAppartement uniquement
  final String? propositionNotes;
  final bool? propositionHasAnimal;
  final String? propositionTypeAnimal;

  /// Date de la réponse du responsable (si elle est connue).
  final DateTime? dateReponse;

  /// Date à laquelle la demande a été résolue.
  final DateTime? dateResolution;

  // Contexte chargé pour la vue responsable (absent côté résident).
  final String? residentPrenom;
  final String? residentNom;
  final String? numeroAppartement;
  final String? tailleAppartement;

  /// Ménage visé par la demande (jour réel et période AM/PM).
  final DateTime? menageDate;
  final String? menagePeriode;

  const DemandeResident({
    required this.id,
    required this.residentId,
    required this.type,
    this.tacheJourId,
    required this.motif,
    required this.statut,
    this.reponse,
    this.propositionDate,
    this.propositionPeriode,
    this.residentAccepte,
    required this.estUrgente,
    required this.createdAt,
    this.propositionNotes,
    this.propositionHasAnimal,
    this.propositionTypeAnimal,
    this.dateReponse,
    this.dateResolution,
    this.residentPrenom,
    this.residentNom,
    this.numeroAppartement,
    this.tailleAppartement,
    this.menageDate,
    this.menagePeriode,
  });

  /// « Prénom Nom » du résident, ou `null` s'il n'a pas été chargé.
  String? get nomResident {
    final nom = [residentPrenom, residentNom]
        .where((p) => p != null && p.trim().isNotEmpty)
        .join(' ')
        .trim();
    return nom.isEmpty ? null : nom;
  }

  /// Reprend le contexte (résident, appartement, ménage) de [autre] : une
  /// demande renvoyée après une réponse ne le contient pas.
  DemandeResident avecContexteDe(DemandeResident autre) => DemandeResident(
        id: id,
        residentId: residentId,
        type: type,
        tacheJourId: tacheJourId,
        motif: motif,
        statut: statut,
        reponse: reponse,
        propositionDate: propositionDate,
        propositionPeriode: propositionPeriode,
        residentAccepte: residentAccepte,
        estUrgente: estUrgente,
        createdAt: createdAt,
        propositionNotes: propositionNotes,
        propositionHasAnimal: propositionHasAnimal,
        propositionTypeAnimal: propositionTypeAnimal,
        dateReponse: dateReponse ?? autre.dateReponse,
        dateResolution: dateResolution ?? autre.dateResolution,
        residentPrenom: residentPrenom ?? autre.residentPrenom,
        residentNom: residentNom ?? autre.residentNom,
        numeroAppartement: numeroAppartement ?? autre.numeroAppartement,
        tailleAppartement: tailleAppartement ?? autre.tailleAppartement,
        menageDate: menageDate ?? autre.menageDate,
        menagePeriode: menagePeriode ?? autre.menagePeriode,
      );

  bool get enAttente => statut == StatutDemande.enAttente;
  bool get repondue => statut == StatutDemande.repondue;
  bool get resolue => statut == StatutDemande.resolue;
  bool get attendsReponseResident =>
      statut == StatutDemande.repondue && residentAccepte == null;

  @override
  List<Object?> get props => [id];
}
