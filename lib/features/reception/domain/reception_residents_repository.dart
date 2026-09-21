import 'reception_models.dart';

/// Erreur affichable à la réception (message déjà rédigé en français).
class ReceptionErreur implements Exception {
  final String message;

  const ReceptionErreur(this.message);

  @override
  String toString() => message;
}

/// Accès de la Réception aux appartements, en lecture seule, plus l'envoi d'un
/// message à l'administration.
///
/// Toutes les lectures passent par des fonctions serveur qui ne renvoient que
/// des champs autorisés. Cette interface n'expose aucun accès direct aux
/// tâches, donc aucun moyen d'atteindre le motif d'un non-réalisé.
abstract class ReceptionResidentsRepository {
  /// Tous les résidents actifs avec leur appartement (une ligne par résident).
  Future<List<ResidentLigne>> residents();

  /// `null` si l'appartement n'existe pas.
  Future<FicheAppartement?> fiche(String appartementId);

  /// Appartements sans occupant actif (où l'on peut inscrire un résident).
  Future<List<AppartementLibre>> appartementsLibres();

  /// Responsables qu'on peut désigner comme demandeur d'une inscription.
  Future<List<ResponsableDemandeur>> responsables();

  /// Inscrit un résident sur un appartement libre, à la demande d'un
  /// responsable. N'assigne AUCUN ménage. La date d'arrivée est remplie par le
  /// serveur.
  Future<ResidentInscrit> inscrireResident({
    required String appartementId,
    required String auteurId,
    required String prenom,
    required String nom,
    required String demandeParId,
    required bool aApplication,
  });

  Future<void> envoyerMessage({
    required String appartementId,
    required String auteurId,
    required NatureDemande nature,
    required String message,
    required bool transmettreEmploye,
  });
}
