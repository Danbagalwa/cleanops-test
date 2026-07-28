import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/chat_message_model.dart';

// ── Interface ─────────────────────────────────────────────

abstract class ChatGroupeDatasource {
  Future<List<ChatMessageModel>> getMessages({int offset = 0, int limit = 50});
  Future<ChatMessageModel> envoyerMessage({
    required String auteurId,
    required String message,
  });
  Future<ChatMessageModel> epinglerMessage({
    required String messageId,
    required String epingleParId,
  });
  Future<ChatMessageModel> desepinglerMessage({required String messageId});
  Future<ChatMessageModel> supprimerMessage({
    required String messageId,
    required String supprimeParId,
  });
  Future<List<ChatMessageModel>> getMessagesEpingles();
  void initRealtime({required void Function(ChatMessageModel) onNew});
  Future<void> disposeRealtime();
}

// ── Implémentation ────────────────────────────────────────

class ChatGroupeDatasourceImpl implements ChatGroupeDatasource {
  static const _select = '*, auteur:auteur_id(prenom)';

  RealtimeChannel? _channel;

  @override
  Future<List<ChatMessageModel>> getMessages({
    int offset = 0,
    int limit = 50,
  }) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.chatGroupe)
          .select(_select)
          .eq('is_supprimé', false)
          .order('date_envoi', ascending: false)
          .range(offset, offset + limit - 1);

      return (data as List)
          .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ChatMessageModel> envoyerMessage({
    required String auteurId,
    required String message,
  }) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.chatGroupe)
          .insert({
            'auteur_id': auteurId,
            'message': message,
          })
          .select(_select)
          .single();
      return ChatMessageModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ChatMessageModel> epinglerMessage({
    required String messageId,
    required String epingleParId,
  }) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.chatGroupe)
          .update({
            'is_épinglé': true,
            'épinglé_par': epingleParId,
            'épinglé_le': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', messageId)
          .select(_select)
          .single();
      return ChatMessageModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ChatMessageModel> desepinglerMessage({
    required String messageId,
  }) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.chatGroupe)
          .update({
            'is_épinglé': false,
            'épinglé_par': null,
            'épinglé_le': null,
          })
          .eq('id', messageId)
          .select(_select)
          .single();
      return ChatMessageModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ChatMessageModel> supprimerMessage({
    required String messageId,
    required String supprimeParId,
  }) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.chatGroupe)
          .update({
            'is_supprimé': true,
            'supprimé_par': supprimeParId,
            'supprimé_le': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', messageId)
          .select(_select)
          .single();
      return ChatMessageModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ChatMessageModel>> getMessagesEpingles() async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.chatGroupe)
          .select(_select)
          .eq('is_épinglé', true)
          .eq('is_supprimé', false)
          .order('épinglé_le', ascending: false);

      return (data as List)
          .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  void initRealtime({required void Function(ChatMessageModel) onNew}) {
    _channel = SupabaseService.client
        .channel('chat_groupe_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseService.chatGroupe,
          callback: (payload) async {
            final id = payload.newRecord['id'] as String?;
            if (id == null) return;
            try {
              final data = await SupabaseService.client
                  .from(SupabaseService.chatGroupe)
                  .select(_select)
                  .eq('id', id)
                  .single();
              onNew(ChatMessageModel.fromJson(data));
            } catch (_) {}
          },
        )
        .subscribe();
  }

  @override
  Future<void> disposeRealtime() async {
    await _channel?.unsubscribe();
    _channel = null;
  }
}
