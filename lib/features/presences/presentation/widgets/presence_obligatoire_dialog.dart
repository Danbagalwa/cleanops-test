import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employes/presentation/providers/employes_provider.dart';
import '../../domain/entities/presence.dart';
import '../providers/presence_provider.dart';

/// Dialog bloquant — s'affiche au login si la préposée n'a pas encore
/// confirmé sa présence du jour. Ne peut pas être fermé sans sélection.
class PresenceObligatoireDialog extends ConsumerWidget {
  final String employeeId;
  const PresenceObligatoireDialog({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(maPresenceNotifierProvider(employeeId));
    final employee = ref.watch(employeeCourantProvider);

    // Ferme automatiquement dès que la présence est confirmée
    ref.listen(maPresenceNotifierProvider(employeeId), (prev, next) {
      if (!next.isLoading && next.maPresence != null && next.error == null) {
        if (context.mounted) Navigator.of(context).pop();
      }
    });

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icône ─────────────────────────────────────
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.absent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.how_to_reg_rounded,
                    color: AppColors.absent, size: 30),
              ),
              const SizedBox(height: AppSizes.md),

              // ── Titre ─────────────────────────────────────
              Text(
                'Bonjour ${employee?.prenom ?? ''} !',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.noir,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Confirmez votre présence\npour aujourd\'hui',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.grisDark),
              ),
              const SizedBox(height: AppSizes.lg),

              // ── Options ───────────────────────────────────
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
                  child: CircularProgressIndicator(color: AppColors.absent),
                )
              else
                _OptionsPresence(employeeId: employeeId),

              // ── Erreur ────────────────────────────────────
              if (state.error != null) ...[
                const SizedBox(height: AppSizes.sm),
                Text(
                  state.error!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.rouge),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Options de présence ────────────────────────────────────

class _OptionsPresence extends ConsumerWidget {
  final String employeeId;
  const _OptionsPresence({required this.employeeId});

  Future<void> _confirmer(
    WidgetRef ref,
    StatutPresence statut,
  ) async {
    final responsableIds = ref
        .read(employesNotifierProvider)
        .employes
        .where((e) => e.isResponsable)
        .map((e) => e.id)
        .toList();

    await ref
        .read(maPresenceNotifierProvider(employeeId).notifier)
        .confirmer(
          date: DateTime.now(),
          statut: statut,
          responsableIds: responsableIds,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _OptionTile(
          icon: Icons.check_circle_outline_rounded,
          label: 'Présente',
          sublabel: 'Toute la journée',
          color: AppColors.fait,
          onTap: () => _confirmer(ref, StatutPresence.present),
        ),
        const SizedBox(height: AppSizes.sm),
        _OptionTile(
          icon: Icons.wb_sunny_outlined,
          label: 'Absente ce matin',
          sublabel: 'AM seulement',
          color: AppColors.aVerifier,
          onTap: () => _confirmer(ref, StatutPresence.absentMatin),
        ),
        const SizedBox(height: AppSizes.sm),
        _OptionTile(
          icon: Icons.nights_stay_outlined,
          label: 'Absente cet après-midi',
          sublabel: 'PM seulement',
          color: AppColors.aVerifier,
          onTap: () => _confirmer(ref, StatutPresence.absentApresMidi),
        ),
        const SizedBox(height: AppSizes.sm),
        _OptionTile(
          icon: Icons.person_off_outlined,
          label: 'Absente aujourd\'hui',
          sublabel: 'Toute la journée',
          color: AppColors.refus,
          onTap: () => _confirmer(ref, StatutPresence.absent),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      sublabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: color.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
