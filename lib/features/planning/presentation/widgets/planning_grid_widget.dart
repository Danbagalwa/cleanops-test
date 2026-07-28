import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../../core/helpers/semaine_helper.dart';
import '../../../appartements/domain/entities/appartement.dart';
import '../../../appartements/presentation/providers/appartements_provider.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../../domain/entities/planning_template.dart';
import '../providers/planning_provider.dart';

const _kJours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];
const _kJoursCourts = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];

String _periodeLabel(PeriodeType periode) =>
    periode == PeriodeType.am ? 'Matin' : 'Après-midi';

// ── Donnée de drag — sealed class ────────────────────────
sealed class _PlanningDragData {}

final class _DragTemplate extends _PlanningDragData {
  final PlanningTemplate template;
  _DragTemplate(this.template);
}

final class _DragAppartement extends _PlanningDragData {
  final Appartement appartement;
  _DragAppartement(this.appartement);
}

// ── Couleur par taille (partagée) ─────────────────────────
Color _tailleColor(String taille) {
  return switch (taille) {
    '2 1/2' => AppColors.jourVert,
    '3 1/2' => AppColors.absent,
    '4 1/2' => AppColors.rouge,
    '5 1/2' => AppColors.aVerifier,
    _ => AppColors.grisDark,
  };
}

// ── Grille 4 semaines pour un employé ─────────────────────
class PlanningGridWidget extends ConsumerStatefulWidget {
  final String employeeId;
  final bool canEdit;
  final String? providerKey;

  const PlanningGridWidget({
    super.key,
    required this.employeeId,
    required this.canEdit,
    this.providerKey,
  });

  @override
  ConsumerState<PlanningGridWidget> createState() => _PlanningGridWidgetState();
}

class _PlanningGridWidgetState extends ConsumerState<PlanningGridWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final int _semaineCourante = SemaineHelper.semaineCourante;
  late int _currentSemaine;

  @override
  void initState() {
    super.initState();
    _currentSemaine = _semaineCourante;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _semaineCourante - 1,
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final s = _tabController.index + 1;
    if (_currentSemaine != s) setState(() => _currentSemaine = s);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final planningState =
        ref.watch(planningNotifierProvider(widget.providerKey));
    final allTemplates = planningState.pourEmployee(widget.employeeId);
    final apptState = ref.watch(appartementsNotifierProvider);

    // Appartements assignés dans la semaine courante (onglet actif)
    final assignedInSemaine = allTemplates
        .where((t) => t.numeroSemaine == _currentSemaine)
        .map((t) => t.appartementId)
        .toSet();

    final tabBar = Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        tabs: List.generate(4, (i) {
          final sem = i + 1;
          final isCurrent = sem == _semaineCourante;
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sem. $sem'),
                if (isCurrent) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.rouge,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        labelColor: AppColors.rouge,
        unselectedLabelColor: AppColors.grisText,
        indicatorColor: AppColors.rouge,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
      ),
    );

    final tabView = Expanded(
      child: TabBarView(
        controller: _tabController,
        children: List.generate(4, (i) {
          final semaine = i + 1;
          return _SemaineTab(
            employeeId: widget.employeeId,
            numeroSemaine: semaine,
            templates:
                allTemplates.where((t) => t.numeroSemaine == semaine).toList(),
            canEdit: widget.canEdit,
            providerKey: widget.providerKey,
          );
        }),
      ),
    );

    final grid = Column(children: [tabBar, tabView]);

    // Mobile ou lecture seule → pas de panel
    if (!isDesktop || !widget.canEdit) return grid;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ApartmentPanel(
          appartements: apptState.appartements,
          assignedIds: assignedInSemaine,
          isLoading: apptState.isLoading,
          currentSemaine: _currentSemaine,
        ),
        const VerticalDivider(
            width: 1, thickness: 1, color: AppColors.grisMedium),
        Expanded(child: grid),
      ],
    );
  }
}

