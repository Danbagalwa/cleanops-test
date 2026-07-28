import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../features/auth/domain/entities/employee.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class TabProfil extends ConsumerWidget {
  final Employee? employee;
  const TabProfil({super.key, required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prenom = employee?.prenom ?? '';
    final nom = employee?.nom ?? '';
    final apt = employee?.nomResidence ?? '—';
    final initiales = nom.length >= 2
        ? nom.substring(0, 2).toUpperCase()
        : nom.toUpperCase();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = MediaQuery.of(context).size.width >= 900;
        final hPad = isDesktop
            ? (constraints.maxWidth - 680) / 2
            : AppSizes.md.toDouble();

        return SingleChildScrollView(
          padding:
              EdgeInsets.symmetric(horizontal: hPad, vertical: AppSizes.md),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Carte profil ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSizes.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: AppColors.grisMedium),
            ),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.rouge,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initiales.isNotEmpty ? initiales : '?',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Text(
                  '$prenom $nom',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.noir,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Apt $apt',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.grisDark,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.grisLight,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: const Text(
                    'PIN attribué par le responsable',
                    style: TextStyle(fontSize: 12, color: AppColors.grisDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),

          // ── Informations ──────────────────────────────────
          _InfoRow(
            icon: Icons.home_rounded,
            label: 'Appartement',
            value: 'Apt $apt',
          ),
          const SizedBox(height: AppSizes.sm),
          _InfoRow(
            icon: Icons.person_rounded,
            label: 'Nom complet',
            value: '$prenom $nom',
          ),
          const SizedBox(height: AppSizes.lg),

          // ── Actions ───────────────────────────────────────
          _ActionButton(
            icon: Icons.info_outline_rounded,
            label: 'À propos',
            onTap: () => _showAPropos(context),
          ),
          const SizedBox(height: AppSizes.sm),
          _ActionButton(
            icon: Icons.help_outline_rounded,
            label: 'Aide',
            onTap: () => _showAide(context),
          ),
          const SizedBox(height: AppSizes.md),

          // ── Déconnexion ───────────────────────────────────
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Se déconnecter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.rouge,
              side: const BorderSide(color: AppColors.rouge),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          const Text(
            'Jazz Teasdale · v1.0',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.grisText),
          ),
        ],
          ),
        );
      },
    );
  }

  void _showAPropos(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('À propos'),
        content: const Text(
          'Application de la résidence Jazz Teasdale.\n\n'
          'Gérez vos demandes de ménage et consultez vos dates de service directement depuis votre appareil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showAide(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aide'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accueil — consultez votre prochain ménage.',
                style: TextStyle(fontSize: 14)),
            SizedBox(height: 8),
            Text('Demandes — faites une demande de reprogrammation, d\'annulation ou laissez un commentaire.',
                style: TextStyle(fontSize: 14)),
            SizedBox(height: 8),
            Text('Pour toute urgence, contactez directement la réception.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.rouge.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.rouge),
          ),
          const SizedBox(width: AppSizes.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.grisText,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.noir)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.grisMedium),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.grisDark),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.noir)),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.grisText),
            ],
          ),
        ),
      ),
    );
  }
}
