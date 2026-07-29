import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/notification_model.dart';

abstract class NotificationsDatasource {
  Future<List<NotificationModel>> getNotifications(String recipientId);
  Stream<List<NotificationModel>> watchNotifications(String recipientId);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String recipientId);
}

class NotificationsDatasourceImpl implements NotificationsDatasource {
  @override
  Stream<List<NotificationModel>> watchNotifications(String recipientId) {
    return SupabaseService.table(SupabaseService.notifications)
        .stream(primaryKey: ['id'])
        .eq('destinataire_id', recipientId)
        .order('date_envoi', ascending: false)
        .limit(100)
        .map(
          (rows) =>
              rows.map((json) => NotificationModel.fromJson(json)).toList(),
        );
  }

  @override
  Future<List<NotificationModel>> getNotifications(String recipientId) async {
    try {
      final data = await SupabaseService.table(SupabaseService.notifications)
          .select()
          .eq('destinataire_id', recipientId)
          .order('date_envoi', ascending: false)
          .limit(100);
      return (data as List)
          .map(
            (json) => NotificationModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (error) {
      throw ServerException('Erreur chargement notifications : $error');
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseService.table(SupabaseService.notifications).update({
        'is_lue': true,
        'date_lue': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', notificationId);
    } catch (error) {
      throw ServerException('Erreur lecture notification : $error');
    }
  }

  @override
  Future<void> markAllAsRead(String recipientId) async {
    try {
      await SupabaseService.table(SupabaseService.notifications)
          .update({
            'is_lue': true,
            'date_lue': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('destinataire_id', recipientId)
          .eq('is_lue', false);
    } catch (error) {
      throw ServerException('Erreur lecture notifications : $error');
    }
  }
}
