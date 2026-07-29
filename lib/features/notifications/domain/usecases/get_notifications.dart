import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/notification.dart';
import '../repositories/notifications_repository.dart';

class GetNotifications {
  const GetNotifications(this.repository);

  final NotificationsRepository repository;

  Future<Either<Failure, List<AppNotification>>> call(String recipientId) =>
      repository.getNotifications(recipientId);
}
