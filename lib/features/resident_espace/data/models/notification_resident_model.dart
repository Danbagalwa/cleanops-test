import '../../domain/entities/notification_resident.dart';

class NotificationResidentModel extends NotificationResident {
  const NotificationResidentModel({
    required super.id,
    required super.residentId,
    super.tacheJourId,
    required super.type,
    required super.message,
    required super.isLue,
    required super.createdAt,
  });

  factory NotificationResidentModel.fromJson(Map<String, dynamic> json) =>
      NotificationResidentModel(
        id: json['id'] as String,
        residentId: json['resident_id'] as String,
        tacheJourId: json['tache_jour_id'] as String?,
        type: TypeNotifResident.fromString(json['type'] as String? ?? ''),
        message: json['message'] as String,
        isLue: json['is_lue'] as bool? ?? false,
        createdAt: DateTime.parse(json['date_envoi'] as String),
      );
}
