import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../presences/domain/entities/presence.dart';
import '../../../presences/presentation/providers/presence_provider.dart';
import '../providers/tache_jour_provider.dart';
import '../widgets/tache_card_widget.dart';
import '../../domain/entities/tache_jour.dart';

class TacheJourScreen extends ConsumerStatefulWidget {
  final String? date;
  const TacheJourScreen({super.key, this.date});

  @override
  ConsumerState<TacheJourScreen> createState() => _TacheJourScreenState();
}

class _TacheJourScreenState extends ConsumerState<TacheJourScreen> {
  late String _dateStr;
  late DateTime _date;
  Set<String> _poolTaskIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = widget.date != null
        ? DateTime.parse(widget.date!)
        : DateTime(now.year, now.month, now.day);
    _dateStr = _toIso(_date);

    Future.microtask(() async {
      final emp = ref.read(employeeCourantProvider);
      if (emp != null) {
        ref
            .read(tacheJourNotifierProvider(_dateStr).notifier)
            .charger(employeeId: emp.id);
        ref
            .read(maPresenceNotifierProvider(emp.id).notifier)
            .charger(_date);
        await _chargerPoolIds();
      }
    });
  }

  String _toIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _nomJour {
    const noms = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    return noms[_date.weekday - 1];
  }

  Future<void> _rafraichir() async {
    final emp = ref.read(employeeCourantProvider);
    if (emp != null) {
      await Future.wait([
        ref
            .read(tacheJourNotifierProvider(_dateStr).notifier)
            .charger(employeeId: emp.id),
        ref
            .read(maPresenceNotifierProvider(emp.id).notifier)
            .charger(_date),
        _chargerPoolIds(),
      ]);
    }
  }

  Future<void> _chargerPoolIds() async {
    try {
      final data = await SupabaseService
          .table(SupabaseService.tachesDisponibles)
          .select('tache_jour_id')
          .eq('statut', 'Disponible');
      if (mounted) {
        setState(() {
          _poolTaskIds = (data as List)
              .map((r) => r['tache_jour_id'] as String)
              .toSet();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tacheJourNotifierProvider(_dateStr));
    final employee = ref.watch(employeeCourantProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;

    final presenceStatut = employee != null
        ? ref.watch(maPresenceNotifierProvider(employee.id)).maPresence?.statut
        : null;

    // Determine which periods are visible based on presence
    final showAm = presenceStatut == null ||
        presenceStatut == StatutPresence.present ||
        presenceStatut == StatutPresence.absentApresMidi;
    final showPm = presenceStatut == null ||
        presenceStatut == StatutPresence.present ||
        presenceStatut == StatutPresence.absentMatin;

    // Les tâches prises volontairement (is_transfert_temp) restent toujours visibles.
    // Les tâches actuellement dans le pool (libérées, statut=Disponible) sont masquées.
    final visibleAmTaches = (showAm
            ? state.amTaches
            : state.amTaches.where((t) => t.isTransfertTemp).toList())
        .where((t) => !_poolTaskIds.contains(t.id))
        .toList();
    final visiblePmTaches = (showPm
            ? state.pmTaches
            : state.pmTaches.where((t) => t.isTransfertTemp).toList())
        .where((t) => !_poolTaskIds.contains(t.id))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: _buildAppBar(state),
      body: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _rafraichir,
        child: _buildBody(
          state,
          isDesktop,
          visibleAmTaches,
          visiblePmTaches,
          presenceStatut,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(TacheJourState state) {
    return AppBar(
      backgroundColor: AppColors.rouge,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _nomJour,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            DateHelper.formatDate(_date),
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
      actions: [
        if (state.isLoading && state.taches.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(right: AppSizes.md),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _rafraichir,
            tooltip: 'Rafraîchir',
          ),
      ],
    );
  }

  Widget _buildBody(
    TacheJourState state,
    bool isDesktop,
    List<TacheJour> visibleAmTaches,
    List<TacheJour> visiblePmTaches,
    StatutPresence? presenceStatut,
  ) {
    if (state.isLoading && state.taches.isEmpty) {
      return const AppSkeletonList(itemCount: 5);
    }
    if (state.error != null && state.taches.isEmpty) {
      return _ErrorState(message: state.error!, onRetry: _rafraichir);
    }
    if (state.taches.isEmpty) {
      return const _EmptyState();
    }

    if (isDesktop) {
      return _DesktopLayout(
        state: state,
        dateStr: _dateStr,
        onRefresh: _rafraichir,
        amTaches: visibleAmTaches,
        pmTaches: visiblePmTaches,
        absenceStatut: presenceStatut,
      );
    } else {
      return _MobileLayout(
        state: state,
        dateStr: _dateStr,
        amTaches: visibleAmTaches,
        pmTaches: visiblePmTaches,
        absenceStatut: presenceStatut,
      );
    }
  }
}

// ══ LAYOUT DESKTOP ════════════════════════════════════════
class _DesktopLayout extends StatelessWidget {
  final TacheJourState state;
  final String dateStr;
  final Future<void> Function() onRefresh;
  final List<TacheJour> amTaches;
  final List<TacheJour> pmTaches;
  final StatutPresence? absenceStatut;

  const _DesktopLayout({
    required this.state,
    required this.dateStr,
    required this.onRefresh,
    required this.amTaches,
    required this.pmTaches,
    this.absenceStatut,
  });

  @override
  Widget build(BuildContext context) {
    final isAbsent = absenceStatut != null && absenceStatut!.estAbsent;

    return Column(
      children: [
        // ── Bandeau absence (si applicable) ──────────────
        if (isAbsent)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: _AbsenceBanner(statut: absenceStatut!),
              ),
            ),
          ),

        // ── Bandeau récap centré ─────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.lg,
            isAbsent ? AppSizes.sm : AppSizes.md,
            AppSizes.lg,
            0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: _SummaryBanner(taches: [...amTaches, ...pmTaches]),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.md),

        // ── Deux panneaux côte à côte ────────────────────
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg, 0, AppSizes.lg, AppSizes.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Panel(
                        label: 'Matin',
                        icon: Icons.wb_sunny_outlined,
                        color: AppColors.absent,
                        taches: amTaches,
                        dateStr: dateStr,
                        updatingIds: state.updatingIds,
                        hidden: absenceStatut == StatutPresence.absentMatin ||
                            absenceStatut == StatutPresence.absent,
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: _Panel(
                        label: 'Après-midi',
                        icon: Icons.nights_stay_outlined,
                        color: AppColors.aVerifier,
                        taches: pmTaches,
                        dateStr: dateStr,
                        updatingIds: state.updatingIds,
                        hidden:
                            absenceStatut == StatutPresence.absentApresMidi ||
                                absenceStatut == StatutPresence.absent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══ LAYOUT MOBILE ═════════════════════════════════════════
class _MobileLayout extends StatelessWidget {
  final TacheJourState state;
  final String dateStr;
  final List<TacheJour> amTaches;
  final List<TacheJour> pmTaches;
  final StatutPresence? absenceStatut;

  const _MobileLayout({
    required this.state,
    required this.dateStr,
    required this.amTaches,
    required this.pmTaches,
    this.absenceStatut,
  });

  @override
  Widget build(BuildContext context) {
    final isAbsent = absenceStatut != null && absenceStatut!.estAbsent;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isAbsent) ...[
            _AbsenceBanner(statut: absenceStatut!),
            const SizedBox(height: AppSizes.sm),
          ],
          _SummaryBanner(taches: [...amTaches, ...pmTaches]),
          const SizedBox(height: AppSizes.md),
          _MobileSection(
            label: 'Matin',
            icon: Icons.wb_sunny_outlined,
            color: AppColors.absent,
            taches: amTaches,
            dateStr: dateStr,
            updatingIds: state.updatingIds,
            hidden: absenceStatut == StatutPresence.absentMatin ||
                absenceStatut == StatutPresence.absent,
          ),
          const SizedBox(height: AppSizes.md),
          _MobileSection(
            label: 'Après-midi',
            icon: Icons.nights_stay_outlined,
            color: AppColors.aVerifier,
            taches: pmTaches,
            dateStr: dateStr,
            updatingIds: state.updatingIds,
            hidden: absenceStatut == StatutPresence.absentApresMidi ||
                absenceStatut == StatutPresence.absent,
          ),
          const SizedBox(height: AppSizes.xxl),
        ],
      ),
    );
  }
}

// ══ PANNEAU DESKTOP (avec ListView interne) ════════════════
class _Panel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<TacheJour> taches;
  final String dateStr;
  final Set<String> updatingIds;
  final bool hidden;

  const _Panel({
    required this.label,
    required this.icon,
    required this.color,
    required this.taches,
    required this.dateStr,
    required this.updatingIds,
    this.hidden = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Column(
          children: [
            // ── En-tête ──────────────────────────────────
            _PanelHeader(
              label: label,
              icon: icon,
              color: color,
              count: hidden ? 0 : taches.length,
            ),

            // ── Liste, état vide ou masqué ───────────────
            Expanded(
              child: hidden
                  ? _PanelHidden(label: label, color: color)
                  : taches.isEmpty
                      ? _PanelEmpty(label: label, color: color)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSizes.sm),
                          itemCount: taches.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: AppSizes.md,
                            endIndent: AppSizes.md,
                            color: Color(0xFFF0F0F0),
                          ),
                          itemBuilder: (_, i) => TacheCardWidget(
                            tache: taches[i],
                            dateStr: dateStr,
                            isUpdating: updatingIds.contains(taches[i].id),
                            inPanel: true,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══ SECTION MOBILE (hauteur naturelle) ════════════════════
class _MobileSection extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<TacheJour> taches;
  final String dateStr;
  final Set<String> updatingIds;
  final bool hidden;

  const _MobileSection({
    required this.label,
    required this.icon,
    required this.color,
    required this.taches,
    required this.dateStr,
    required this.updatingIds,
    this.hidden = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PanelHeader(
              label: label,
              icon: icon,
              color: color,
              count: hidden ? 0 : taches.length,
            ),
            if (hidden)
              _PanelHidden(label: label, color: color)
            else if (taches.isEmpty)
              _PanelEmpty(label: label, color: color)
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < taches.length; i++) ...[
                    TacheCardWidget(
                      tache: taches[i],
                      dateStr: dateStr,
                      isUpdating: updatingIds.contains(taches[i].id),
                      inPanel: true,
                    ),
                    if (i < taches.length - 1)
                      const Divider(
                        height: 1,
                        indent: AppSizes.md,
                        endIndent: AppSizes.md,
                        color: Color(0xFFF0F0F0),
                      ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── En-tête de panneau ────────────────────────────────────
class _PanelHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;

  const _PanelHeader({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: color.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.noir,
            ),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count tâche${count > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── État masqué (absence) d'un panneau ───────────────────
class _PanelHidden extends StatelessWidget {
  final String label;
  final Color color;

  const _PanelHidden({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.visibility_off_rounded,
            size: 36,
            color: AppColors.grisMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Tâches masquées — absence $label',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.grisText,
            ),
          ),
        ],
      ),
    );
  }
}

// ── État vide d'un panneau ────────────────────────────────
class _PanelEmpty extends StatelessWidget {
  final String label;
  final Color color;

  const _PanelEmpty({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 36,
            color: color.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 10),
          Text(
            'Aucune tâche le $label',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.grisText,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bandeau absence ───────────────────────────────────────
class _AbsenceBanner extends StatelessWidget {
  final StatutPresence statut;
  const _AbsenceBanner({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String message) = switch (statut) {
      StatutPresence.absent => (
          Icons.person_off_outlined,
          AppColors.rouge,
          'Vous êtes absente aujourd\'hui. Aucune tâche à effectuer.',
        ),
      StatutPresence.absentMatin => (
          Icons.wb_sunny_outlined,
          AppColors.aVerifier,
          'Vous êtes absente ce matin. Seules les tâches de l\'après-midi sont visibles.',
        ),
      StatutPresence.absentApresMidi => (
          Icons.nights_stay_outlined,
          AppColors.aVerifier,
          'Vous êtes absente cet après-midi. Seules les tâches du matin sont visibles.',
        ),
      _ => (Icons.info_outline_rounded, AppColors.grisDark, ''),
    };

    if (message.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bandeau récapitulatif ─────────────────────────────────
class _SummaryBanner extends StatelessWidget {
  final List<TacheJour> taches;
  const _SummaryBanner({required this.taches});

  @override
  Widget build(BuildContext context) {
    final total = taches.length;
    final confirmees = taches.where((t) => t.estConfirmee).length;
    final minutes = taches.fold(0, (s, t) => s + t.minutesEstimees);
    final progression = total > 0 ? confirmees / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.task_alt_rounded,
                  value: '$confirmees / $total',
                  label: 'Tâches',
                  color: AppColors.fait,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: _Stat(
                  icon: Icons.schedule_rounded,
                  value: minutes > 0
                      ? DateHelper.minutesEnHeures(minutes)
                      : '—',
                  label: 'Durée estimée',
                  color: AppColors.rouge,
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: AppSizes.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progression,
                backgroundColor: AppColors.grisMedium,
                color: progression == 1.0 ? AppColors.fait : AppColors.rouge,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              confirmees == total && total > 0
                  ? 'Journée complète ✓'
                  : '$confirmees tâche${confirmees > 1 ? 's' : ''} confirmée${confirmees > 1 ? 's' : ''} sur $total',
              style: TextStyle(
                fontSize: 12,
                color: confirmees == total
                    ? AppColors.fait
                    : AppColors.grisText,
                fontWeight: confirmees == total
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.grisDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── État vide global ──────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_rounded,
              size: 56, color: AppColors.grisMedium),
          SizedBox(height: 16),
          Center(
            child: Text(
              'Aucune tâche pour cette journée.',
              style: TextStyle(fontSize: 15, color: AppColors.grisText),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'Profitez de votre journée !',
              style: TextStyle(fontSize: 13, color: AppColors.grisMedium),
            ),
          ),
        ],
      ),
    );
  }
}

// ── État d'erreur ─────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
        child: AppErrorNotice(error: message, onRetry: onRetry),
      ),
    );
  }
}
