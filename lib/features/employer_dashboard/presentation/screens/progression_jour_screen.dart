import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';

import '../../domain/entities/progression_jour.dart';
import '../providers/employer_dashboard_provider.dart';

enum _Tri { progression, prenom }

class ProgressionJourScreen extends ConsumerStatefulWidget {
  const ProgressionJourScreen({super.key});

  @override
  ConsumerState<ProgressionJourScreen> createState() =>
      _ProgressionJourScreenState();
}

class _ProgressionJourScreenState extends ConsumerState<ProgressionJourScreen> {
  String _recherche = '';
  _Tri _tri = _Tri.progression;
  bool _croissant = true;
  int _page = 0;
  int _parPage = 10;

  /// `null` : choisi selon la largeur (grille sur téléphone, tableau sinon).
  ModeAffichage? _mode;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load());
  }

  void _load() => ref
      .read(employerDashboardNotifierProvider.notifier)
      .loadProgressionJour();

  void _trier(_Tri tri) => setState(() {
        _croissant = _tri == tri ? !_croissant : true;
        _tri = tri;
        _page = 0;
      });

  /// Préposées filtrées et triées. En tri par progression, celles sans tâche
  /// restent à la fin (0 % n'y veut pas dire « en retard »).
  List<ProgressionJour> _lignes(List<ProgressionJour> toutes) {
    final q = _recherche.trim().toLowerCase();
    final filtrees = toutes
        .where((p) => q.isEmpty || p.prenom.toLowerCase().contains(q))
        .toList();
    int parPrenom(ProgressionJour a, ProgressionJour b) =>
        a.prenom.toLowerCase().compareTo(b.prenom.toLowerCase());
    int sens(int c) => _croissant ? c : -c;

    if (_tri == _Tri.prenom) {
      return filtrees..sort((a, b) => sens(parPrenom(a, b)));
    }
    final actives = filtrees.where((p) => p.totalTaches > 0).toList()
      ..sort((a, b) => sens(a.pourcentage.compareTo(b.pourcentage)));
    final sansTaches = filtrees.where((p) => p.totalTaches == 0).toList()
      ..sort(parPrenom);
    return [...actives, ...sansTaches];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employerDashboardNotifierProvider);
    final compact = estCompact(context);
    final mode =
        compact ? ModeAffichage.grille : (_mode ?? ModeAffichage.tableau);

    final lignes = _lignes(state.progressions);
    final nbPages = lignes.isEmpty ? 1 : ((lignes.length - 1) ~/ _parPage) + 1;
    final page = _page.clamp(0, nbPages - 1);
    final visibles = lignes.skip(page * _parPage).take(_parPage).toList();
    final marge = compact ? 12.0 : 24.0;

    return PageAvecEnTete(
      chargement: state.isLoading,
      enTete: EnTetePage(
        icone: Icons.checklist_rounded,
        titre: 'Progression du jour',
        sousTitre: 'Avancement des préposées — '
            '${DateHelper.formatDate(DateTime.now())}',
      ),
      contenu: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: () async => _load(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
              .plusBarre(context),
          children: [_contenu(state, lignes, visibles, page, mode, compact)],
        ),
      ),
    );
  }

  Widget _contenu(
    EmployerDashboardState state,
    List<ProgressionJour> lignes,
    List<ProgressionJour> visibles,
    int page,
    ModeAffichage mode,
    bool compact,
  ) {
    if (state.isLoading && state.progressions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator(color: AppColors.rouge)),
      );
    }
    if (state.error != null && state.progressions.isEmpty) {
      return _ErrorState(message: state.error!, onRetry: _load);
    }
    if (state.progressions.isEmpty) return const _EmptyState();

    final recherche = ChampRecherche(
      indice: 'Rechercher une préposée par prénom',
      onChanged: (v) => setState(() {
        _recherche = v;
        _page = 0;
      }),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryBanner(progressions: state.progressions),
        const SizedBox(height: AppSizes.md),
        BarreSection(
          titre: 'Préposées du jour (${state.progressions.length})',
          onRetour: () => context.backOrHome(AppRoutes.employerDashboard),
          actions: [
            ActionSection(
              icone: Icons.refresh_rounded,
              infoBulle: 'Actualiser',
              onPressed: state.isLoading ? null : _load,
            ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        if (compact)
          recherche
        else
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: recherche,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              BasculeAffichage(
                mode: mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
            ],
          ),
        const SizedBox(height: AppSizes.md),
        if (lignes.isEmpty)
          CarteContenu(
            padding: const EdgeInsets.all(AppSizes.xl),
            child: Text(
              'Aucune préposée ne correspond à « ${_recherche.trim()} ».',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grisDark),
            ),
          )
        else if (mode == ModeAffichage.tableau)
          _TableauProgression(
            lignes: visibles,
            premierNumero: page * _parPage + 1,
            tri: _tri,
            croissant: _croissant,
            onTrier: _trier,
          )
        else
          _GrilleProgression(lignes: visibles),
        const SizedBox(height: AppSizes.md),
        BarrePagination(
          page: page,
          parPage: _parPage,
          total: lignes.length,
          onPage: (p) => setState(() => _page = p),
          onParPage: (n) => setState(() {
            _parPage = n;
            _page = 0;
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Affichage tableau
// ─────────────────────────────────────────────────────────

const _styleEnTete = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.grisDark,
);

class _TableauProgression extends StatelessWidget {
  final List<ProgressionJour> lignes;
  final int premierNumero;
  final _Tri tri;
  final bool croissant;
  final ValueChanged<_Tri> onTrier;

  const _TableauProgression({
    required this.lignes,
    required this.premierNumero,
    required this.tri,
    required this.croissant,
    required this.onTrier,
  });

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF7F8FA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                    width: 40, child: Text('N°', style: _styleEnTete)),
                Expanded(
                  flex: 3,
                  child: _EnTeteTri(
                    libelle: 'Préposée',
                    actif: tri == _Tri.prenom,
                    croissant: croissant,
                    onTap: () => onTrier(_Tri.prenom),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _EnTeteTri(
                    libelle: 'Progression',
                    actif: tri == _Tri.progression,
                    croissant: croissant,
                    onTap: () => onTrier(_Tri.progression),
                  ),
                ),
                const Expanded(
                    flex: 2, child: Text('Confirmées', style: _styleEnTete)),
                const Expanded(child: Text('Fait', style: _styleEnTete)),
                const Expanded(child: Text('En attente', style: _styleEnTete)),
                const Expanded(child: Text('Absent', style: _styleEnTete)),
                const Expanded(child: Text('Refus', style: _styleEnTete)),
                const Expanded(
                    flex: 2, child: Text('Statut', style: _styleEnTete)),
                const SizedBox(width: 48),
              ],
            ),
          ),
          for (final (i, p) in lignes.indexed) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.grisMedium),
            _LigneProgression(progression: p, numero: premierNumero + i),
          ],
        ],
      ),
    );
  }
}