// ── Panel appartements (gauche) ───────────────────────────
class _ApartmentPanel extends StatelessWidget {
  final List<Appartement> appartements;
  final Set<String> assignedIds;
  final bool isLoading;
  final int currentSemaine;

  const _ApartmentPanel({
    required this.appartements,
    required this.assignedIds,
    required this.isLoading,
    required this.currentSemaine,
  });

  @override
  Widget build(BuildContext context) {
    final available = appartements
        .where((a) => !assignedIds.contains(a.id))
        .toList()
      ..sort((a, b) => a.numero.compareTo(b.numero));

    return SizedBox(
      width: 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── En-tête panel ──────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: const BoxDecoration(
              color: AppColors.grisLight,
              border: Border(
                  bottom: BorderSide(color: AppColors.grisMedium)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'APPARTEMENTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grisText,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Semaine $currentSemaine',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.grisText,
                  ),
                ),
              ],
            ),
          ),

          // ── Liste ──────────────────────────────────────
          Expanded(
            child: isLoading
                ? const AppSkeletonList(
                    itemCount: 5,
                    padding: EdgeInsets.all(AppSizes.sm),
                  )
                : available.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          appartements.isEmpty
                              ? 'Aucun appartement.'
                              : 'Tous les appartements sont assignés cette semaine.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.grisText,
                            height: 1.4,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: available.length,
                        itemBuilder: (_, i) =>
                            _PanelChip(appartement: available[i]),
                      ),
          ),

          // ── Compteur bas ───────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.grisMedium)),
            ),
            child: Text(
              '${available.length} / ${appartements.length} disponibles',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.grisText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip draggable dans le panel ──────────────────────────
class _PanelChip extends StatefulWidget {
  final Appartement appartement;
  const _PanelChip({required this.appartement});

  @override
  State<_PanelChip> createState() => _PanelChipState();
}

class _PanelChipState extends State<_PanelChip> {
  bool _hovered = false;

  Widget _buildChip({bool hovered = false, bool elevated = false}) {
    final a = widget.appartement;
    final color = _tailleColor(a.taille);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: hovered || elevated
            ? color.withValues(alpha: 0.14)
            : color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: hovered || elevated ? 0.5 : 0.25),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apt. ${a.numero}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  a.taille,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.drag_indicator_rounded,
            size: 14,
            color: color.withValues(alpha: hovered ? 0.65 : 0.25),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Draggable<_PlanningDragData>(
        data: _DragAppartement(widget.appartement),
        feedback: Material(
          color: Colors.transparent,
          elevation: 0,
          child: SizedBox(
            width: 150,
            child: _buildChip(elevated: true),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.25,
          child: _buildChip(),
        ),
        child: _buildChip(hovered: _hovered),
      ),
    );
  }
}

// ── Onglet d'une semaine du cycle ─────────────────────────
class _SemaineTab extends ConsumerWidget {
  final String employeeId;
  final int numeroSemaine;
  final List<PlanningTemplate> templates;
  final bool canEdit;
  final String? providerKey;

