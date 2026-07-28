import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../domain/entities/stat_semaine.dart';

class StatSemaineTab extends StatelessWidget {
  final List<StatSemaine> stats;

  const StatSemaineTab({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const _VideMessage(
        message: 'Aucune tâche cette semaine.',
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            _GraphiqueSemaine(stats: stats),
            const SizedBox(height: AppSizes.md),
            _ListeJours(stats: stats),
          ],
        ),
      ),
    );
  }
}

// ── Graphique LineChart ────────────────────────────────────

class _GraphiqueSemaine extends StatelessWidget {
  final List<StatSemaine> stats;
  const _GraphiqueSemaine({required this.stats});

  @override
  Widget build(BuildContext context) {
    final spots = stats
        .map((s) => FlSpot(s.jourIndex.toDouble(), s.pourcentage))
        .toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, AppSizes.md, AppSizes.md, 8),
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
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 4,
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: spots.length > 1,
              color: AppColors.rouge,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 5,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: AppColors.rouge,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.rouge.withValues(alpha: 0.08),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                interval: 25,
                getTitlesWidget: (val, _) => Text(
                  '${val.toInt()}%',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.grisText),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (val, _) {
                  const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];
                  final idx = val.toInt();
                  if (idx < 0 || idx >= labels.length) return const SizedBox();
                  return Text(
                    labels[idx],
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.grisDark),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.grisMedium.withValues(alpha: 0.6),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.noir.withValues(alpha: 0.85),
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(0)}%',
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Liste des jours ────────────────────────────────────────

class _ListeJours extends StatelessWidget {
  final List<StatSemaine> stats;
  const _ListeJours({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  height: 1, indent: AppSizes.md, endIndent: AppSizes.md),
            _LigneJour(stat: stats[i]),
          ],
        ],
      ),
    );
  }
}

class _LigneJour extends StatelessWidget {
  final StatSemaine stat;
  const _LigneJour({required this.stat});

  @override
  Widget build(BuildContext context) {
    final pct = stat.pourcentage;
    final color = pct >= 100
        ? AppColors.fait
        : pct >= 80
            ? AppColors.fait
            : pct >= 50
                ? AppColors.aVerifier
                : AppColors.refus;

    final icon = pct >= 100
        ? Icons.check_circle_rounded
        : pct > 0
            ? Icons.sync_rounded
            : Icons.radio_button_unchecked_rounded;

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              stat.jour,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.noir),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: AppColors.grisMedium,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 7,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          SizedBox(
            width: 40,
            child: Text(
              '${pct.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(width: AppSizes.xs),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSizes.sm),
          SizedBox(
            width: 38,
            child: Text(
              '${stat.fait}/${stat.total}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.grisText,
                  fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message vide ───────────────────────────────────────────

class _VideMessage extends StatelessWidget {
  final String message;
  const _VideMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart_rounded, size: 56, color: AppColors.grisMedium),
          const SizedBox(height: AppSizes.md),
          Text(
            message,
            style: const TextStyle(color: AppColors.grisText, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
