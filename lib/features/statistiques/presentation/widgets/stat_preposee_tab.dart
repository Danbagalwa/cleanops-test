import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../domain/entities/stat_preposee.dart';
import '../providers/statistiques_provider.dart';
import 'periode_selector_widget.dart';

class StatPreposeeTab extends ConsumerWidget {
  const StatPreposeeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statistiquesNotifierProvider);
    final stats = state.statPreposees;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            // ── Filtre de période ────────────────────────────
            const PeriodeSelectorWidget(),
            const SizedBox(height: AppSizes.xs),

            // ── Contenu ──────────────────────────────────────
            if (stats.isEmpty)
              const _Vide()
            else ...[
              _LegendePills(),
              const SizedBox(height: AppSizes.md),
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
                      _CartePreposee(stat: stats[i], rang: i + 1),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── État vide ──────────────────────────────────────────────

class _Vide extends StatelessWidget {
  const _Vide();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 48, color: AppColors.grisMedium),
            SizedBox(height: AppSizes.md),
            Text(
              'Aucune donnée pour cette période.',
              style: TextStyle(color: AppColors.grisText, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Légende ────────────────────────────────────────────────

class _LegendePills extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _Pill(color: AppColors.fait, label: '>80% Excellent'),
        SizedBox(width: AppSizes.sm),
        _Pill(color: AppColors.aVerifier, label: '50-80% Moyen'),
        SizedBox(width: AppSizes.sm),
        _Pill(color: AppColors.refus, label: '<50% Attention'),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final Color color;
  final String label;
  const _Pill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.grisText)),
      ],
    );
  }
}

// ── Carte préposée ─────────────────────────────────────────

class _CartePreposee extends StatelessWidget {
  final StatPreposee stat;
  final int rang;
  const _CartePreposee({required this.stat, required this.rang});

  Color get _couleurPct {
    if (stat.pourcentage >= 80) return AppColors.fait;
    if (stat.pourcentage >= 50) return AppColors.aVerifier;
    return AppColors.refus;
  }

  @override
  Widget build(BuildContext context) {
    final color = _couleurPct;
    final pct = stat.pourcentage;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stat.prenom.isNotEmpty ? stat.prenom[0] : '?',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  stat.prenom,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.noir),
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xs + 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: AppColors.grisMedium,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Row(
            children: [
              _Badge(
                icon: Icons.check_circle_outline_rounded,
                label: '${stat.fait} fait',
                color: AppColors.fait,
              ),
              const SizedBox(width: AppSizes.sm),
              _Badge(
                icon: Icons.door_back_door_outlined,
                label: '${stat.absent} absent',
                color: AppColors.absent,
              ),
              const SizedBox(width: AppSizes.sm),
              _Badge(
                icon: Icons.block_rounded,
                label: '${stat.refus} refus',
                color: AppColors.refus,
              ),
              const Spacer(),
              Text(
                '${stat.fait}/${stat.total} tâches',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.grisText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
