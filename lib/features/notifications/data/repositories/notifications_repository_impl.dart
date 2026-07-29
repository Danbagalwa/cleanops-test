import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_datasource.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  const NotificationsRepositoryImpl(this.datasource);

  final NotificationsDatasource datasource;

  @override
  Stream<List<AppNotification>> watchNotifications(String recipientId) =>
      datasource.watchNotifications(recipientId);

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications(
    String recipientId,
  ) async {
    try {
      return Right(await datasource.getNotifications(recipientId));
    } catch (error) {
      return Left(ServerFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> markAsRead(String notificationId) async {
    try {
      await datasource.markAsRead(notificationId);
      return const Right(unit);
    } catch (error) {
      return Left(ServerFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> markAllAsRead(String recipientId) async {
    try {
      await datasource.markAllAsRead(recipientId);
      return const Right(unit);
    } catch (error) {
      return Left(ServerFailure(error.toString()));
    }
  }
}
