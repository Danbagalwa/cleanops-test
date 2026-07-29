import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/notifications_datasource.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../domain/entities/notification.dart';
import '../../domain/repositories/notifications_repository.dart';

final notificationsDatasourceProvider = Provider<NotificationsDatasource>(
  (_) => NotificationsDatasourceImpl(),
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepositoryImpl(
    ref.watch(notificationsDatasourceProvider),
  ),
);

class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;

  int get unreadCount => notifications.where((item) => !item.isRead).length;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      NotificationsState(
        notifications: notifications ?? this.notifications,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this.repository, this.recipientId)
      : super(const NotificationsState()) {
    if (recipientId.isNotEmpty) {
      load();
      _subscription = repository.watchNotifications(recipientId).listen(
        (items) => state = state.copyWith(
          notifications: items,
          isLoading: false,
          clearError: true,
        ),
        onError: (_) {
          // Le chargement manuel reste disponible si le temps réel est coupé.
        },
      );
    }
  }

  final NotificationsRepository repository;
  final String recipientId;
  StreamSubscription<List<AppNotification>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (recipientId.isEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await repository.getNotifications(recipientId);
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (items) => state = state.copyWith(
        isLoading: false,
        notifications: items,
        clearError: true,
      ),
    );
  }

  Future<bool> markAsRead(String id) async {
    final index = state.notifications.indexWhere((item) => item.id == id);
    if (index < 0 || state.notifications[index].isRead) return true;
    final previous = state.notifications;
    state = state.copyWith(
      notifications: previous
          .map(
            (item) => item.id == id
                ? item.copyWith(isRead: true, readAt: DateTime.now())
                : item,
          )
          .toList(),
      clearError: true,
    );
    final result = await repository.markAsRead(id);
    return result.fold(
      (failure) {
        state = state.copyWith(
          notifications: previous,
          error: failure.message,
        );
        return false;
      },
      (_) => true,
    );
  }

  Future<bool> markAllAsRead() async {
    if (state.unreadCount == 0) return true;
    final previous = state.notifications;
    final now = DateTime.now();
    state = state.copyWith(
      notifications: previous
          .map((item) => item.copyWith(isRead: true, readAt: now))
          .toList(),
      clearError: true,
    );
    final result = await repository.markAllAsRead(recipientId);
    return result.fold(
      (failure) {
        state = state.copyWith(
          notifications: previous,
          error: failure.message,
        );
        return false;
      },
      (_) => true,
    );
  }
}

final notificationsNotifierProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final recipientId = ref.watch(employeeCourantProvider)?.id ?? '';
  return NotificationsNotifier(
    ref.watch(notificationsRepositoryProvider),
    recipientId,
  );
});

final unreadNotificationsCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsNotifierProvider).unreadCount,
);
