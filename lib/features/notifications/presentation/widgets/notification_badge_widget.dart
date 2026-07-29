import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/notifications_provider.dart';

class NotificationBadgeIcon extends ConsumerWidget {
  const NotificationBadgeIcon({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationsCountProvider);
    final icon = Icon(
      count > 0
          ? Icons.notifications_rounded
          : Icons.notifications_none_rounded,
      color: color ?? AppColors.rouge,
    );
    if (count == 0) return icon;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      child: icon,
    );
  }
}
