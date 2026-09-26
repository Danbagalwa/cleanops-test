import 'package:flutter/material.dart';
import '../constants/app_sizes.dart';
import '../errors/user_friendly_error.dart';
import 'notification_app.dart';

class AppErrorNotice extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AppErrorNotice({
    super.key,
    required this.error,
    this.onRetry,
    this.retryLabel = 'Réessayer',
  });

  @override
  Widget build(BuildContext context) {
    final content = UserFriendlyError.from(error);
    final colors = _colorsFor(content.kind);
    final icon = _iconFor(content.kind);

    return Semantics(
      liveRegion: true,
      label: '${content.title}. ${content.message}',
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.foreground.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.foreground.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Icon(icon, color: colors.foreground, size: 26),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    content.title,
                    style: TextStyle(
                      color: colors.title,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    content.message,
                    style: TextStyle(
                      color: colors.title.withValues(alpha: 0.78),
                      height: 1.4,
                      fontSize: 14,
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: AppSizes.md),
                    FilledButton.icon(
                      onPressed: onRetry,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.foreground,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.md,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(retryLabel),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppFeedback {
  AppFeedback._();

  static void showError(BuildContext context, Object? error) =>
      NotificationApp.depuisErreur(context, error);
}

({Color background, Color border, Color foreground, Color title}) _colorsFor(
  UserErrorKind kind,
) {
  if (kind == UserErrorKind.connection ||
      kind == UserErrorKind.unavailable ||
      kind == UserErrorKind.session) {
    return (
      background: const Color(0xFFFFF8E8),
      border: const Color(0xFFF2D58A),
      foreground: const Color(0xFF9A6700),
      title: const Color(0xFF594214),
    );
  }

  return (
    background: const Color(0xFFFFF3F1),
    border: const Color(0xFFF2C4BE),
    foreground: const Color(0xFFB7473A),
    title: const Color(0xFF592F2A),
  );
}

IconData _iconFor(UserErrorKind kind) {
  return switch (kind) {
    UserErrorKind.connection => Icons.cloud_off_rounded,
    UserErrorKind.session => Icons.lock_clock_rounded,
    UserErrorKind.permission => Icons.shield_outlined,
    UserErrorKind.duplicate => Icons.content_copy_rounded,
    UserErrorKind.validation => Icons.info_outline_rounded,
    UserErrorKind.notFound => Icons.search_off_rounded,
    UserErrorKind.unavailable => Icons.schedule_rounded,
    UserErrorKind.unexpected => Icons.support_agent_rounded,
  };
}