  const _SemaineTab({
    required this.employeeId,
    required this.numeroSemaine,
    required this.templates,
    required this.canEdit,
    required this.providerKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (templates.isEmpty && !canEdit) {
      return const Center(
        child: Text(
          'Aucun appartement assigné pour cette semaine.',
          style: TextStyle(color: AppColors.grisText),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? AppSizes.md : AppSizes.sm),
      child: isDesktop
          ? _buildDesktopGrid(context, ref)
          : _buildMobileList(context, ref),
    );
  }

  Widget _buildDesktopGrid(BuildContext context, WidgetRef ref) {
    return Table(
      defaultColumnWidth: const FlexColumnWidth(),
      border: TableBorder.all(
        color: AppColors.grisMedium,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.grisLight),
          children: [
            const _HeaderCell(''),
            ..._kJoursCourts.map((j) => _HeaderCell(j)),
          ],
        ),
        TableRow(
          children: [
            const _PeriodeLabel('AM', AppColors.absent),
            ..._kJours.map((jour) => _SlotCell(
                  employeeId: employeeId,
                  numeroSemaine: numeroSemaine,
                  jour: jour,
                  periode: PeriodeType.am,
                  templates: templates,
                  canEdit: canEdit,
                  providerKey: providerKey,
                )),
          ],
        ),
        TableRow(
          children: [
            const _PeriodeLabel('PM', AppColors.aVerifier),
            ..._kJours.map((jour) => _SlotCell(
                  employeeId: employeeId,
                  numeroSemaine: numeroSemaine,
                  jour: jour,
                  periode: PeriodeType.pm,
                  templates: templates,
                  canEdit: canEdit,
                  providerKey: providerKey,
                )),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileList(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _kJours.map((jour) {
        final amTemplates = templates
            .where((t) => t.jour == jour && t.periode == PeriodeType.am)
            .toList()
          ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));
        final pmTemplates = templates
            .where((t) => t.jour == jour && t.periode == PeriodeType.pm)
            .toList()
          ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));

        if (amTemplates.isEmpty && pmTemplates.isEmpty && !canEdit) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: AppSizes.sm),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.grisMedium),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.grisLight,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppSizes.radiusSm),
                    topRight: Radius.circular(AppSizes.radiusSm),
                  ),
                ),
                child: Text(
                  jour,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.noir,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSizes.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MobilePeriodeRow(
                      label: 'AM',
                      color: AppColors.absent,
                      slots: amTemplates,
                      canEdit: canEdit,
                      providerKey: providerKey,
                      onAdd: canEdit
                          ? () => _showAddDialog(
                              context, ref, jour, PeriodeType.am)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    _MobilePeriodeRow(
                      label: 'PM',
                      color: AppColors.aVerifier,
                      slots: pmTemplates,
                      canEdit: canEdit,
                      providerKey: providerKey,
                      onAdd: canEdit
                          ? () => _showAddDialog(
                              context, ref, jour, PeriodeType.pm)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    WidgetRef ref,
    String jour,
    PeriodeType periode,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AddSlotDialog(
        employeeId: employeeId,
        numeroSemaine: numeroSemaine,
        jour: jour,
        periode: periode,
        providerKey: providerKey,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

// ── Cellule tableau desktop — drag & drop ─────────────────
class _SlotCell extends ConsumerStatefulWidget {
  final String employeeId;
  final int numeroSemaine;
  final String jour;
  final PeriodeType periode;
  final List<PlanningTemplate> templates;
  final bool canEdit;
  final String? providerKey;

  const _SlotCell({
    required this.employeeId,
    required this.numeroSemaine,
    required this.jour,
    required this.periode,
    required this.templates,
    required this.canEdit,
    required this.providerKey,
  });

  @override
  ConsumerState<_SlotCell> createState() => _SlotCellState();
}

class _SlotCellState extends ConsumerState<_SlotCell> {
  bool _isDropping = false;

  List<PlanningTemplate> get _slots => widget.templates
      .where((t) => t.jour == widget.jour && t.periode == widget.periode)
      .toList()
    ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));

  Future<void> _handleDrop(_PlanningDragData data) async {
    if (_isDropping) return;
    setState(() => _isDropping = true);

    final notifier =
        ref.read(planningNotifierProvider(widget.providerKey).notifier);

    bool ok = true;
    switch (data) {
      case _DragTemplate(template: final t):
        ok = await notifier.deplacerSlot(
          templateId: t.id,
          employeeId: widget.employeeId,
          jour: widget.jour,
          periode: widget.periode,
        );
        if (ok && mounted) {
          _showMoveConfirmation(t);
        }
      case _DragAppartement(appartement: final a):
        ok = await notifier.ajouterSlot(
          employeeId: widget.employeeId,
          appartementId: a.id,
          numeroSemaine: widget.numeroSemaine,
          jour: widget.jour,
          periode: widget.periode,
        );
    }

    if (mounted) setState(() => _isDropping = false);

    if (!ok && mounted) {
      final msg = ref
              .read(planningNotifierProvider(widget.providerKey))
              .error ??
          'Impossible d\'assigner cet appartement.';
      AppFeedback.showError(context, msg);
    }
  }

  void _showMoveConfirmation(PlanningTemplate original) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1F6B45),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  'Appartement déplacé vers ${widget.jour}, '
                  '${_periodeLabel(widget.periode).toLowerCase()}.',
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Annuler',
            textColor: Colors.white,
            onPressed: () {
              ref
                  .read(planningNotifierProvider(widget.providerKey).notifier)
                  .deplacerSlot(
                    templateId: original.id,
                    employeeId: original.employeeId,
                    jour: original.jour,
                    periode: original.periode,
                    numeroTache: original.numeroTache,
                  );
            },
          ),
        ),
      );
  }

  String? _rejectionReason(_PlanningDragData data) {
    final allTemplates =
        ref.read(planningNotifierProvider(widget.providerKey)).templates;

    // Renvoie true si l'appart est déjà attribué CE JOUR (toutes périodes,
    // tous préposés), en excluant optionnellement le template en cours de déplacement
    bool dejaPrisAujourdhui(String appartementId, {String? excludeId}) {
      return allTemplates.any((t) =>
          t.appartementId == appartementId &&
          t.numeroSemaine == widget.numeroSemaine &&
          t.jour == widget.jour &&
          (excludeId == null || t.id != excludeId));
    }

    return switch (data) {
      _DragTemplate(template: final t)
          when t.employeeId == widget.employeeId &&
              t.jour == widget.jour &&
              t.periode == widget.periode =>
        'Déjà dans ce créneau',
      _DragTemplate(template: final t)
          when dejaPrisAujourdhui(t.appartementId, excludeId: t.id) =>
        'Déjà planifié ce jour',
      _DragAppartement(appartement: final a)
          when dejaPrisAujourdhui(a.id) =>
        'Déjà planifié ce jour',
      _ => null,
    };
  }

  bool _canAccept(_PlanningDragData data) =>
      !_isDropping && _rejectionReason(data) == null;

  Widget _buildContent({
    _PlanningDragData? acceptedData,
    _PlanningDragData? rejectedData,
  }) {
    final notifier =
        ref.read(planningNotifierProvider(widget.providerKey).notifier);
    final slots = _slots;
    final isDraggingOver = acceptedData != null;
    final isRejected = rejectedData != null;
    final showStatus = isDraggingOver || isRejected || _isDropping;
    final accent = isRejected
        ? AppColors.refus
        : _isDropping
            ? AppColors.rouge
            : AppColors.fait;
    final hint = _isDropping
        ? 'Déplacement en cours…'
        : isRejected
            ? _rejectionReason(rejectedData)
            : 'Déposer ici · ${_periodeLabel(widget.periode)}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      decoration: BoxDecoration(
        color: showStatus
            ? accent.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: showStatus
              ? accent.withValues(alpha: 0.55)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showStatus)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppSizes.xs),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    isRejected
                        ? Icons.block_rounded
                        : _isDropping
                            ? Icons.sync_rounded
                            : Icons.move_down_rounded,
                    size: 14,
                    color: accent,
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Expanded(
                    child: Text(
                      hint ?? 'Ce créneau n’est pas disponible',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ...slots.map((t) {
            final chip = _ApptChip(
              template: t,
              canEdit: widget.canEdit,
              onRemove:
                  widget.canEdit ? () => notifier.supprimerSlot(t.id) : null,
            );
            if (!widget.canEdit) return chip;

            return Draggable<_PlanningDragData>(
              data: _DragTemplate(t),
              maxSimultaneousDrags: _isDropping ? 0 : 1,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: Material(
                color: Colors.transparent,
                elevation: 6,
                borderRadius: BorderRadius.circular(4),
                child: _ApptChip(
                  template: t,
                  canEdit: false,
                  isDragging: true,
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.25,
                child: _ApptChip(template: t, canEdit: false),
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Tooltip(
                  message: 'Glisser pour déplacer cet appartement',
                  child: chip,
                ),
              ),
            );
          }),
          if (widget.canEdit)
            Padding(
              padding: slots.isEmpty
                  ? EdgeInsets.zero
                  : const EdgeInsets.only(top: 3),
              child: _AddButton(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => _AddSlotDialog(
                    employeeId: widget.employeeId,
                    numeroSemaine: widget.numeroSemaine,
                    jour: widget.jour,
                    periode: widget.periode,
                    providerKey: widget.providerKey,
                    onClose: () => Navigator.of(ctx).pop(),
                  ),
                ),
                isEmpty: slots.isEmpty,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canEdit) {
      return TableCell(child: _buildContent());
    }

    return TableCell(
      child: DragTarget<_PlanningDragData>(
        onWillAcceptWithDetails: (d) => _canAccept(d.data),
        onAcceptWithDetails: (d) => _handleDrop(d.data),
        builder: (context, candidateData, rejectedData) => _buildContent(
          acceptedData:
              candidateData.isEmpty ? null : candidateData.first,
          rejectedData:
              rejectedData.isEmpty
                  ? null
                  : rejectedData.first as _PlanningDragData,
        ),
      ),
    );
  }
}

// ── Bouton "+ Ajouter" ────────────────────────────────────
class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isEmpty;
  const _AddButton({required this.onTap, required this.isEmpty});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.rouge.withValues(alpha: 0.13)
                : AppColors.rouge.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.rouge.withValues(alpha: _hovered ? 0.35 : 0.2),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 11, color: AppColors.rouge),
              SizedBox(width: 2),
              Text(
                'Ajouter',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.rouge,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge appartement (dans les cellules) ─────────────────
class _ApptChip extends StatefulWidget {
  final PlanningTemplate template;
  final bool canEdit;
  final VoidCallback? onRemove;
  final bool isDragging;

  const _ApptChip({
    required this.template,
    required this.canEdit,
    this.onRemove,
    this.isDragging = false,
  });

  @override
  State<_ApptChip> createState() => _ApptChipState();
}

class _ApptChipState extends State<_ApptChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final appt = widget.template.appartement;
    final taille = appt?.taille ?? '?';
    final color = _tailleColor(taille);
    final showRemove = widget.canEdit && widget.onRemove != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: widget.isDragging
              ? color.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: color.withValues(alpha: widget.isDragging ? 0.5 : 0.3),
          ),
          boxShadow: widget.isDragging
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appt?.numero ?? '—',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (appt != null) ...[
              const SizedBox(width: 3),
              Text(
                taille,
                style: TextStyle(
                    fontSize: 10, color: color.withValues(alpha: 0.8)),
              ),
            ],
            if (showRemove)
              AnimatedSize(
                duration: const Duration(milliseconds: 140),
                child: _hovered
                    ? GestureDetector(
                        onTap: widget.onRemove,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Icon(Icons.close_rounded,
                              size: 11,
                              color: color.withValues(alpha: 0.8)),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── En-tête colonne tableau ───────────────────────────────
class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.grisText,
            letterSpacing: 0.3,
          ),
          textAlign: label.isEmpty ? TextAlign.start : TextAlign.center,
        ),
      ),
    );
  }
}

