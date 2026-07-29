import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/dashboard_account_actions.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/progression_jour.dart';
import '../providers/employer_dashboard_provider.dart';

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

  Future<void> _refresh() => ref
      .read(employerDashboardNotifierProvider.notifier)
      .loadProgressionJour();

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(employeeCourantProvider);
    final state = ref.watch(employerDashboardNotifierProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: AppColors.rouge,
              surfaceTintColor: AppColors.rouge,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'Tableau de bord',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Actualiser',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: state.isLoading ? null : _refresh,
                ),
                const DashboardAccountActions(),
                const SizedBox(width: 4),
              ],
            ),
      body: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _refresh,
        child: isDesktop
            ? _DesktopLayout(employee: employee, state: state)
            : _MobileLayout(employee: employee, state: state),
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
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        _BienvenuCard(employee: employee),
        const SizedBox(height: AppSizes.md),
        if (state.error != null) ...[
          const _DashboardError(),
          const SizedBox(height: AppSizes.md),
        ],
        _StatsGrid(state: state, isDesktop: false),
        if (state.progressions.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _TeamProgress(progressions: state.progressions),
        ],
        const SizedBox(height: AppSizes.md),
        const _SectionTitle(title: 'Accès rapide'),
        const SizedBox(height: AppSizes.sm),
        const _ActionsRapides(columns: 2),
        const SizedBox(height: AppSizes.xxl),
      ],
    );
  }
}

