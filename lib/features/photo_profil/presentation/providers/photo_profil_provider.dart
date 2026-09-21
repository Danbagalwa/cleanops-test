import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/compression_photo.dart';
import '../../data/photo_profil_repository_impl.dart';
import '../../data/selecteur_image_picker.dart';
import '../../domain/photo_profil_models.dart';
import '../../domain/photo_profil_repository.dart';
import '../../domain/selecteur_image.dart';

final photoProfilRepositoryProvider = Provider<PhotoProfilRepository>(
  (_) => const PhotoProfilRepositoryImpl(),
);

/// Choix d'une image (remplaçable dans les tests).
final selecteurImageProvider = Provider<SelecteurImage>(
  (_) => SelecteurImagePicker(),
);

/// Réduction d'une image choisie (remplaçable dans les tests).
typedef CompressionPhoto = Future<PhotoCompressee> Function(Uint8List octets);

final compressionPhotoProvider = Provider<CompressionPhoto>(
  (_) => (octets) => CompresseurPhoto.compresser(octets),
);

/// La photo d'un utilisateur : octets JPEG, ou `null` s'il n'en a pas.
///
/// Gardée en mémoire pour la session : les listes (résidents, équipe…) ne la
/// redemandent pas à chaque défilement. Elle est rechargée après un changement
/// de photo (`ref.invalidate`).
final photoProfilProvider = FutureProvider.autoDispose
    .family<Uint8List?, ProprietairePhoto>((ref, proprietaire) async {
  final lien = ref.keepAlive();
  try {
    return await ref.watch(photoProfilRepositoryProvider).lire(proprietaire);
  } catch (_) {
    lien.close(); // un échec n'est pas gardé : il sera retenté
    rethrow;
  }
});
