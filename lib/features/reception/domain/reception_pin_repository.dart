import 'reception_pin_models.dart';

/// Accès de la Réception aux PIN des résidents.
///
/// Le PIN est généré par le serveur ; la Réception ne le choisit pas et ne peut
/// pas le relire.
abstract class ReceptionPinRepository {
  Future<List<ResidentPin>> residents();

  /// Fait passer un résident de « Inscrit » à « Sans app » (ou inversement).
  /// Ne touche ni au PIN, ni à l'état actif, ni au planning. Renvoie le nouveau
  /// statut (`true` = Inscrit).
  Future<bool> changerStatutApplication({
    required String residentId,
    required String auteurId,
    required bool aApplication,
  });

  /// Génère (ou réinitialise) le PIN et le renvoie UNE seule fois.
  Future<PinGenere> genererPin({
    required String residentId,
    required String auteurId,
  });
}
