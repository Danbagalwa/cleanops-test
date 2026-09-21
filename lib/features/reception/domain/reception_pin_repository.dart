import 'reception_pin_models.dart';

/// Accès de la Réception aux PIN des résidents.
///
/// Le PIN est généré par le serveur ; la Réception ne le choisit pas et ne peut
/// pas le relire.
abstract class ReceptionPinRepository {
  Future<List<ResidentPin>> residents();

  /// Génère (ou réinitialise) le PIN et le renvoie UNE seule fois.
  Future<PinGenere> genererPin({
    required String residentId,
    required String auteurId,
  });
}
