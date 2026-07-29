import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/notifications_repository.dart';

class MarkNotificationAsRead {
  const MarkNotificationAsRead(this.repository);

  final NotificationsRepository repository;

  Future<Either<Failure, Unit>> call(String notificationId) =>
      repository.markAsRead(notificationId);
}
