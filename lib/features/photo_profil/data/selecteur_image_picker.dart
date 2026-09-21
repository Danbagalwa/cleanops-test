import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../core/services/compression_photo.dart';
import '../domain/selecteur_image.dart';

/// Sélecteur réel (galerie ou appareil photo), fondé sur `image_picker`.
///
/// Demande au système de limiter d'emblée l'image à 1600 px : une photo de 12
/// mégapixels n'est ainsi presque jamais lue en entier. La réduction finale (carré
/// de 320 px sous 40 Ko) est faite ensuite par [CompresseurPhoto].
class SelecteurImagePicker implements SelecteurImage {
  final ImagePicker _picker;

  SelecteurImagePicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  @override
  Future<Uint8List?> choisir(SourcePhoto source) async {
    try {
      final fichier = await _picker.pickImage(
        source: switch (source) {
          SourcePhoto.galerie => ImageSource.gallery,
          SourcePhoto.appareil => ImageSource.camera,
        },
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (fichier == null) return null;
      return await fichier.readAsBytes();
    } catch (_) {
      throw const ErreurPhoto("Impossible d'ouvrir l'image choisie.");
    }
  }
}
