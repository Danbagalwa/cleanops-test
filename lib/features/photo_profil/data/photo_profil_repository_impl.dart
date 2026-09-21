import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/compression_photo.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/photo_profil_models.dart';
import '../domain/photo_profil_repository.dart';

/// Implémentation Supabase : uniquement des appels de FONCTIONS serveur (la table
/// n'est pas accessible directement).
class PhotoProfilRepositoryImpl implements PhotoProfilRepository {
  const PhotoProfilRepositoryImpl();

  @override
  Future<Uint8List?> lire(ProprietairePhoto proprietaire) async {
    try {
      final data = await SupabaseService.client.rpc(
        'photo_profil',
        params: {'p_type': proprietaire.type.code, 'p_id': proprietaire.id},
      );
      if (data == null) return null;
      return octetsDepuisBase64(
        (data as Map<String, dynamic>)['photo_base64'] as String?,
      );
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
      await SupabaseService.client.rpc(
        'definir_photo_profil',
        params: {
          'p_type': proprietaire.type.code,
          'p_id': proprietaire.id,
          'p_photo_base64': base64Encode(photo.octets),
          'p_largeur': photo.largeur,
          'p_hauteur': photo.hauteur,
        },
      );
    } on PostgrestException catch (e) {
      throw ErreurPhoto(_message(e, erreur));
    } catch (_) {
      throw const ErreurPhoto(erreur);
    }
  }

  @override
  Future<void> supprimer(ProprietairePhoto proprietaire) async {
    const erreur = "La photo n'a pas pu être supprimée.";
    try {
      await SupabaseService.client.rpc(
        'supprimer_photo_profil',
        params: {'p_type': proprietaire.type.code, 'p_id': proprietaire.id},
      );
    } on PostgrestException catch (e) {
      throw ErreurPhoto(_message(e, erreur));
    } catch (_) {
      throw const ErreurPhoto(erreur);
    }
  }

  /// Les refus métier du serveur (code P0001) sont déjà rédigés pour
  /// l'utilisateur ; toute autre erreur reçoit un message générique.
  String _message(PostgrestException e, String parDefaut) =>
      e.code == 'P0001' && e.message.isNotEmpty ? e.message : parDefaut;
}