// ── Label AM/PM (première colonne) ────────────────────────
class _PeriodeLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _PeriodeLabel(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ── Ligne période mobile ──────────────────────────────────
class _MobilePeriodeRow extends ConsumerWidget {
  final String label;
  final Color color;
  final List<PlanningTemplate> slots;
  final bool canEdit;
  final VoidCallback? onAdd;
  final String? providerKey;

  const _MobilePeriodeRow({
    required this.label,
    required this.color,
    required this.slots,
    required this.canEdit,
    required this.providerKey,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              ...slots.map((t) => _ApptChip(
                    template: t,
                    canEdit: canEdit,
                    onRemove: canEdit
                        ? () => ref
                            .read(planningNotifierProvider(providerKey)
                                .notifier)
                            .supprimerSlot(t.id)
                        : null,
                  )),
              if (canEdit)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.rouge.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppColors.rouge.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 13, color: AppColors.rouge),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Dialog ajout d'appartement ────────────────────────────
class _AddSlotDialog extends ConsumerStatefulWidget {
  final String employeeId;
  final int numeroSemaine;
  final String jour;
  final PeriodeType periode;
  final String? providerKey;
  final VoidCallback onClose;

  const _AddSlotDialog({
    required this.employeeId,
    required this.numeroSemaine,
    required this.jour,
    required this.periode,
    required this.providerKey,
    required this.onClose,
  });

  @override
  ConsumerState<_AddSlotDialog> createState() => _AddSlotDialogState();
}

class _AddSlotDialogState extends ConsumerState<_AddSlotDialog> {
  Appartement? _selected;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final apptState = ref.watch(appartementsNotifierProvider);
    final planningState =
        ref.watch(planningNotifierProvider(widget.providerKey));

    // Règle : un appartement ne peut être visité qu'une seule fois par jour
    // → on exclut tout appartement déjà attribué ce jour, quelle que soit la
    // période (AM ou PM) et quel que soit le préposé
    final prisAujourdhui = planningState.templates
        .where((t) =>
            t.numeroSemaine == widget.numeroSemaine &&
            t.jour == widget.jour)
        .map((t) => t.appartementId)
        .toSet();

    final disponibles = apptState.appartements
        .where((a) => !prisAujourdhui.contains(a.id))
        .toList();

    final nbMasques = apptState.appartements
        .where((a) => prisAujourdhui.contains(a.id))
        .length;

    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
      title: Text(
        '${widget.jour} — ${widget.periode.label}  ·  Sem. ${widget.numeroSemaine}',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 340,
        child: apptState.isLoading
            ? const AppSkeletonForm(fieldCount: 3)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Erreur inline ──────────────────────
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.refus.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusSm),
                        border: Border.all(
                            color: AppColors.refus.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 15, color: AppColors.refus),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.refus),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ── Dropdown ───────────────────────────
                  if (disponibles.isEmpty)
                    Text(
                      nbMasques > 0
                          ? 'Tous les appartements disponibles sont déjà attribués ce jour.'
                          : 'Aucun appartement disponible.',
                      style: const TextStyle(color: AppColors.grisText),
                    )
                  else
                    DropdownButtonFormField<Appartement>(
                      initialValue: _selected,
                      hint: const Text('Choisir un appartement'),
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSm),
                          borderSide:
                              const BorderSide(color: AppColors.grisMedium),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      items: disponibles
                          .map((a) => DropdownMenuItem(
                                value: a,
                                child: Text(
                                  'Apt. ${a.numero}  ·  ${a.taille}  ·  ${a.minutesBase} min',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ))
                          .toList(),
                      onChanged: (a) =>
                          setState(() {
                            _selected = a;
                            _error = null;
                          }),
                    ),

                  // ── Note appartements masqués ──────────
                  if (nbMasques > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 13,
                            color: AppColors.grisText.withValues(alpha: 0.7)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '$nbMasques appartement${nbMasques > 1 ? 's' : ''} '
                            'masqué${nbMasques > 1 ? 's' : ''} — '
                            'déjà attribué${nbMasques > 1 ? 's' : ''} ce jour.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.grisText.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onClose,
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
          onPressed: _selected == null || _saving
              ? null
              : () async {
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  final ok = await ref
                      .read(planningNotifierProvider(widget.providerKey)
                          .notifier)
                      .ajouterSlot(
                        employeeId: widget.employeeId,
                        appartementId: _selected!.id,
                        numeroSemaine: widget.numeroSemaine,
                        jour: widget.jour,
                        periode: widget.periode,
                      );
                  if (ok && mounted) {
                    widget.onClose();
                  } else if (mounted) {
                    setState(() {
                      _saving = false;
                      _error = ref
                              .read(planningNotifierProvider(widget.providerKey))
                              .error ??
                          'Impossible d\'assigner cet appartement.';
                      _selected = null;
                    });
                  }
                },
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Ajouter'),
        ),
      ],
    );
  }
}
