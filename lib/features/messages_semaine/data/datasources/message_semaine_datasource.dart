import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/message_semaine.dart';
import '../models/message_semaine_model.dart';

abstract class MessageSemaineDatasource {
  Future<MessageSemaineModel?> getMessageActif();
  Future<List<MessageSemaineModel>> getHistorique();
  Future<MessageSemaineModel> creerMessage(
    String contenu,
    MessageType type,
    String creeParId,
  );
  Future<void> desactiverMessage(String id);
}

class MessageSemaineDatasourceImpl implements MessageSemaineDatasource {
  static const _table = 'messages_semaine';
  static const _kSelect =
      'id, contenu, type, is_actif, créé_par, date_creation, date_desactivation';

  @override
  Future<MessageSemaineModel?> getMessageActif() async {
    try {
      final data = await SupabaseService.client
          .from(_table)
          .select(_kSelect)
          .eq('is_actif', true)
          .maybeSingle();
      if (data == null) return null;
      return MessageSemaineModel.fromJson(data);
    } catch (e) {
      throw ServerException('Erreur chargement message actif : $e');
    }
  }

  @override
  Future<List<MessageSemaineModel>> getHistorique() async {
    try {
      final data = await SupabaseService.client
          .from(_table)
          .select(_kSelect)
          .order('date_creation', ascending: false);
      return (data as List)
          .map((j) => MessageSemaineModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Erreur chargement historique messages : $e');
    }
  }

  @override
  Future<MessageSemaineModel> creerMessage(
    String contenu,
    MessageType type,
    String creeParId,
  ) async {
    try {
      final data = await SupabaseService.client
          .from(_table)
          .insert({
            'contenu': contenu,
            'type': _typeToString(type),
            'is_actif': true,
            'créé_par': creeParId,
          })
          .select(_kSelect)
          .single();
      return MessageSemaineModel.fromJson(data);
    } catch (e) {
      throw ServerException('Erreur création message : $e');
    }
  }

  @override
  Future<void> desactiverMessage(String id) async {
    try {
      await SupabaseService.client
          .from(_table)
          .update({
            'is_actif': false,
            'date_desactivation': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      throw ServerException('Erreur désactivation message : $e');
    }
  }

  static String _typeToString(MessageType t) => switch (t) {
        MessageType.automatique  => 'Automatique',
        MessageType.fete         => 'Fete',
        MessageType.personnalise => 'Personnalisé',
      };
}
