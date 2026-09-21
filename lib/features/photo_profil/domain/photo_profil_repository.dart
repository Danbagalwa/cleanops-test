import 'dart:typed_data';

import '../../../core/services/compression_photo.dart';
import 'photo_profil_models.dart';

/// Photo de profil d'un utilisateur : lecture, remplacement, suppression.
abstract class PhotoProfilRepository {
  /// Octets JPEG de la photo, ou `null` si l'utilisateur n'en a pas.
  Future<Uint8List?> lire(ProprietairePhoto proprietaire);

  /// Remplace la photo (l'image DOIT avoir été réduite avant).
  Future<void> definir(ProprietairePhoto proprietaire, PhotoCompressee photo);

  Future<void> supprimer(ProprietairePhoto proprietaire);
}
