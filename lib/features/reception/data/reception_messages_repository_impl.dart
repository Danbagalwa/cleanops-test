import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/reception_messages_models.dart';
import '../domain/reception_messages_repository.dart';
import '../domain/reception_residents_repository.dart' show ReceptionErreur;

/// Implémentation Supabase : un seul appel de FONCTION serveur.
class ReceptionMessagesRepositoryImpl implements ReceptionMessagesRepository {
  const ReceptionMessagesRepositoryImpl();

  static const _erreur = 'Impossible de charger les messages transmis.';

  @override
  Future<List<MessageTransmis>> messages() async {
    try {
      final data =
          await SupabaseService.client.rpc('reception_messages_transmis');
      return [
        for (final item in (data as List? ?? const []))
          MessageTransmis.fromJson(item as Map<String, dynamic>),
      ];
    } on PostgrestException catch (e) {
      throw ReceptionErreur(
          e.code == 'P0001' && e.message.isNotEmpty ? e.message : _erreur);
    } catch (_) {
      throw const ReceptionErreur(_erreur);
    }
  }
}
