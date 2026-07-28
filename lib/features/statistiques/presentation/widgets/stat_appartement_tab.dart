import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../domain/entities/stat_appartement.dart';

class StatAppartementTab extends StatelessWidget {
  final List<StatAppartement> stats;

  const StatAppartementTab({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apartment_outlined,
                size: 56, color: AppColors.grisMedium),
            SizedBox(height: AppSizes.md),
            Text(
              'Aucun problème signalé ce mois.',
              style: TextStyle(color: AppColors.grisText, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
              child: Text(
                'Top ${stats.length} — appartements avec absences ou refus ce mois',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.grisText),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (int i = 0; i < stats.length; i++) ...[
                    if (i > 0)
                      const Divider(
                          height: 1,
                          indent: AppSizes.md,
                          endIndent: AppSizes.md),
                    _LigneAppartement(stat: stats[i], rang: i + 1),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ligne appartement ──────────────────────────────────────

class _LigneAppartement extends StatelessWidget {
  final StatAppartement stat;
  final int rang;
  const _LigneAppartement({required this.stat, required this.rang});

  @override
  Widget build(BuildContext context) {
    final total = stat.totalProblemes;
    final severity = total >= 5
        ? AppColors.refus
        : total >= 3
            ? AppColors.aVerifier
            : AppColors.absent;

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 12),
      child: Row(
        children: [
          // ── Rang ──────────────────────────────────────────
          SizedBox(
            width: 24,
            child: Text(
              '$rang',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grisText,
                  fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          // ── Numéro + taille ───────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apt ${stat.numero}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.noir),
                ),
                Text(
                  stat.taille,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.grisText),
                ),
              ],
            ),
          ),
          // ── Badges absences + refus ───────────────────────
          if (stat.nbAbsences > 0)
            _CountBadge(
              count: stat.nbAbsences,
              label: 'absent',
              color: AppColors.absent,
              bg: AppColors.absentBg,
            ),
          if (stat.nbRefus > 0) ...[
            const SizedBox(width: AppSizes.xs),
            _CountBadge(
              count: stat.nbRefus,
              label: 'refus',
              color: AppColors.refus,
              bg: AppColors.refusBg,
            ),
          ],
          const SizedBox(width: AppSizes.sm),
          // ── Total problèmes ───────────────────────────────
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: severity.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$total',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: severity,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final Color bg;
  const _CountBadge({
    required this.count,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
