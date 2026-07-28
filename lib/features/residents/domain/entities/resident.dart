import 'package:equatable/equatable.dart';

class Resident extends Equatable {
  final String id;
  final String appartementId;
  final String nom;
  final String prenom;
  final bool hasPin;
  final bool aApplication;
  final bool isActif;
  final String? desactiveParId;
  final DateTime? dateDesactivation;
  final DateTime dateCreation;
  final DateTime dateMiseAJour;

  // Dénormalisé depuis le JOIN appartements(numero, taille)
  final String? numeroAppartement;
  final String? tailleAppartement;

  const Resident({
    required this.id,
    required this.appartementId,
    required this.nom,
    required this.prenom,
    this.hasPin = false,
    required this.aApplication,
    required this.isActif,
    this.desactiveParId,
    this.dateDesactivation,
    required this.dateCreation,
    required this.dateMiseAJour,
    this.numeroAppartement,
    this.tailleAppartement,
  });

  String get nomComplet => '$prenom $nom';

  String get statut {
    if (!isActif) return 'Inactif';
    return aApplication ? 'Inscrit' : 'Sans app';
  }

  String get initiales =>
      nom.length >= 2 ? nom.substring(0, 2).toUpperCase() : nom.toUpperCase();

  bool get aPin => hasPin;

  @override
  List<Object?> get props => [id];
}
