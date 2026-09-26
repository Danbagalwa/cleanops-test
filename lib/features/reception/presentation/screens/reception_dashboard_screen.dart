import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/dashboard_welcome_header.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../reception_sections.dart';
import 'package:cleanops/core/widgets/espace_barre_mobile.dart';

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
    final marge = estCompact(context) ? AppSizes.md : AppSizes.lg;

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(marge).plusBarre(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DashboardWelcomeHeader(
                  employee: employee,
                  actions: [
                    EnTeteAction(
                      icone: Icons.event_note_rounded,
                      libelle: 'Mes demandes',
                      onPressed: () =>
                          context.go(receptionMesDemandesEquipeRoute),
                    ),
                  ],
                ),
                SizedBox(height: marge),
                const Text(
                  'Que souhaitez-vous faire ?',
                  style: TextStyle(color: AppColors.grisDark),
                ),
                const SizedBox(height: AppSizes.md),
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
