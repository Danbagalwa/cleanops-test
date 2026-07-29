import '../../domain/entities/notification.dart';

class NotificationModel extends AppNotification {
  const NotificationModel({
    required super.id,
    required super.recipientId,
    required super.type,
    required super.category,
    required super.message,
    required super.isRead,
    required super.sentAt,
    super.entityId,
    super.entityType,
    super.readAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'General';
    return NotificationModel(
      id: json['id'] as String,
      recipientId: json['destinataire_id'] as String,
      type: type,
      category: NotificationCategory.fromValue(type),
      message: json['message'] as String? ?? 'Nouvelle notification',
      entityId: json['entity_id'] as String?,
      entityType: json['entity_type'] as String?,
      isRead: json['is_lue'] as bool? ?? false,
      sentAt: DateTime.tryParse(json['date_envoi'] as String? ?? '') ??
          DateTime.now(),
      readAt: DateTime.tryParse(json['date_lue'] as String? ?? ''),
    );
  }
}