// ══ LAYOUT DESKTOP (WEB PRO) ════════════════════════════════════════
class _DesktopLayout extends StatelessWidget {
  final Employee? employee;
  final EmployerDashboardState state;
  const _DesktopLayout({required this.employee, required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. Sidebar de navigation optionnelle ou espace menu (Simulé ici par structure propre)
        // Vous pouvez insérer un NavigationRail ou votre widget Sidebar ici si nécessaire.

        // 2. Contenu Principal avec contrainte de largeur maximale pour le confort visuel
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                  maxWidth: 1280), // Évite l'étirement infini
              child: Scaffold(
                backgroundColor: Colors.transparent,
                // Top bar version Web intégrée au contenu
                appBar: AppBar(
                  backgroundColor: AppColors.rouge,
                  surfaceTintColor: AppColors.rouge,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  title: const Text(
                    'Tableau de bord de l\'entreprise',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    if (state.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    const DashboardAccountActions(),
                    const SizedBox(width: AppSizes.md),
                  ],
                ),
                // Un seul scroll view pour toute la page pour une glisse fluide à la souris
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Colonne Gauche principale (Activité)
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BienvenuCard(employee: employee),
                            const SizedBox(height: AppSizes.lg),
                            const _SectionTitle(title: 'Vue d\'ensemble'),
                            const SizedBox(height: AppSizes.md),
                            if (state.error != null) ...[
                              const _DashboardError(),
                              const SizedBox(height: AppSizes.md),
                            ],
                            _StatsGrid(state: state, isDesktop: true),
                            if (state.progressions.isNotEmpty) ...[
                              const SizedBox(height: AppSizes.lg),
                              _TeamProgress(progressions: state.progressions),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSizes.lg),
                      // Colonne Droite secondaire (Actions & Infos)
                      const Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(title: 'Accès rapide'),
                            SizedBox(height: AppSizes.md),
                            _ActionsRapides(columns: 2),
                            SizedBox(height: AppSizes.md),
                            _InfoCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Carte bienvenue ───────────────────────────────────────
class _BienvenuCard extends StatelessWidget {
  final Employee? employee;
  const _BienvenuCard({required this.employee});

  String get _salutation {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.rouge, AppColors.rougeFonce],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.rouge.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_salutation, ${employee?.prenom ?? ''} 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  DateHelper.formatDate(DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    employee?.role.label ?? 'Responsable',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cache l'icone massive en version mobile si l'écran est trop petit
          if (MediaQuery.of(context).size.width > 360)
            Container(
              padding: const EdgeInsets.all(AppSizes.lg),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.manage_accounts_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }
}

// ── Grille statistiques ───────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final EmployerDashboardState state;
  final bool isDesktop;
  const _StatsGrid({required this.state, required this.isDesktop});

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
      itemCount: stats.length,
      // Plus d'espace et de colonnes sur le Web si nécessaire, ou cartes mieux proportionnées
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 2 : 2,
        crossAxisSpacing: AppSizes.md,
        mainAxisSpacing: AppSizes.md,
        childAspectRatio: isDesktop ? 2.2 : 1.6,
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
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
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
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Icon(data.icon, color: data.color, size: 24),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value ?? '',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: data.color,
                  ),
                ),
                if (data.value == null)
                  Container(
                    width: 42,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EAF0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grisDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Actions rapides ───────────────────────────────────────
class _ActionsRapides extends StatelessWidget {
  final int columns;
  const _ActionsRapides({this.columns = 1});

  @override
  Widget build(BuildContext context) {
    final actions = [
      const _ActionData(
          icon: Icons.task_alt_rounded,
          label: 'Progression du jour',
          subtitle: 'Avancement en temps réel',
          color: AppColors.fait,
          route: AppRoutes.progressionJour),
      const _ActionData(
          icon: Icons.calendar_month_rounded,
          label: 'Planning',
          subtitle: 'Gérer les horaires',
          color: AppColors.absent,
          route: AppRoutes.planning),
      const _ActionData(
          icon: Icons.apartment_rounded,
          label: 'Appartements',
          subtitle: 'Accès & résidents',
          color: AppColors.fait,
          route: AppRoutes.appartements),
      const _ActionData(
          icon: Icons.bar_chart_rounded,
          label: 'Statistiques',
          subtitle: 'Rapports & données',
          color: AppColors.rouge,
          route: AppRoutes.statistiques),
      const _ActionData(
          icon: Icons.sticky_note_2_rounded,
          label: 'Mémo',
          subtitle: 'Messages internes',
          color: AppColors.aVerifier,
          route: AppRoutes.memo),
      const _ActionData(
          icon: Icons.person_off_outlined,
          label: 'Absences',
          subtitle: 'Gérer les absences',
          color: AppColors.rouge,
          route: AppRoutes.presences),
      const _ActionData(
          icon: Icons.apartment_rounded,
          label: 'Aires communes',
          subtitle: 'Suivi des espaces communs',
          color: Color(0xFF00897B),
          route: AppRoutes.aireCommune),
      const _ActionData(
          icon: Icons.campaign_rounded,
          label: 'Messages semaine',
          subtitle: 'Message motivationnel équipe',
          color: AppColors.rouge,
          route: AppRoutes.messagesSemaine),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final count = constraints.maxWidth < 380 ? 1 : columns;
        final width = (constraints.maxWidth - spacing * (count - 1)) / count;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions.asMap().entries.map((entry) {
            return SizedBox(
              width: width,
              child: _ActionTile(data: entry.value)
                  .animate(
                    delay: Duration(milliseconds: 120 + entry.key * 35),
                  )
                  .fadeIn(duration: 250.ms)
                  .slideY(begin: .04, end: 0),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String route;
  const _ActionData(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.color,
      required this.route});
}

class _ActionTile extends StatefulWidget {
  final _ActionData data;
  const _ActionTile({required this.data});

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _isHovered = false; // Gestion manuelle du Hover pour le Web

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: _isHovered
            ? Matrix4.translationValues(4, 0, 0)
            : Matrix4.identity(), // Léger décalage au survol
        child: Material(
          color: Colors.white,
          elevation: _isHovered ? 4 : 0,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: InkWell(
            onTap: () => context.go(widget.data.route),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isHovered
                      ? widget.data.color.withValues(alpha: 0.5)
                      : Colors.transparent,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.data.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    child: Icon(widget.data.icon,
                        color: widget.data.color, size: 22),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data.label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.noir,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.data.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.grisText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color:
                        _isHovered ? widget.data.color : AppColors.grisMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Carte info ────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.absent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: AppColors.absent.withValues(alpha: 0.15),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.absent,
            size: 20,
          ),
          SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'Les statistiques détaillées seront disponibles prochainement.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.absent,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 400.ms).fadeIn(duration: 400.ms);
  }
}

class _TeamProgress extends StatelessWidget {
  const _TeamProgress({required this.progressions});

  final List<ProgressionJour> progressions;

  @override
  Widget build(BuildContext context) {
    final sorted = [...progressions]
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
          for (final item in sorted.take(4)) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: AppColors.rouge.withValues(alpha: .09),
                  child: Text(
                    item.prenom.isEmpty ? '?' : item.prenom[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.rouge,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
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
            ),
            const SizedBox(height: 13),
          ],
        ],
      ),
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
