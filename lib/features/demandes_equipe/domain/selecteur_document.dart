import 'entities/fichier_choisi.dart';

/// Choix d'un document (PDF ou image) par l'utilisateur. Séparé du reste pour
/// pouvoir être remplacé dans les tests (le vrai sélecteur ouvre une fenêtre
/// du système).
abstract class SelecteurDocument {
  /// `null` si l'utilisateur annule.
  Future<FichierChoisi?> choisir({required List<String> extensions});
}