class _EnTeteTri extends StatelessWidget {
  final String libelle;
  final bool actif;
  final bool croissant;
  final VoidCallback onTap;

  const _EnTeteTri({
    required this.libelle,
    required this.actif,
    required this.croissant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(libelle,
                  style: _styleEnTete.copyWith(
                      color: actif ? AppColors.rouge : AppColors.grisDark)),
              const SizedBox(width: 4),
              Icon(
                !actif
                    ? Icons.swap_vert_rounded
                    : croissant
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                size: 14,
                color: actif ? AppColors.rouge : AppColors.grisDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LigneProgression extends StatelessWidget {
  final ProgressionJour progression;
  final int numero;

  const _LigneProgression({required this.progression, required this.numero});

  @override
  Widget build(BuildContext context) {
    final p = progression;
    final sansTache = p.totalTaches == 0;
    final urgency = _urgencyOf(p);
    final couleur = sansTache ? AppColors.grisText : urgency.color;
    final pct = p.pourcentage.clamp(0.0, 100.0);
    final enAttente = (p.totalTaches -
            p.totalFait -
            p.totalAbsent -
            p.totalRefus -
            p.totalAnnule)
        .clamp(0, p.totalTaches);
    const styleCellule = TextStyle(fontSize: 13, color: AppColors.noir);

    Widget nombre(int n, Color c) => Text(
          sansTache ? '—' : '$n',
          style: styleCellule.copyWith(
            color: n == 0 || sansTache ? AppColors.grisText : c,
            fontWeight: n == 0 ? FontWeight.w400 : FontWeight.w700,
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('$numero', style: styleCellule)),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                AvatarProfil(
                  proprietaire: ProprietairePhoto(
                      TypeProprietairePhoto.employe, p.employeeId),
                  initiales:
                      p.prenom.isNotEmpty ? p.prenom[0].toUpperCase() : '?',
                  rayon: 15,
                  couleurFond: couleur.withValues(alpha: 0.12),
                  couleurTexte: couleur,
                  tailleTexte: 12,
                  poidsTexte: FontWeight.bold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.prenom,
                    overflow: TextOverflow.ellipsis,
                    style: styleCellule.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: sansTache
                ? const Text('—',
                    style: TextStyle(fontSize: 13, color: AppColors.grisText))
                : Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 6,
                            backgroundColor: AppColors.grisMedium,
                            valueColor: AlwaysStoppedAnimation(couleur),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${pct.round()} %',
                          textAlign: TextAlign.right,
                          style: styleCellule.copyWith(
                              fontWeight: FontWeight.w700, color: couleur),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              sansTache ? '—' : '${p.tachesConfirmees} / ${p.totalTaches}',
              style: styleCellule,
            ),
          ),
          Expanded(child: nombre(p.totalFait, AppColors.fait)),
          Expanded(child: nombre(enAttente, AppColors.grisDark)),
          Expanded(child: nombre(p.totalAbsent, AppColors.absent)),
          Expanded(child: nombre(p.totalRefus, AppColors.refus)),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _BadgeStatut(
                libelle: sansTache ? 'Aucune tâche' : urgency.label,
                couleur: couleur,
              ),
            ),
          ),
          SizedBox(width: 48, child: _MenuLigne(employeeId: p.employeeId)),
        ],
      ),
    );
  }
}

