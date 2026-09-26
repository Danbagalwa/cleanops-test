import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/dashboard_welcome_header.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../statistiques/domain/entities/statistiques_menages.dart';
import '../../../statistiques/presentation/providers/statistiques_provider.dart';
import '../../../statistiques/presentation/widgets/cartes_statistiques.dart';
import '../../domain/entities/progression_jour.dart';
import '../providers/employer_dashboard_provider.dart';
import 'package:cleanops/core/widgets/espace_barre_mobile.dart';

class EmployerDashboardScreen extends ConsumerStatefulWidget {
  const EmployerDashboardScreen({super.key});

  @override
  ConsumerState<EmployerDashboardScreen> createState() =>
      _EmployerDashboardScreenState();
}

class _EmployerDashboardScreenState
    extends ConsumerState<EmployerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(employerDashboardNotifierProvider.notifier)
          .loadProgressionJour(),
    );
  }

  Future<void> _refresh() {
    ref.invalidate(statistiquesSemaineProvider);
    return ref
        .read(employerDashboardNotifierProvider.notifier)
        .loadProgressionJour();
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(employeeCourantProvider);
    final state = ref.watch(employerDashboardNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.rouge,
            onRefresh: _refresh,
            // Largeur réellement disponible (barre latérale déduite), pas
            // celle de la fenêtre.
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= kLargeurCompacte
                      ? _DesktopLayout(employee: employee, state: state)
                      : _MobileLayout(employee: employee, state: state),
            ),
          ),
          if (state.isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.rouge,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }
}

// ══ LAYOUT MOBILE ═════════════════════════════════════════
class _MobileLayout extends StatelessWidget {
  final Employee? employee;
  final EmployerDashboardState state;
  const _MobileLayout({required this.employee, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md).plusBarre(context),
      children: [
        DashboardWelcomeHeader(employee: employee),
        const SizedBox(height: AppSizes.md),
        if (state.error != null) ...[
          const _DashboardError(),
          const SizedBox(height: AppSizes.md),
        ],
        _StatsGrid(state: state, colonnes: 2),
        const SizedBox(height: AppSizes.md),
        const _GraphiqueSemaine(hauteur: 220),
        const SizedBox(height: AppSizes.md),
        _TeamProgress(state: state),
        const SizedBox(height: AppSizes.lg),
      ],
    );
  }
}

// ══ LAYOUT LARGE (WEB, TABLETTE) ═════════════════════════
class _DesktopLayout extends StatelessWidget {
  final Employee? employee;
  final EmployerDashboardState state;
  const _DesktopLayout({required this.employee, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.lg).plusBarre(context),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DashboardWelcomeHeader(employee: employee),
                const SizedBox(height: AppSizes.lg),
                const _SectionTitle(title: 'Vue d’ensemble'),
                const SizedBox(height: AppSizes.md),
                if (state.error != null) ...[
                  const _DashboardError(),
                  const SizedBox(height: AppSizes.md),
                ],
                LayoutBuilder(
                  builder: (context, constraints) => _StatsGrid(
                    state: state,
                    colonnes: constraints.maxWidth >= 900 ? 4 : 2,
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                // Graphique de la semaine et progression de l'équipe côte à
                // côte quand la place le permet, l'un sous l'autre sinon.
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 1000) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _GraphiqueSemaine(hauteur: 260),
                          const SizedBox(height: AppSizes.lg),
                          _TeamProgress(state: state),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          flex: 3,
                          child: _GraphiqueSemaine(hauteur: 260),
                        ),
                        const SizedBox(width: AppSizes.lg),
                        Expanded(flex: 2, child: _TeamProgress(state: state)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Grille statistiques ───────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final EmployerDashboardState state;
  final int colonnes;
  const _StatsGrid({required this.state, required this.colonnes});

  @override
  Widget build(BuildContext context) {
    final progressions = state.progressions;
    final totalTasks =
        progressions.fold<int>(0, (sum, item) => sum + item.totalTaches);
    final confirmed =
        progressions.fold<int>(0, (sum, item) => sum + item.tachesConfirmees);
    final alerts = progressions.fold<int>(
      0,
      (sum, item) => sum + item.totalAbsent + item.totalRefus,
    );
    final average =
        totalTasks == 0 ? 0 : (confirmed / totalTasks * 100).round();

    final stats = [
      _StatData(
          icon: Icons.people_rounded,
          label: 'Équipe aujourd’hui',
          value: state.isLoading && progressions.isEmpty
              ? null
              : '${progressions.length}',
          color: AppColors.absent),
      _StatData(
          icon: Icons.task_alt_rounded,
          label: 'Tâches confirmées',
          value: state.isLoading && progressions.isEmpty
              ? null
              : '$confirmed/$totalTasks',
          color: AppColors.fait),
      _StatData(
          icon: Icons.donut_large_rounded,
          label: 'Avancement global',
          value: state.isLoading && progressions.isEmpty ? null : '$average %',
          color: AppColors.rouge),
      _StatData(
          icon: Icons.report_outlined,
          label: alerts == 0 ? 'Aucune alerte' : 'Absences ou refus',
          value: state.isLoading && progressions.isEmpty ? null : '$alerts',
          color: alerts == 0 ? AppColors.fait : AppColors.aVerifier),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Sans marge explicite, la grille reprend celle du bas de l'écran
      // (barre en verre) : grand vide sous les cartes.
      padding: EdgeInsets.zero,
      itemCount: stats.length,
      // Hauteur fixe : un ratio ferait des cartes trop hautes sur une large
      // fenêtre et déborderait sur un petit téléphone.
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: colonnes,
        crossAxisSpacing: AppSizes.md,
        mainAxisSpacing: AppSizes.md,
        mainAxisExtent: colonnes == 2 ? 104 : 96,
      ),
      itemBuilder: (context, index) {
        return _StatCard(data: stats[index])
            .animate(delay: Duration(milliseconds: index * 60))
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.08, end: 0);
      },
    );
  }
}

