import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/compression_photo.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/photo_profil_models.dart';
import '../domain/photo_profil_repository.dart';

/// Implémentation Supabase Storage (bucket "photos-profil", privé). Voir la
/// migration 202609210032 pour les règles d'accès (storage.objects) et le
/// plafond de taille / type imposé par le bucket.
class PhotoProfilRepositoryImpl implements PhotoProfilRepository {
  static const _bucket = 'photos-profil';

  const PhotoProfilRepositoryImpl();

  String _chemin(ProprietairePhoto proprietaire) =>
      '${proprietaire.type.code}/${proprietaire.id}.jpg';

  @override
  Future<Uint8List?> lire(ProprietairePhoto proprietaire) async {
    try {
      return await SupabaseService.client.storage
          .from(_bucket)
          .download(_chemin(proprietaire));
    } on StorageException catch (e) {
      if (_estIntrouvable(e)) return null;
      throw const ErreurPhoto('Impossible de charger la photo de profil.');
    } catch (_) {
      throw const ErreurPhoto('Impossible de charger la photo de profil.');
    }
  }

  @override
  Future<void> definir(
    ProprietairePhoto proprietaire,
    PhotoCompressee photo,
  ) async {
    const erreur = "La photo n'a pas pu être enregistrée.";
    try {
      await SupabaseService.client.storage.from(_bucket).uploadBinary(
            _chemin(proprietaire),
            photo.octets,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    } on StorageException catch (e) {
      throw ErreurPhoto(_message(e, erreur));
    } catch (_) {
      throw const ErreurPhoto(erreur);
    }
  }

  @override
  Future<void> supprimer(ProprietairePhoto proprietaire) async {
    const erreur = "La photo n'a pas pu être supprimée.";
    try {
      await SupabaseService.client.storage
          .from(_bucket)
          .remove([_chemin(proprietaire)]);
    } on StorageException catch (e) {
      if (_estIntrouvable(e)) return; // déjà absente : rien à faire
      throw ErreurPhoto(_message(e, erreur));
    } catch (_) {
      throw const ErreurPhoto(erreur);
    }
  }

  bool _estIntrouvable(StorageException e) =>
      e.statusCode == '404' || e.statusCode == '400';

  /// Les refus métier de Storage (quota, type MIME refusé…) sont déjà
  /// rédigés de façon lisible ; toute autre erreur reçoit un message générique.
  String _message(StorageException e, String parDefaut) =>
      e.message.isNotEmpty ? e.message : parDefaut;
}