class _BadgeStatut extends StatelessWidget {
  final String libelle;
  final Color couleur;

  const _BadgeStatut({required this.libelle, required this.couleur});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          libelle,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w600, color: couleur),
        ),
      );
}

enum _ActionLigne { planning, memo }

/// Actions d'une préposée (⋮) : son planning, lui écrire un mémo.
class _MenuLigne extends StatelessWidget {
  final String employeeId;

  const _MenuLigne({required this.employeeId});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ActionLigne>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.rouge),
      onSelected: (a) => switch (a) {
        _ActionLigne.planning =>
          context.go('${AppRoutes.planning}?employeeId=$employeeId'),
        _ActionLigne.memo =>
          context.go('${AppRoutes.memo}?employeeId=$employeeId'),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _ActionLigne.planning,
          child: Text('Voir son planning'),
        ),
        PopupMenuItem(
          value: _ActionLigne.memo,
          child: Text('Lui écrire un mémo'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Affichage grille
// ─────────────────────────────────────────────────────────

class _GrilleProgression extends StatelessWidget {
  final List<ProgressionJour> lignes;

  const _GrilleProgression({required this.lignes});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const ecart = AppSizes.sm;
        final colonnes =
            math.max(1, (constraints.maxWidth + ecart) ~/ (340 + ecart));
        final largeur =
            (constraints.maxWidth - ecart * (colonnes - 1)) / colonnes;
        return Wrap(
          spacing: ecart,
          runSpacing: ecart,
          children: [
            for (final p in lignes)
              SizedBox(
                width: largeur,
                child: p.totalTaches > 0
                    ? _ProgressionCard(progression: p)
                    : _InactiveCard(employeeId: p.employeeId, prenom: p.prenom),
              ),
          ],
        );
      },
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
                      label:
                          '${actives.length} / ${progressions.length} actives',
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
                        label:
                            '$totalAbsent absent${totalAbsent > 1 ? "s" : ""}',
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
  static const double _sweepFull = math.pi * 1.5; // 270°

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
  final hasAction = p.totalFait > 0 || p.totalAbsent > 0 || p.totalRefus > 0;
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
              AvatarProfil(
                proprietaire: ProprietairePhoto(
                    TypeProprietairePhoto.employe, p.employeeId),
                initiales: initiale,
                rayon: 22,
                couleurFond: barColor.withValues(alpha: 0.12),
                couleurTexte: barColor,
                tailleTexte: 16,
                poidsTexte: FontWeight.bold,
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
            style: const TextStyle(fontSize: 12, color: AppColors.grisText),
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
                  count: p.totalRefus, label: 'Refus', color: AppColors.refus),
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
  final String employeeId;
  final String prenom;
  const _InactiveCard({required this.employeeId, required this.prenom});

  @override
  Widget build(BuildContext context) {
    final initiale = prenom.isNotEmpty ? prenom[0].toUpperCase() : '?';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Row(
        children: [
          AvatarProfil(
            proprietaire:
                ProprietairePhoto(TypeProprietairePhoto.employe, employeeId),
            initiales: initiale,
            rayon: 17,
            couleurFond: AppColors.grisMedium,
            couleurTexte: AppColors.grisDark,
            tailleTexte: 13,
            poidsTexte: FontWeight.w600,
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
          Icon(Icons.bar_chart_rounded, size: 64, color: AppColors.grisMedium),
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
              style: const TextStyle(fontSize: 14, color: AppColors.grisDark),
            ),
            const SizedBox(height: AppSizes.lg),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
