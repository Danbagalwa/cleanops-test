import 'dart:typed_data';

/// D'où vient l'image choisie.
enum SourcePhoto { galerie, appareil }

/// Choix d'une image par l'utilisateur. Séparé du reste pour pouvoir être
/// remplacé dans les tests (le vrai sélecteur ouvre une fenêtre du système).
abstract class SelecteurImage {
  /// Octets de l'image choisie, ou `null` si l'utilisateur annule.
  Future<Uint8List?> choisir(SourcePhoto source);
}
