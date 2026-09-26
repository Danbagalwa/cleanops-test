import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/dialogue_app.dart';
import '../../domain/entities/chat_message.dart';
import 'chat_bubble.dart';

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
    // Sur ordinateur, la feuille garde une largeur de lecture.
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (_) => MessageOptionsBottomSheet(
      message: message,
      onEpingler: onEpingler,
      onDesepingler: onDesepingler,
      onSupprimer: onSupprimer,
    ),
  );
}

/// Confirme la suppression d'un message (dialogue standard).
Future<bool> confirmerSuppressionMessage(
    BuildContext context, ChatMessage message) async {
  final extrait = message.message.length > 120
      ? '${message.message.substring(0, 120)}…'
      : message.message;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => DialogueApp(
      titre: 'Supprimer le message',
      largeur: 460,
      libelleAction: 'Supprimer',
      libelleSecondaire: 'Annuler',
      onFermer: () => Navigator.of(ctx).pop(false),
      onAction: () => Navigator.of(ctx).pop(true),
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ce message sera retiré de la discussion pour toute l’équipe.',
            style: TextStyle(fontSize: 14, color: AppColors.grisDark),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.grisLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.grisMedium),
            ),
            child: Text(
              '${message.prenomAuteur} : « $extrait »',
              style: const TextStyle(fontSize: 13, color: AppColors.noir),
            ),
          ),
        ],
      ),
    ),
  );
  return ok == true;
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grisMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'OPTIONS DU MESSAGE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.noir,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: AppColors.grisDark),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.grisLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.grisMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.prenomAuteur,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: couleurAuteur(message.prenomAuteur),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 13, color: AppColors.noir),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            if (message.estEpingle)
              _OptionTile(
                icon: Icons.push_pin_outlined,
                label: 'Désépingler',
                color: couleurEpingle,
                onTap: () {
                  Navigator.pop(context);
                  onDesepingler();
                },
              )
            else
              _OptionTile(
                icon: Icons.push_pin_rounded,
                label: 'Épingler pour toute l’équipe',
                color: couleurEpingle,
                onTap: () {
                  Navigator.pop(context);
                  onEpingler();
                },
              ),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Supprimer',
              color: AppColors.refus,
              onTap: () async {
                Navigator.pop(context);
                if (await confirmerSuppressionMessage(context, message)) {
                  onSupprimer();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        label,
        style: const TextStyle(
            fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.noir),
      ),
    );
  }
}
