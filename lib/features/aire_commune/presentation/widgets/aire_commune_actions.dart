import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/dialogue_app.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../domain/entities/tache_aire_commune.dart';
import '../providers/aire_commune_provider.dart';

/// Demande confirmation (dialogue standard) ; `true` si l'utilisateur valide.
Future<bool> _demander(
  BuildContext context, {
  required String titre,
  required String message,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => DialogueApp(
      titre: titre,
      largeur: 440,
      libelleAction: action,
      libelleSecondaire: 'Retour',
      onFermer: () => Navigator.of(ctx).pop(false),
      onAction: () => Navigator.of(ctx).pop(true),
      contenu: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.aVerifier, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 14, height: 1.4, color: AppColors.grisDark),
            ),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}

/// Repasse une zone confirmée à « À confirmer » (responsable).
Future<void> annulerConfirmationAire(
  BuildContext context,
  WidgetRef ref,
  TacheAireCommune zone,
) async {
  final nom = formatZoneAire(zone.zone);
  final ok = await _demander(
    context,
    titre: 'Annuler la confirmation',
    message: 'La zone « $nom » repassera à « À confirmer ».',
    action: 'Annuler la confirmation',
  );
  if (!ok || !context.mounted) return;

  final succes = await ref
      .read(aireCommuneNotifierProvider.notifier)
      .annulerConfirmationZone(zone.id);
  if (!context.mounted) return;
  if (succes) {
    NotificationApp.info(context, '$nom repasse à « À confirmer ».');
  } else {
    NotificationApp.erreur(
      context,
      ref.read(aireCommuneNotifierProvider).error ??
          'Impossible d’annuler cette confirmation pour le moment.',
    );
  }
}

/// Remet toutes les zones de la semaine à « À confirmer » (responsable).
Future<void> remettreAZeroAireCommune(
    BuildContext context, WidgetRef ref) async {
  final ok = await _demander(
    context,
    titre: 'Remettre à zéro la semaine',
    message: 'Toutes les confirmations de la semaine seront effacées. '
        'Les zones repasseront à « À confirmer ».',
    action: 'Remettre à zéro',
  );
  if (!ok || !context.mounted) return;

  final succes = await ref
      .read(aireCommuneNotifierProvider.notifier)
      .resetSemaineComplete();
  if (!context.mounted) return;
  if (succes) {
    NotificationApp.succes(context, 'Aire commune remise à zéro');
  } else {
    NotificationApp.erreur(
      context,
      ref.read(aireCommuneNotifierProvider).error ?? 'Erreur lors du reset',
    );
  }
}
