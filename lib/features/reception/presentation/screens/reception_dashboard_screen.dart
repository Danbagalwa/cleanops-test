import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/widgets/dashboard_account_actions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../reception_sections.dart';

/// Tableau de bord de la Réception : un accueil et un accès direct aux 5
/// sections de sa vue.
///
/// Volontairement SANS donnée : il n'affiche ni compteur, ni progression, ni
/// statistique, ni liste. Les informations autorisées à la Réception (statut du
/// jour d'un appartement, présence de l'équipe…) viendront avec chaque section.
class ReceptionDashboardScreen extends ConsumerWidget {
  const ReceptionDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(employeeCourantProvider);

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Réception',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            Text(
              DateHelper.formatDate(DateTime.now()),
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        // Notifications, profil et déconnexion, comme pour les autres
        // utilisateurs, vers les écrans de la Réception.
        actions: const [
          DashboardAccountActions(
            profilRoute: receptionProfilRoute,
            notificationsRoute: receptionNotificationsRoute,
          ),
          SizedBox(width: AppSizes.md),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee == null
                      ? 'Bonjour'
                      : 'Bonjour ${employee.prenom}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                const Text(
                  'Que souhaitez-vous faire ?',
                  style: TextStyle(color: AppColors.grisDark),
                ),
                const SizedBox(height: AppSizes.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final deuxColonnes = constraints.maxWidth >= 640;
                    final largeur = deuxColonnes
                        ? (constraints.maxWidth - AppSizes.md) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: AppSizes.md,
                      runSpacing: AppSizes.md,
                      children: [
                        for (final section in receptionSections)
                          SizedBox(
                            width: largeur,
                            child: _SectionTile(section: section),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final ReceptionSection section;

  const _SectionTile({required this.section});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      elevation: 1,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        onTap: () => context.go(section.route),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.rouge.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(section.iconActive, color: AppColors.rouge),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.titre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      section.description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.grisDark,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.grisDark),
            ],
          ),
        ),
      ),
    );
  }
}
