import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Destination TEMPORAIRE de la Réception (option A retenue).
///
/// La vue Réception (résidents, équipe, à aviser, PIN, messages transmis)
/// n'existe pas encore. Cet écran ne lit et n'affiche AUCUNE donnée de
/// l'application : il informe seulement, et permet de se déconnecter. C'est la
/// seule page accessible à ce profil ; toutes les autres lui sont refusées par
/// le routeur.
class ReceptionEnConstructionScreen extends ConsumerWidget {
  const ReceptionEnConstructionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(employeeCourantProvider);

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        title: const Text('Réception'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.construction_rounded,
                  size: 56,
                  color: AppColors.rouge,
                ),
                const SizedBox(height: AppSizes.md),
                const Text(
                  'Vue Réception en construction',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSizes.sm),
                const Text(
                  'Votre espace Réception n\'est pas encore disponible. '
                  'Il sera accessible dès qu\'il sera prêt.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.45, color: AppColors.grisText),
                ),
                if (employee != null) ...[
                  const SizedBox(height: AppSizes.md),
                  Text(
                    'Connecté(e) : ${employee.nomComplet}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.grisText),
                  ),
                ],
                const SizedBox(height: AppSizes.lg),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authNotifierProvider.notifier).logout();
                    if (context.mounted) context.go('/');
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
