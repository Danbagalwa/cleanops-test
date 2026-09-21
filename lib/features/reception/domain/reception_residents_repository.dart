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

  Future<void> envoyerMessage({
    required String appartementId,
    required String auteurId,
    required NatureDemande nature,
    required String message,
    required bool transmettreEmploye,
  });
}
