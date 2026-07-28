import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/semaine_helper.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../presences/presentation/providers/presence_provider.dart';
import '../../../presences/presentation/widgets/presence_card_widget.dart';
import '../../../presences/presentation/widgets/presence_obligatoire_dialog.dart';
import '../providers/employee_dashboard_provider.dart';
import '../widgets/mini_calendrier_widget.dart';
import '../widgets/message_semaine_widget.dart';
import '../../domain/entities/semaine.dart';

class EmployeeDashboardScreen extends ConsumerStatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  ConsumerState<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState
    extends ConsumerState<EmployeeDashboardScreen> {
  bool _presenceDialogShown = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(dashboardNotifierProvider.notifier).charger();

      // Déclenche le check de présence immédiatement, sans attendre
      // que PresenceCardWidget se rende dans le layout
      final employee = ref.read(employeeCourantProvider);
      if (employee != null) {
        ref
            .read(maPresenceNotifierProvider(employee.id).notifier)
            .charger(DateTime.now());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(employeeCourantProvider);
    final dashState = ref.watch(dashboardNotifierProvider);

    // Force la déclaration de présence au premier chargement
    if (employee != null) {
      ref.listen(maPresenceNotifierProvider(employee.id), (prev, next) {
        if (!_presenceDialogShown &&
            prev?.isLoading == true &&
            !next.isLoading &&
            next.maPresence == null &&
            next.error == null) {
          _presenceDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    PresenceObligatoireDialog(employeeId: employee.id),
              );
            }
          });
        }
      });
    }
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: () =>
            ref.read(dashboardNotifierProvider.notifier).rafraichir(),
        child: isDesktop
            ? _DesktopLayout(state: dashState, employee: employee)
            : _MobileLayout(state: dashState, employee: employee),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }
}

// ══ LAYOUT MOBILE ═════════════════════════════════════════
class _MobileLayout extends ConsumerWidget {
  final DashboardState state;
  final dynamic employee;

  const _MobileLayout({required this.state, required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.rouge),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        // ── Salutation ──────────────────────────────────
        _SalutationCard(prenom: employee?.prenom ?? ''),
        const SizedBox(height: AppSizes.md),

        // ── Présence du jour ─────────────────────────────
        PresenceCardWidget(date: DateTime.now()),
        const SizedBox(height: AppSizes.md),

        // ── Message semaine ──────────────────────────────
        if (state.messageSemaine != null) ...[
          MessageSemaineWidget(message: state.messageSemaine!),
          const SizedBox(height: AppSizes.md),
        ],

        // ── Résumé du jour ───────────────────────────────
        if (state.semaine != null) ...[
          _ResumeDuJour(semaine: state.semaine!),
          const SizedBox(height: AppSizes.md),

          // ── Mini calendrier ──────────────────────────
          const _SectionTitle(title: 'Ma semaine'),
          const SizedBox(height: AppSizes.sm),
          MiniCalendrierWidget(
            jours: state.semaine!.jours,
            onJourTap: (jour) => context.go(
              '${AppRoutes.tacheJour}?date=${jour.date.toIso8601String().split('T')[0]}',
            ),
          ),
          const SizedBox(height: AppSizes.md),

          // ── Actions rapides ───────────────────────────
          const _SectionTitle(title: 'Accès rapide'),
          const SizedBox(height: AppSizes.sm),
          _ActionsRapides(),
        ],

        // ── Erreur ───────────────────────────────────────
        if (state.error != null) _ErrorCard(message: state.error!),

        const SizedBox(height: AppSizes.xxl),
      ],
    );
  }
}

// ══ LAYOUT DESKTOP ════════════════════════════════════════
class _DesktopLayout extends ConsumerWidget {
  final DashboardState state;
  final dynamic employee;

  const _DesktopLayout({required this.state, required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.rouge),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Colonne gauche ───────────────────────────────
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.lg),
            children: [
              _SalutationCard(prenom: employee?.prenom ?? ''),
              const SizedBox(height: AppSizes.md),
              PresenceCardWidget(date: DateTime.now()),
              const SizedBox(height: AppSizes.md),
              if (state.messageSemaine != null)
                MessageSemaineWidget(message: state.messageSemaine!),
              const SizedBox(height: AppSizes.md),
              if (state.semaine != null) _ResumeDuJour(semaine: state.semaine!),
            ],
          ),
        ),

        // ── Colonne droite ───────────────────────────────
        Expanded(
          flex: 4,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.lg),
            children: [
              if (state.semaine != null) ...[
                const _SectionTitle(title: 'Ma semaine'),
                const SizedBox(height: AppSizes.sm),
                MiniCalendrierWidget(
                  jours: state.semaine!.jours,
                  onJourTap: (jour) => context.go(
                    '${AppRoutes.tacheJour}?date=${jour.date.toIso8601String().split('T')[0]}',
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                const _SectionTitle(title: 'Accès rapide'),
                const SizedBox(height: AppSizes.sm),
                _ActionsRapides(),
              ],
              if (state.error != null) _ErrorCard(message: state.error!),
            ],
          ),
        ),
      ],
    );
  }
}

