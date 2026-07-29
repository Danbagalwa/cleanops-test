import 'package:equatable/equatable.dart';

enum NotificationCategory {
  planning,
  absence,
  demande,
  transfert,
  message,
  general;

  static NotificationCategory fromValue(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('absence') ||
        normalized.contains('presence') ||
        normalized.contains('retard')) {
      return NotificationCategory.absence;
    }
    if (normalized.contains('demande')) return NotificationCategory.demande;
    if (normalized.contains('transfert') || normalized.contains('disponible')) {
      return NotificationCategory.transfert;
    }
    if (normalized.contains('planning') ||
        normalized.contains('tache') ||
        normalized.contains('changement') ||
        normalized.contains('annulation')) {
      return NotificationCategory.planning;
    }
    if (normalized.contains('message') || normalized.contains('memo')) {
      return NotificationCategory.message;
    }
    return NotificationCategory.general;
  }
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.category,
    required this.message,
    required this.isRead,
    required this.sentAt,
    this.entityId,
    this.entityType,
    this.readAt,
  });

  final String id;
  final String recipientId;
  final String type;
  final NotificationCategory category;
  final String message;
  final String? entityId;
  final String? entityType;
  final bool isRead;
  final DateTime sentAt;
  final DateTime? readAt;

  AppNotification copyWith({bool? isRead, DateTime? readAt}) => AppNotification(
        id: id,
        recipientId: recipientId,
        type: type,
        category: category,
        message: message,
        entityId: entityId,
        entityType: entityType,
        isRead: isRead ?? this.isRead,
        sentAt: sentAt,
        readAt: readAt ?? this.readAt,
      );

  @override
  List<Object?> get props => [id, isRead, readAt];
}
