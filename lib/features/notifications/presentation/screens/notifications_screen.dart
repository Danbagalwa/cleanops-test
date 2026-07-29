import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/notification.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsNotifierProvider);
    final notifications = _unreadOnly
        ? state.notifications.where((item) => !item.isRead).toList()
        : state.notifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        surfaceTintColor: AppColors.rouge,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () {
            final employee = ref.read(employeeCourantProvider);
            context.backOrHome(
              employee?.isResponsable == true
                  ? AppRoutes.employerDashboard
                  : AppRoutes.employeeDashboard,
            );
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: state.isLoading ? null : _markAllAsRead,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Tout lire'),
            ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: state.isLoading
                ? null
                : () => ref.read(notificationsNotifierProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: () =>
            ref.read(notificationsNotifierProvider.notifier).load(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 80),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(
                          unread: state.unreadCount,
                          total: state.notifications.length,
                        ),
                        const SizedBox(height: 18),
                        SegmentedButton<bool>(
                          segments: [
                            const ButtonSegment(
                              value: false,
                              icon: Icon(Icons.inbox_outlined),
                              label: Text('Toutes'),
                            ),
                            ButtonSegment(
                              value: true,
                              icon:
                                  const Icon(Icons.mark_email_unread_outlined),
                              label: Text('Non lues (${state.unreadCount})'),
                            ),
                          ],
                          selected: {_unreadOnly},
                          showSelectedIcon: false,
                          onSelectionChanged: (selection) =>
                              setState(() => _unreadOnly = selection.first),
                        ),
                        if (state.error != null) ...[
                          const SizedBox(height: 14),
                          const _ErrorNotice(),
                        ],
                        const SizedBox(height: 14),
                        if (state.isLoading && state.notifications.isEmpty)
                          const _NotificationsSkeleton()
                        else if (notifications.isEmpty)
                          _EmptyState(unreadOnly: _unreadOnly)
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE7E9F2),
                              ),
                            ),
                            child: Column(
                              children: [
                                for (var index = 0;
                                    index < notifications.length;
                                    index++) ...[
                                  _NotificationTile(
                                    notification: notifications[index],
                                    onTap: () =>
                                        _openNotification(notifications[index]),
                                  ),
                                  if (index < notifications.length - 1)
                                    const Divider(
                                      height: 1,
                                      indent: 72,
                                      color: Color(0xFFE7E9F2),
                                    ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    final ok =
        await ref.read(notificationsNotifierProvider.notifier).markAllAsRead();
    if (!mounted) return;
    _feedback(
      ok
          ? 'Toutes les notifications ont été marquées comme lues.'
          : 'Nous n’avons pas pu mettre à jour les notifications.',
      success: ok,
    );
  }

  Future<void> _openNotification(AppNotification notification) async {
    final ok = await ref
        .read(notificationsNotifierProvider.notifier)
        .markAsRead(notification.id);
    if (!mounted) return;
    if (!ok) {
      _feedback(
        'La notification reste disponible. Sa lecture n’a pas pu être '
        'enregistrée.',
        success: false,
      );
      return;
    }
    final route = _routeFor(notification);
    if (route != null) context.go(route);
  }

  String? _routeFor(AppNotification notification) {
    return switch (notification.category) {
      NotificationCategory.absence => AppRoutes.presences,
      NotificationCategory.demande => AppRoutes.demandesResidents,
      NotificationCategory.transfert => AppRoutes.tachesDisponibles,
      NotificationCategory.planning => AppRoutes.planning,
      NotificationCategory.message => AppRoutes.memo,
      NotificationCategory.general => null,
    };
  }

  void _feedback(String message, {required bool success}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              success ? const Color(0xFF176B3A) : const Color(0xFF9F2D2D),
          content: Text(message),
        ),
      );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.unread, required this.total});

  final int unread;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.rouge, AppColors.rougeLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unread == 0
                      ? 'Vous êtes à jour'
                      : '$unread notification${unread > 1 ? 's' : ''} non lue'
                          '${unread > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total notification${total > 1 ? 's' : ''} récente'
                  '${total > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .74),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(notification.category);
    return Material(
      color: notification.isRead
          ? Colors.transparent
          : AppColors.rouge.withValues(alpha: .025),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _categoryIcon(notification.category),
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: AppColors.noir,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: notification.isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _relativeDate(notification.sentAt),
                      style: const TextStyle(
                        color: AppColors.grisText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead) ...[
                const SizedBox(width: 10),
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.rouge,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.unreadOnly});

  final bool unreadOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E9F2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 46,
            color: AppColors.grisMedium,
          ),
          const SizedBox(height: 12),
          Text(
            unreadOnly
                ? 'Aucune notification non lue'
                : 'Aucune notification pour le moment',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            unreadOnly
                ? 'Vous avez pris connaissance de toutes les informations.'
                : 'Les nouvelles informations importantes apparaîtront ici.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.grisDark,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Color(0xFFC2410C)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Les notifications n’ont pas pu être actualisées. Vous pouvez '
              'réessayer sans risque.',
              style: TextStyle(
                color: Color(0xFF9A3412),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        5,
        (_) => Container(
          height: 82,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE9EAF0),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

Color _categoryColor(NotificationCategory category) => switch (category) {
      NotificationCategory.planning => AppColors.rouge,
      NotificationCategory.absence => const Color(0xFFC2410C),
      NotificationCategory.demande => const Color(0xFF1769AA),
      NotificationCategory.transfert => const Color(0xFF00796B),
      NotificationCategory.message => const Color(0xFF7B1FA2),
      NotificationCategory.general => const Color(0xFF667085),
    };

IconData _categoryIcon(NotificationCategory category) => switch (category) {
      NotificationCategory.planning => Icons.calendar_month_outlined,
      NotificationCategory.absence => Icons.person_off_outlined,
      NotificationCategory.demande => Icons.inbox_outlined,
      NotificationCategory.transfert => Icons.swap_horiz_rounded,
      NotificationCategory.message => Icons.chat_bubble_outline_rounded,
      NotificationCategory.general => Icons.notifications_none_rounded,
    };

String _relativeDate(DateTime date) {
  final difference = DateTime.now().difference(date);
  if (!difference.isNegative && difference.inMinutes < 1) {
    return 'À l’instant';
  }
  if (!difference.isNegative && difference.inHours < 1) {
    return 'Il y a ${difference.inMinutes} min';
  }
  if (!difference.isNegative && difference.inDays < 1) {
    return 'Il y a ${difference.inHours} h';
  }
  if (!difference.isNegative && difference.inDays < 7) {
    return 'Il y a ${difference.inDays} j';
  }
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