// ══ WIDGETS COMMUNS ═══════════════════════════════════════

// ── Salutation ────────────────────────────────────────────
class _SalutationCard extends StatelessWidget {
  final String prenom;
  const _SalutationCard({required this.prenom});

  String get _salutation {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  String get _emoji {
    final h = DateTime.now().hour;
    if (h < 12) return '☀️';
    if (h < 18) return '🌤️';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_salutation $prenom $_emoji',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.noir,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            SemaineHelper.libelleSemaineCourante,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.grisDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            DateHelper.formatDate(DateTime.now()),
            style: const TextStyle(fontSize: 12, color: AppColors.grisText),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }
}

// ── Résumé du jour ────────────────────────────────────────
class _ResumeDuJour extends StatelessWidget {
  final Semaine semaine;
  const _ResumeDuJour({required this.semaine});

  @override
  Widget build(BuildContext context) {
    final jour = semaine.jourAujourdhui;
    final totalTaches = jour?.numeroTaches ?? 0;
    final totalMinutes = jour?.totalMinutes ?? 0;
    final confirmees = jour?.tachesConfirmees ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Aujourd'hui",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.grisDark,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              // Tâches
              Expanded(
                child: _StatItem(
                  icon: Icons.task_alt_rounded,
                  label: 'Tâches',
                  value: totalTaches == 0 ? '—' : '$confirmees / $totalTaches',
                  color: AppColors.fait,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              // Minutes
              Expanded(
                child: _StatItem(
                  icon: Icons.schedule_rounded,
                  label: 'Durée',
                  value: totalMinutes == 0
                      ? '—'
                      : DateHelper.minutesEnHeures(totalMinutes),
                  color: AppColors.rouge,
                ),
              ),
            ],
          ),
          if (totalTaches > 0) ...[
            const SizedBox(height: AppSizes.md),
            // Barre de progression
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalTaches > 0 ? confirmees / totalTaches : 0,
                backgroundColor: AppColors.grisMedium,
                color: AppColors.fait,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              '$confirmees tâche${confirmees > 1 ? 's' : ''} confirmée${confirmees > 1 ? 's' : ''} sur $totalTaches',
              style: const TextStyle(fontSize: 12, color: AppColors.grisText),
            ),
          ],
        ],
      ),
    )
        .animate(delay: 100.ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: AppSizes.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.grisDark),
          ),
        ],
      ),
    );
  }
}

// ── Actions rapides ───────────────────────────────────────
class _ActionsRapides extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(
        icon: Icons.today_rounded,
        label: 'Ma Journée',
        color: AppColors.rouge,
        onTap: () => context.go(AppRoutes.tacheJour),
      ),
      _ActionItem(
        icon: Icons.calendar_month_rounded,
        label: 'Mon Planning',
        color: AppColors.absent,
        onTap: () => context.go(AppRoutes.planning),
      ),
      _ActionItem(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Mémo',
        color: AppColors.fait,
        onTap: () => context.go(AppRoutes.memo),
      ),
      _ActionItem(
        icon: Icons.group_rounded,
        label: 'Chat Équipe',
        color: AppColors.aVerifier,
        onTap: () => context.go(AppRoutes.chatGroupe),
      ),
      _ActionItem(
        icon: Icons.assignment_ind_outlined,
        label: 'Tâches dispo.',
        color: AppColors.fait,
        onTap: () => context.go(AppRoutes.tachesDisponibles),
      ),
      _ActionItem(
        icon: Icons.apartment_rounded,
        label: 'Aires communes',
        color: const Color(0xFF00897B),
        onTap: () => context.go(AppRoutes.aireCommune),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSizes.md,
      mainAxisSpacing: AppSizes.md,
      childAspectRatio: 1.6,
      children: actions.asMap().entries.map((e) {
        return e.value
            .animate(delay: Duration(milliseconds: e.key * 80))
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.2, end: 0);
      }).toList(),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.noir,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppColors.grisText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Titre de section ──────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.noir,
      ),
    );
  }
}

// ── Carte erreur ──────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.rouge.withValues(alpha:0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.rouge),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.rouge, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
