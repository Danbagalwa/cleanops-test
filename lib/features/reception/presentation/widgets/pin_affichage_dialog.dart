import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/reception_pin_models.dart';
import 'package:cleanops/core/widgets/notification_app.dart';

/// Fenêtre qui montre un PIN qui vient d'être généré : UNE seule fois, puis
/// plus jamais relisible. Ne se ferme pas par un clic à côté.
class AffichagePinDialog extends StatelessWidget {
  final String nomComplet;
  final String numero;
  final PinGenere pin;

  const AffichagePinDialog({
    super.key,
    required this.nomComplet,
    required this.numero,
    required this.pin,
  });

  Future<void> _copier(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: pin.pin));
    if (!context.mounted) return;
    NotificationApp.succes(context, 'PIN copié.');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      title: Text(pin.reinitialise ? 'PIN réinitialisé' : 'PIN généré'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$nomComplet · Apt $numero',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSizes.md),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg, vertical: AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.grisLight,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: SelectableText(
                  pin.pin,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              pin.reinitialise
                  ? "L'ancien PIN ne fonctionne plus. Communiquez celui-ci au "
                      'résident maintenant.'
                  : 'Communiquez ce PIN au résident maintenant.',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: AppSizes.xs),
            const Text(
              'Il ne pourra plus être affiché après la fermeture de cette '
              'fenêtre. En cas d\'oubli, il faudra le réinitialiser.',
              style: TextStyle(height: 1.4, color: AppColors.grisDark),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _copier(context),
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copier'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Terminé'),
        ),
      ],
    );
  }
}
