import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/notifications/presentation/widgets/notification_badge_widget.dart';
import '../constants/app_colors.dart';
import '../router/app_router.dart';

class DashboardAccountActions extends ConsumerWidget {
  const DashboardAccountActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.go(AppRoutes.notifications),
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: .14),
            hoverColor: Colors.white.withValues(alpha: .24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: .28),
            ),
          ),
          icon: const NotificationBadgeIcon(color: Colors.white),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Mon profil',
          onPressed: () => context.go(AppRoutes.profil),
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: .14),
            hoverColor: Colors.white.withValues(alpha: .24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: .28),
            ),
          ),
          icon: const Icon(Icons.account_circle_rounded),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Se déconnecter',
          onPressed: () => _logout(context, ref),
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFF9F2D2D),
            backgroundColor: const Color(0xFFFFEDED),
            hoverColor: const Color(0xFFFFDADA),
          ),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: AppColors.rouge),
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez vous identifier à nouveau pour accéder à votre espace.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Rester connecté'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(authNotifierProvider.notifier).logout();
    if (context.mounted) context.go(AppRoutes.login);
  }
}
