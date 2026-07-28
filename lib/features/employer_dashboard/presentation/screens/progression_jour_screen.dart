import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/entities/progression_jour.dart';
import '../providers/employer_dashboard_provider.dart';

class ProgressionJourScreen extends ConsumerStatefulWidget {
  const ProgressionJourScreen({super.key});

  @override
  ConsumerState<ProgressionJourScreen> createState() =>
      _ProgressionJourScreenState();
}

class _ProgressionJourScreenState
    extends ConsumerState<ProgressionJourScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load());
  }

  void _load() =>
      ref.read(employerDashboardNotifierProvider.notifier).loadProgressionJour();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employerDashboardNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.backOrHome(AppRoutes.employerDashboard),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progression du jour',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              DateHelper.formatDate(DateTime.now()),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        actions: [
          // Spinner pendant le refresh, icône sinon
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Rafraîchir',
              onPressed: _load,
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: () async => _load(),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(EmployerDashboardState state) {
    if (state.isLoading && state.progressions.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.rouge));
    }
    if (state.error != null && state.progressions.isEmpty) {
      return _ErrorState(message: state.error!, onRetry: _load);
    }
    if (state.progressions.isEmpty) {
      return const _EmptyState();
    }

    // ── Tri & regroupement ──────────────────────────────
    // Actives = ont des tâches, triées par progression croissante
    final actives = state.progressions
        .where((p) => p.totalTaches > 0)
        .toList()
      ..sort((a, b) => a.pourcentage.compareTo(b.pourcentage));

    // Sans tâches = triées par prénom
    final sansTaches = state.progressions
        .where((p) => p.totalTaches == 0)
        .toList()
      ..sort((a, b) => a.prenom.compareTo(b.prenom));

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md, vertical: AppSizes.lg),
          children: [
            // Bandeau récapitulatif
            _SummaryBanner(progressions: state.progressions),

            // Section préposées actives
            if (actives.isNotEmpty) ...[
              const SizedBox(height: AppSizes.lg),
              const _SectionLabel(label: 'PRÉPOSÉES DU JOUR'),
              const SizedBox(height: AppSizes.xs),
              ...actives.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.sm),
                    child: _ProgressionCard(progression: p),
                  )),
            ],

            // Section préposées sans tâches
            if (sansTaches.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              const _SectionLabel(label: "PAS DE TÂCHES AUJOURD'HUI"),
              const SizedBox(height: AppSizes.xs),
              ...sansTaches.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.sm),
                    child: _InactiveCard(prenom: p.prenom),
                  )),
            ],

            const SizedBox(height: AppSizes.lg),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Label de section
// ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.grisText,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Bandeau récapitulatif
// ─────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final List<ProgressionJour> progressions;
  const _SummaryBanner({required this.progressions});

  @override
  Widget build(BuildContext context) {
    final actives = progressions.where((p) => p.totalTaches > 0).toList();
    final totalTaches = progressions.fold(0, (s, p) => s + p.totalTaches);
    final totalFait = progressions.fold(0, (s, p) => s + p.totalFait);
    final totalAbsent = progressions.fold(0, (s, p) => s + p.totalAbsent);
    final totalRefus = progressions.fold(0, (s, p) => s + p.totalRefus);

    final moyennePct = actives.isEmpty
        ? 0.0
        : actives.fold(0.0, (s, p) => s + p.pourcentage) / actives.length;

    final gaugeColor = moyennePct >= 80
        ? AppColors.fait
        : moyennePct >= 40
            ? AppColors.aVerifier
            : AppColors.rouge;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Jauge circulaire ───────────────────────────
          _CircularGauge(percentage: moyennePct, color: gaugeColor),
          const SizedBox(width: AppSizes.md),

          // ── Stats détaillées ───────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Vue d'ensemble",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.noir,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Wrap(
                  spacing: AppSizes.xs,
                  runSpacing: AppSizes.xs,
                  children: [
                    _SummaryChip(
                      icon: Icons.people_rounded,
                      label: '${actives.length} / ${progressions.length} actives',
                      color: AppColors.absent,
                    ),
                    _SummaryChip(
                      icon: Icons.task_alt_rounded,
                      label: '$totalFait / $totalTaches faites',
                      color: AppColors.fait,
                    ),
                    if (totalAbsent > 0)
                      _SummaryChip(
                        icon: Icons.person_off_outlined,
                        label: '$totalAbsent absent${totalAbsent > 1 ? "s" : ""}',
                        color: AppColors.absent,
                      ),
                    if (totalRefus > 0)
                      _SummaryChip(
                        icon: Icons.cancel_outlined,
                        label: '$totalRefus refus',
                        color: AppColors.refus,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Jauge circulaire (style speedometer)
// ─────────────────────────────────────────────────────────

class _CircularGauge extends StatelessWidget {
  final double percentage;
  final Color color;
  const _CircularGauge({required this.percentage, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: CustomPaint(
        painter: _GaugePainter(percentage: percentage, color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'moy.',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.grisText,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final Color color;
  const _GaugePainter({required this.percentage, required this.color});

  // Arc de 270°, départ en bas à gauche (7h30), fin en bas à droite (4h30)
  static const double _startAngle = math.pi * 0.75; // 135° → 7h30
  static const double _sweepFull = math.pi * 1.5;   // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 16) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Arc de fond
    canvas.drawArc(
      rect,
      _startAngle,
      _sweepFull,
      false,
      Paint()
        ..color = AppColors.grisMedium
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );

    // Arc de progression
    if (percentage > 0) {
      canvas.drawArc(
        rect,
        _startAngle,
        _sweepFull * (percentage / 100).clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.percentage != percentage || old.color != color;
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SummaryChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Niveaux d'urgence
// ─────────────────────────────────────────────────────────

enum _UrgencyLevel { pasCommence, enCours, termine }

extension _UrgencyExt on _UrgencyLevel {
  Color get color {
    switch (this) {
      case _UrgencyLevel.pasCommence:
        return AppColors.refus;
      case _UrgencyLevel.enCours:
        return AppColors.aVerifier;
      case _UrgencyLevel.termine:
        return AppColors.fait;
    }
  }

  IconData get icon {
    switch (this) {
      case _UrgencyLevel.pasCommence:
        return Icons.warning_amber_rounded;
      case _UrgencyLevel.enCours:
        return Icons.timelapse_rounded;
      case _UrgencyLevel.termine:
        return Icons.check_circle_rounded;
    }
  }

  String get label {
    switch (this) {
      case _UrgencyLevel.pasCommence:
        return 'Pas commencé';
      case _UrgencyLevel.enCours:
        return 'En cours';
      case _UrgencyLevel.termine:
        return 'Terminé';
    }
  }
}

_UrgencyLevel _urgencyOf(ProgressionJour p) {
  if (p.pourcentage >= 100) return _UrgencyLevel.termine;
  final hasAction =
      p.totalFait > 0 || p.totalAbsent > 0 || p.totalRefus > 0;
  return hasAction ? _UrgencyLevel.enCours : _UrgencyLevel.pasCommence;
}

// ─────────────────────────────────────────────────────────
// Carte préposée active
// ─────────────────────────────────────────────────────────

class _ProgressionCard extends StatelessWidget {
  final ProgressionJour progression;
  const _ProgressionCard({required this.progression});

  @override
  Widget build(BuildContext context) {
    final p = progression;
    final pct = p.pourcentage.clamp(0.0, 100.0);
    final urgency = _urgencyOf(p);
    final barColor = urgency.color;
    final initiale = p.prenom.isNotEmpty ? p.prenom[0].toUpperCase() : '?';
    final enAttente = (p.totalTaches -
            p.totalFait -
            p.totalAbsent -
            p.totalRefus -
            p.totalAnnule)
        .clamp(0, p.totalTaches);

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        // Bordure rouge discète pour signaler "pas commencé"
        border: urgency == _UrgencyLevel.pasCommence
            ? Border.all(
                color: AppColors.refus.withValues(alpha: 0.35), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: barColor.withValues(alpha: 0.12),
                child: Text(
                  initiale,
                  style: TextStyle(
                    color: barColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.prenom,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.noir,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Badge d'urgence
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(urgency.icon, size: 12, color: urgency.color),
                        const SizedBox(width: 4),
                        Text(
                          urgency.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: urgency.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.xs),
              Text(
                '${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)} %',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: barColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.sm),

          // ── Barre de progression ─────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: AppColors.grisMedium,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 7,
            ),
          ),

          const SizedBox(height: AppSizes.xs + 2),

          // ── Résumé ───────────────────────────────────
          Text(
            '${p.totalTaches} tâche${p.totalTaches > 1 ? "s" : ""}  •  '
            '${p.tachesConfirmees} confirmée${p.tachesConfirmees > 1 ? "s" : ""}',
            style:
                const TextStyle(fontSize: 12, color: AppColors.grisText),
          ),

          const SizedBox(height: AppSizes.sm),

          // ── Pastilles : tous les états ───────────────
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatPill(
                  count: p.totalFait, label: 'Fait', color: AppColors.fait),
              _StatPill(
                  count: enAttente,
                  label: 'En attente',
                  color: AppColors.grisText),
              _StatPill(
                  count: p.totalAbsent,
                  label: 'Absent',
                  color: AppColors.absent),
              _StatPill(
                  count: p.totalRefus,
                  label: 'Refus',
                  color: AppColors.refus),
              if (p.totalAnnule > 0)
                _StatPill(
                    count: p.totalAnnule,
                    label: 'Annulé',
                    color: AppColors.annule),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Carte préposée sans tâches (grisée, compacte)
// ─────────────────────────────────────────────────────────

class _InactiveCard extends StatelessWidget {
  final String prenom;
  const _InactiveCard({required this.prenom});

  @override
  Widget build(BuildContext context) {
    final initiale = prenom.isNotEmpty ? prenom[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.grisMedium,
            child: Text(
              initiale,
              style: const TextStyle(
                color: AppColors.grisDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              prenom,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.grisDark,
              ),
            ),
          ),
          const Text(
            'Aucune tâche assignée',
            style: TextStyle(fontSize: 11, color: AppColors.grisText),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Pastille de statut
// ─────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _StatPill(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// État vide
// ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 64, color: AppColors.grisMedium),
          SizedBox(height: AppSizes.md),
          Text(
            "Aucune donnée pour aujourd'hui",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.grisDark),
          ),
          SizedBox(height: AppSizes.xs),
          Text(
            "Les tâches n'ont pas encore été générées.",
            style: TextStyle(color: AppColors.grisText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// État erreur
// ─────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.rouge),
            const SizedBox(height: AppSizes.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 14, color: AppColors.grisDark),
            ),
            const SizedBox(height: AppSizes.lg),
            FilledButton.icon(
              onPressed: onRetry,
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.rouge),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
