import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../domain/entities/tache_jour.dart';
import 'statut_selector_widget.dart';

class TacheCardWidget extends StatelessWidget {
  final TacheJour tache;
  final String dateStr;
  final bool isUpdating;
  // inPanel = true : pas de marge/bordure externe (le panneau les fournit)
  final bool inPanel;

  const TacheCardWidget({
    super.key,
    required this.tache,
    required this.dateStr,
    this.isUpdating = false,
    this.inPanel = false,
  });

  Color get _statutColor => switch (tache.statut) {
        StatutTache.fait => AppColors.fait,
        StatutTache.absent => AppColors.absent,
        StatutTache.refus => AppColors.refus,
        StatutTache.annule => AppColors.annule,
        StatutTache.nonCommence => AppColors.nonCommence,
      };

  Color get _statutBg => switch (tache.statut) {
        StatutTache.fait => AppColors.faitBg,
        StatutTache.absent => AppColors.absentBg,
        StatutTache.refus => AppColors.refusBg,
        StatutTache.annule => AppColors.annuleBg,
        StatutTache.nonCommence => AppColors.grisLight,
      };

  String get _statutLabel => tache.statut.label;

  IconData get _statutIcon => switch (tache.statut) {
        StatutTache.fait => Icons.check_circle_rounded,
        StatutTache.absent => Icons.door_back_door_outlined,
        StatutTache.refus => Icons.block_rounded,
        StatutTache.annule => Icons.cancel_rounded,
        StatutTache.nonCommence => Icons.radio_button_unchecked_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (inPanel) {
      // Dans un panneau : InkWell simple, pas de bordure ni d'ombre
      return InkWell(
        onTap: isUpdating
            ? null
            : () => StatutSelectorWidget.show(context, tache, dateStr),
        child: content,
      );
    }

    // Mode standalone : carte avec bordure et ombre
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.xs),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: InkWell(
          onTap: isUpdating
              ? null
              : () => StatutSelectorWidget.show(context, tache, dateStr),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: AppColors.grisMedium),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final appt = tache.appartement;
    final minutes = tache.minutesEstimees;

    return Row(
      children: [
        // ── Barre de statut colorée ──────────────────────
        Container(width: 4, color: _statutColor),

        // ── Contenu ──────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                // Numéro de tâche
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.rouge.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${tache.numeroTache}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.rouge,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Infos appartement
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt != null ? 'Apt. ${appt.numero}' : 'Appartement',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.noir,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (appt != null) ...[
                            _Badge(appt.taille, AppColors.grisText),
                            const SizedBox(width: 6),
                          ],
                          if (minutes > 0)
                            _Badge(
                              DateHelper.minutesEnHeures(minutes),
                              AppColors.grisDark,
                            ),
                        ],
                      ),
                      if (tache.motifAbsent != null &&
                          tache.motifAbsent!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          tache.motifAbsent!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.absent,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Statut badge
                if (isUpdating)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.rouge,
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statutBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statutIcon, size: 12, color: _statutColor),
                            const SizedBox(width: 4),
                            Text(
                              _statutLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _statutColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Icon(
                        Icons.edit_rounded,
                        size: 12,
                        color: AppColors.grisText,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
