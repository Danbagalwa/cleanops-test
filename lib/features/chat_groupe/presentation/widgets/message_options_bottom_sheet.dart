import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/chat_message.dart';

Future<void> showMessageOptions({
  required BuildContext context,
  required ChatMessage message,
  required VoidCallback onEpingler,
  required VoidCallback onDesepingler,
  required VoidCallback onSupprimer,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => MessageOptionsBottomSheet(
      message: message,
      onEpingler: onEpingler,
      onDesepingler: onDesepingler,
      onSupprimer: onSupprimer,
    ),
  );
}

class MessageOptionsBottomSheet extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onEpingler;
  final VoidCallback onDesepingler;
  final VoidCallback onSupprimer;

  const MessageOptionsBottomSheet({
    super.key,
    required this.message,
    required this.onEpingler,
    required this.onDesepingler,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusXl)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Poignée
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grisMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Aperçu du message
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.md, 0, AppSizes.md, AppSizes.md),
              child: Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: AppColors.grisLight,
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 14, color: AppColors.grisText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.grisDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Épingler / Désépingler
            if (message.estEpingle)
              _OptionTile(
                icon: Icons.push_pin_outlined,
                label: 'Désépingler',
                color: AppColors.aVerifier,
                onTap: () {
                  Navigator.pop(context);
                  onDesepingler();
                },
              )
            else
              _OptionTile(
                icon: Icons.push_pin_rounded,
                label: 'Épingler',
                color: AppColors.aVerifier,
                onTap: () {
                  Navigator.pop(context);
                  onEpingler();
                },
              ),

            const Divider(height: 1),

            // Supprimer
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Supprimer',
              color: AppColors.rouge,
              onTap: () {
                Navigator.pop(context);
                _confirmerSuppression(context);
              },
            ),

            const SizedBox(height: AppSizes.sm),
          ],
        ),
      ),
    );
  }

  void _confirmerSuppression(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppSizes.radiusLg)),
        title: const Text('Supprimer ce message ?'),
        content: Text(
          '"${message.message.length > 60 ? '${message.message.substring(0, 60)}…' : message.message}"',
          style: const TextStyle(
              fontSize: 13, color: AppColors.grisDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onSupprimer();
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.rouge),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        label,
        style:
            TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }
}
