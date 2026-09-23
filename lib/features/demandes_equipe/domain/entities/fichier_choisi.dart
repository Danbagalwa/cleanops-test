import 'dart:typed_data';

/// Un fichier tout juste choisi par l'utilisateur, avant tout contrôle
/// (taille, format).
class FichierChoisi {
  final String nom;
  final String? extension;
  final Uint8List octets;

  const FichierChoisi({
    required this.nom,
    required this.extension,
    required this.octets,
  });
}
