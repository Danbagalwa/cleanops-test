import 'reception_avis_models.dart';

/// Accès de la Réception aux résidents à aviser.
///
/// La lecture et le traitement passent par des fonctions serveur : aucun accès
/// direct aux tables, donc aucun moyen d'atteindre un motif de non-réalisation.
abstract class ReceptionAvisRepository {
  /// Avis ouverts, plus ceux traités aujourd'hui.
  Future<List<AvisResident>> avis();

  Future<void> traiter({
    required String avisId,
    required String auteurId,
    required ActionAvis action,
    String? commentaire,
  });
}
