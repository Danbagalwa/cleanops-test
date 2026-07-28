import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class EmployerDashboardScreen extends ConsumerWidget {
  const EmployerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(employeeCourantProvider);

    // Breakpoint standard pour le web / tablettes paysages
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      // On masque l'AppBar classique sur Desktop car la navigation y est intégrée différemment
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: AppColors.rouge,
              elevation: 0,
              title: const Text(
                'Tableau de bord',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
      body: isDesktop
          ? _DesktopLayout(employee: employee)
          : _MobileLayout(employee: employee),
    );
  }
}

// ══ LAYOUT MOBILE ═════════════════════════════════════════
class _MobileLayout extends StatelessWidget {
  final Employee? employee;
  const _MobileLayout({required this.employee});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        _BienvenuCard(employee: employee),
        const SizedBox(height: AppSizes.md),
        const _StatsGrid(isDesktop: false),
        const SizedBox(height: AppSizes.md),
        const _SectionTitle(title: 'Accès rapide'),
        const SizedBox(height: AppSizes.sm),
        const _ActionsRapides(),
        const SizedBox(height: AppSizes.xxl),
      ],
    );
  }
}

// ══ LAYOUT DESKTOP (WEB PRO) ════════════════════════════════════════
class _DesktopLayout extends StatelessWidget {
  final Employee? employee;
  const _DesktopLayout({required this.employee});

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
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  title: const Text(
                    'Tableau de bord de l\'entreprise',
                    style: TextStyle(
                      color: AppColors.noir,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined,
                          color: AppColors.noir),
                      onPressed: () {},
                    ),
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
                            const _StatsGrid(isDesktop: true),
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
                            _ActionsRapides(),
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
  final bool isDesktop;
  const _StatsGrid({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final stats = [
      const _StatData(
          icon: Icons.people_rounded,
          label: 'Employé(e)s',
          value: '—',
          color: AppColors.absent),
      const _StatData(
          icon: Icons.apartment_rounded,
          label: 'Appartements',
          value: '—',
          color: AppColors.fait),
      const _StatData(
          icon: Icons.task_alt_rounded,
          label: "Tâches ce soir",
          value: '—',
          color: AppColors.rouge),
      const _StatData(
          icon: Icons.sticky_note_2_rounded,
          label: 'Messages',
          value: '—',
          color: AppColors.aVerifier),
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
  final String value;
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
                  data.value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: data.color,
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
  const _ActionsRapides();

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

    return Column(
      children: actions.asMap().entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
          child: _ActionTile(data: e.value)
              .animate(delay: Duration(milliseconds: 150 + e.key * 50))
              .fadeIn(duration: 250.ms)
              .slideX(begin: 0.03, end: 0),
        );
      }).toList(),
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