class _StatData {
  final IconData icon;
  final String label;
  final String? value;
  final Color color;
  const _StatData(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    // Carte étroite (2 par ligne sur un petit téléphone) : marges et icône
    // réduites pour laisser la place au libellé.
    return LayoutBuilder(builder: (context, constraints) {
      final etroite = constraints.maxWidth < 200;
      return Container(
        padding: EdgeInsets.all(etroite ? 12 : AppSizes.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(etroite ? 6 : AppSizes.sm),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child:
                  Icon(data.icon, color: data.color, size: etroite ? 20 : 24),
            ),
            SizedBox(width: etroite ? 10 : AppSizes.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pendant le chargement, une pastille grise tient la place
                  // du chiffre (même hauteur : la carte ne saute pas).
                  if (data.value == null)
                    Container(
                      width: 42,
                      height: 24,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EAF0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        data.value!,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: data.color,
                        ),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    data.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.grisDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Graphique de la semaine ───────────────────────────────
/// Ménages de la semaine en cours, jour par jour et par statut : mêmes
/// graphique et tableau que la page Statistiques.
class _GraphiqueSemaine extends ConsumerWidget {
  const _GraphiqueSemaine({required this.hauteur});

  final double hauteur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semaine = ref.watch(statistiquesSemaineProvider);
    final jours = semaine.valueOrNull?.parJour ?? const <StatJour>[];

    return CarteStatistique(
      titre: 'Cette semaine',
      hauteur: hauteur,
      graphique: (_) => semaine.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.rouge),
        ),
        error: (_, __) =>
            const MessageVide('Le graphique n’a pas pu être chargé.'),
        data: (_) => GraphiqueParJour(jours: jours),
      ),
      tableau: (_) => TableauStat(
        vide: 'Aucun ménage cette semaine.',
        entetes: const ['Jour', 'Planifiés', 'Faits', 'Absents', 'Refus'],
        lignes: [
          for (final j in jours)
            [
              DateFormat('EEE dd/MM', 'fr_FR').format(j.date),
              '${j.comptes.total}',
              '${j.comptes.fait}',
              '${j.comptes.absent}',
              '${j.comptes.refus}',
            ],
        ],
      ),
    );
  }
}

class _TeamProgress extends StatelessWidget {
  const _TeamProgress({required this.state});

  final EmployerDashboardState state;

  @override
  Widget build(BuildContext context) {
    final sorted = [...state.progressions]
      ..sort((a, b) => a.pourcentage.compareTo(b.pourcentage));
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: const Color(0xFFE7E9F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progression de l’équipe',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Les personnes à accompagner apparaissent en premier',
                      style: TextStyle(
                        color: AppColors.grisDark,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.progressionJour),
                child: const Text('Tout voir'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
              child: Text(
                state.isLoading
                    ? 'Chargement de la progression…'
                    : 'Aucune tâche planifiée pour l’équipe aujourd’hui.',
                style: const TextStyle(color: AppColors.grisDark, fontSize: 13),
              ),
            )
          else
            // Sur grand écran, deux colonnes et jusqu'à 6 personnes.
            LayoutBuilder(
              builder: (context, constraints) {
                final deuxColonnes = constraints.maxWidth >= 600;
                final largeur = deuxColonnes
                    ? (constraints.maxWidth - AppSizes.lg) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: AppSizes.lg,
                  runSpacing: 13,
                  children: [
                    for (final item in sorted.take(deuxColonnes ? 6 : 4))
                      SizedBox(
                        width: largeur,
                        child: _LigneProgression(item: item),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _LigneProgression extends StatelessWidget {
  const _LigneProgression({required this.item});

  final ProgressionJour item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AvatarProfil(
          proprietaire:
              ProprietairePhoto(TypeProprietairePhoto.employe, item.employeeId),
          initiales: item.prenom.isEmpty ? '?' : item.prenom[0].toUpperCase(),
          rayon: 15,
          couleurFond: AppColors.rouge.withValues(alpha: .09),
          couleurTexte: AppColors.rouge,
          tailleTexte: 12,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.prenom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Text(
                    '${item.tachesConfirmees}/${item.totalTaches}',
                    style: const TextStyle(
                      color: AppColors.grisDark,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: (item.pourcentage / 100).clamp(0, 1),
                  minHeight: 6,
                  color: item.pourcentage >= 100
                      ? AppColors.fait
                      : AppColors.rouge,
                  backgroundColor: const Color(0xFFE9EAF0),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Color(0xFFC2410C), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Les indicateurs n’ont pas pu être actualisés. Les autres '
              'fonctions restent disponibles.',
              style: TextStyle(
                color: Color(0xFF9A3412),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Titre section ─────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.noir,
        letterSpacing: -0.5,
      ),
    );
  }
}
