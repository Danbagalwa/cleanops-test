import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../appartements/domain/entities/appartement.dart';
import '../../../appartements/presentation/providers/appartements_provider.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../../domain/entities/planning_template.dart';
import '../providers/planning_provider.dart';
import 'package:cleanops/core/widgets/espace_barre_mobile.dart';
import 'package:cleanops/core/widgets/dialogue_app.dart';
import 'package:cleanops/core/widgets/notification_app.dart';

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

// ── Grille d'une semaine pour un employé ─────────────────
/// Planning d'une préposée pour UNE semaine du cycle ([numeroSemaine]) : le
/// choix de la semaine appartient à la page (filtres de sa barre de section).
/// Sur bureau, en modification, le panneau des appartements (glisser-déposer)
/// est affiché à gauche.
class PlanningGridWidget extends ConsumerWidget {
  final String employeeId;
  final int numeroSemaine;
  final bool canEdit;
  final String? providerKey;

  const PlanningGridWidget({
    super.key,
    required this.employeeId,
    required this.numeroSemaine,
    required this.canEdit,
    this.providerKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final planningState = ref.watch(planningNotifierProvider(providerKey));
    final templates = planningState
        .pourEmployee(employeeId)
        .where((t) => t.numeroSemaine == numeroSemaine)
        .toList();

    final grid = _SemaineTab(
      employeeId: employeeId,
      numeroSemaine: numeroSemaine,
      templates: templates,
      canEdit: canEdit,
      providerKey: providerKey,
    );

    // Mobile ou lecture seule → pas de panel
    if (!isDesktop || !canEdit) return grid;

    final apptState = ref.watch(appartementsNotifierProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ApartmentPanel(
          appartements: apptState.appartements,
          assignedIds: templates.map((t) => t.appartementId).toSet(),
          isLoading: apptState.isLoading,
          currentSemaine: numeroSemaine,
        ),
        const VerticalDivider(
            width: 1, thickness: 1, color: AppColors.grisMedium),
        Expanded(child: grid),
      ],
    );
  }
}

// ── Panel appartements (gauche) ───────────────────────────
/// Réserve des appartements non placés cette semaine, à glisser dans la
/// grille. Grille compacte sur deux colonnes, recherche instantanée et
/// flèches pour parcourir la liste sans molette.
class _ApartmentPanel extends StatefulWidget {
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
  State<_ApartmentPanel> createState() => _ApartmentPanelState();
}

class _ApartmentPanelState extends State<_ApartmentPanel> {
  final _recherche = TextEditingController();
  final _defilement = ScrollController();
  bool _peutMonter = false;
  bool _peutDescendre = false;

  @override
  void dispose() {
    _recherche.dispose();
    _defilement.dispose();
    super.dispose();
  }

  void _majFleches(ScrollMetrics m) {
    final monter = m.pixels > m.minScrollExtent + 1;
    final descendre = m.pixels < m.maxScrollExtent - 1;
    if (monter != _peutMonter || descendre != _peutDescendre) {
      setState(() {
        _peutMonter = monter;
        _peutDescendre = descendre;
      });
    }
  }

  void _defiler(int sens) {
    if (!_defilement.hasClients) return;
    final p = _defilement.position;
    final cible = (p.pixels + sens * p.viewportDimension * 0.8)
        .clamp(p.minScrollExtent, p.maxScrollExtent);
    _defilement.animateTo(
      cible,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.appartements
        .where((a) => !widget.assignedIds.contains(a.id))
        .toList()
      ..sort((a, b) => a.numero.compareTo(b.numero));
    final filtres =
        available.where((a) => _correspond(a, _recherche.text)).toList();

    final grilleVisible = !widget.isLoading && filtres.isNotEmpty;
    final Widget liste;
    if (widget.isLoading) {
      liste = const AppSkeletonList(
        itemCount: 5,
        padding: EdgeInsets.all(AppSizes.sm),
      );
    } else if (available.isEmpty || filtres.isEmpty) {
      liste = Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          widget.appartements.isEmpty
              ? 'Aucun appartement.'
              : available.isEmpty
                  ? 'Tous les appartements sont assignés cette semaine.'
                  : 'Aucun résultat.',
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.grisText,
            height: 1.4,
          ),
        ),
      );
    } else {
      liste = NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) {
          _majFleches(n.metrics);
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            _majFleches(n.metrics);
            return false;
          },
          child: GridView.builder(
            controller: _defilement,
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 42,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: filtres.length,
            itemBuilder: (_, i) => _PanelChip(appartement: filtres[i]),
          ),
        ),
      );
    }

    return SizedBox(
      width: 204,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── En-tête panel ──────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: const BoxDecoration(
              color: AppColors.grisLight,
              border: Border(bottom: BorderSide(color: AppColors.grisMedium)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'À PLACER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grisText,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Text(
                      'Semaine ${widget.currentSemaine}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.grisText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ChampRechercheAppartement(
                  controller: _recherche,
                  dense: true,
                  onChanged: (_) => setState(() {
                    if (_defilement.hasClients) _defilement.jumpTo(0);
                  }),
                ),
              ],
            ),
          ),

          // ── Liste ──────────────────────────────────────
          Expanded(child: liste),

          // ── Compteur + flèches de défilement ───────────
          Container(
            padding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.grisMedium)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _recherche.text.trim().isEmpty
                        ? '${available.length} / ${widget.appartements.length} disponibles'
                        : '${filtres.length} résultat${filtres.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.grisText,
                    ),
                  ),
                ),
                _FlecheDefilement(
                  icone: Icons.keyboard_arrow_up_rounded,
                  infoBulle: 'Monter',
                  onTap:
                      grilleVisible && _peutMonter ? () => _defiler(-1) : null,
                ),
                _FlecheDefilement(
                  icone: Icons.keyboard_arrow_down_rounded,
                  infoBulle: 'Descendre',
                  onTap: grilleVisible && _peutDescendre
                      ? () => _defiler(1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlecheDefilement extends StatelessWidget {
  final IconData icone;
  final String infoBulle;
  final VoidCallback? onTap;

  const _FlecheDefilement({
    required this.icone,
    required this.infoBulle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: infoBulle,
      onPressed: onTap,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      color: AppColors.rouge,
      disabledColor: AppColors.grisMedium,
      icon: Icon(icone),
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
      padding: const EdgeInsets.symmetric(horizontal: 7),
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
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.numero,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  a.taille,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.drag_indicator_rounded,
            size: 13,
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
      child: Tooltip(
        message: 'Apt. ${widget.appartement.numero} · '
            '${widget.appartement.taille} · '
            '${widget.appartement.minutesBase} min',
        waitDuration: const Duration(milliseconds: 600),
        child: Draggable<_PlanningDragData>(
          data: _DragAppartement(widget.appartement),
          feedback: Material(
            color: Colors.transparent,
            elevation: 0,
            child: SizedBox(
              width: 110,
              height: 42,
              child: _buildChip(elevated: true),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: _buildChip(),
          ),
          child: _buildChip(hovered: _hovered),
        ),
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
      padding: EdgeInsets.all(isDesktop ? AppSizes.md : AppSizes.sm)
          .plusBarre(context),
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
                          ? () =>
                              _showAddDialog(context, ref, jour, PeriodeType.am)
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
                          ? () =>
                              _showAddDialog(context, ref, jour, PeriodeType.pm)
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
      final msg =
          ref.read(planningNotifierProvider(widget.providerKey)).error ??
              'Impossible d\'assigner cet appartement.';
      AppFeedback.showError(context, msg);
    }
  }

  void _showMoveConfirmation(PlanningTemplate original) {
    NotificationApp.succes(
      context,
      'Appartement déplacé vers ${widget.jour}, '
      '${_periodeLabel(widget.periode).toLowerCase()}.',
      libelleAction: 'Annuler',
      onAction: () {
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
      _DragAppartement(appartement: final a) when dejaPrisAujourdhui(a.id) =>
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
        color: showStatus ? accent.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color:
              showStatus ? accent.withValues(alpha: 0.55) : Colors.transparent,
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
          acceptedData: candidateData.isEmpty ? null : candidateData.first,
          rejectedData: rejectedData.isEmpty
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
                              size: 11, color: color.withValues(alpha: 0.8)),
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
                            .read(
                                planningNotifierProvider(providerKey).notifier)
                            .supprimerSlot(t.id)
                        : null,
                  )),
              if (canEdit)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
  final _recherche = TextEditingController();
  late PeriodeType _periode = widget.periode;

  /// Appartements cochés, dans l'ordre de sélection (= ordre d'ajout).
  final _selection = <String>{};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  int _placesLibres(PlanningState planning, PeriodeType periode) {
    final occupees = planning
        .pourSlot(widget.employeeId, widget.numeroSemaine, widget.jour, periode)
        .length;
    return (PlanningNotifier.capaciteMaxParPeriode - occupees)
        .clamp(0, PlanningNotifier.capaciteMaxParPeriode);
  }

  void _basculer(Appartement a, int places) {
    setState(() {
      _error = null;
      if (!_selection.remove(a.id) && _selection.length < places) {
        _selection.add(a.id);
      }
    });
  }

  void _toutSelectionner(List<Appartement> visibles, int places) {
    setState(() {
      _error = null;
      for (final a in visibles) {
        if (_selection.length >= places) break;
        _selection.add(a.id);
      }
    });
  }

  Future<void> _ajouter(List<Appartement> appartements) async {
    final choisis = [
      for (final id in _selection) appartements.firstWhere((a) => a.id == id),
    ];
    if (choisis.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final notifier =
        ref.read(planningNotifierProvider(widget.providerKey).notifier);
    final echecs = <String>[];
    String? raison;
    for (final a in choisis) {
      final ok = await notifier.ajouterSlot(
        employeeId: widget.employeeId,
        appartementId: a.id,
        numeroSemaine: widget.numeroSemaine,
        jour: widget.jour,
        periode: _periode,
      );
      if (ok) {
        _selection.remove(a.id);
      } else {
        echecs.add(a.numero);
        raison ??= ref.read(planningNotifierProvider(widget.providerKey)).error;
      }
      if (!mounted) return;
    }

    final ajoutes = choisis.length - echecs.length;
    final periode = _periodeLabel(_periode).toLowerCase();
    if (echecs.isEmpty) {
      widget.onClose();
      NotificationApp.succes(
        context,
        ajoutes == 1
            ? 'Apt. ${choisis.first.numero} ajouté — ${widget.jour} $periode.'
            : '$ajoutes appartements ajoutés — ${widget.jour} $periode.',
      );
      return;
    }
    setState(() {
      _saving = false;
      _error = [
        if (ajoutes > 0)
          '$ajoutes ajouté${ajoutes > 1 ? 's' : ''}, '
              'mais ${echecs.length} non ajouté${echecs.length > 1 ? 's' : ''} '
              '(Apt. ${echecs.join(', ')}).',
        raison ?? 'Impossible d\'assigner ces appartements.',
      ].join(' ');
    });
  }

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
            t.numeroSemaine == widget.numeroSemaine && t.jour == widget.jour)
        .map((t) => t.appartementId)
        .toSet();

    final disponibles = apptState.appartements
        .where((a) => !prisAujourdhui.contains(a.id))
        .toList()
      ..sort((a, b) => a.numero.compareTo(b.numero));
    final nbMasques = apptState.appartements.length - disponibles.length;
    final filtres =
        disponibles.where((a) => _correspond(a, _recherche.text)).toList();

    final places = _placesLibres(planningState, _periode);
    final nb = _selection.length;
    final depasse = nb > places;
    final complet = nb >= places;

    return DialogueApp(
      titre: 'Ajouter des appartements',
      libelleAction: nb > 1 ? 'Ajouter ($nb)' : 'Ajouter',
      enCours: _saving,
      onFermer: widget.onClose,
      onAction: nb == 0 || depasse ? null : () => _ajouter(disponibles),
      contenu: apptState.isLoading
          ? const AppSkeletonForm(fieldCount: 3)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Créneau visé ───────────────────────
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pastille(icone: Icons.today_rounded, libelle: widget.jour),
                    _Pastille(
                      icone: Icons.event_repeat_rounded,
                      libelle: 'Semaine ${widget.numeroSemaine}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ChoixPeriode(
                  periode: _periode,
                  placesMatin: _placesLibres(planningState, PeriodeType.am),
                  placesApresMidi: _placesLibres(planningState, PeriodeType.pm),
                  onChanged: _saving
                      ? null
                      : (p) => setState(() {
                            _periode = p;
                            _error = null;
                          }),
                ),
                const SizedBox(height: 16),

                // ── Erreur inline ──────────────────────
                if (_error != null) ...[
                  _ErreurInline(_error!),
                  const SizedBox(height: 12),
                ],

                if (disponibles.isEmpty)
                  Text(
                    nbMasques > 0
                        ? 'Tous les appartements disponibles sont déjà attribués ce jour.'
                        : 'Aucun appartement disponible.',
                    style: const TextStyle(color: AppColors.grisText),
                  )
                else if (places == 0)
                  Text(
                    'Le ${widget.jour.toLowerCase()} '
                    '${_periodeLabel(_periode).toLowerCase()} est complet '
                    '(${PlanningNotifier.capaciteMaxParPeriode} tâches). '
                    'Choisissez l\'autre période ou retirez une tâche.',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.grisText, height: 1.4),
                  )
                else ...[
                  _ChampRechercheAppartement(
                    controller: _recherche,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),

                  // ── Compteur de sélection ──────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          depasse
                              ? '$nb sélectionnés pour $places place${places > 1 ? 's' : ''} : '
                                  'retirez-en ${nb - places}.'
                              : '$nb sélectionné${nb > 1 ? 's' : ''} · '
                                  '$places place${places > 1 ? 's' : ''} libre${places > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                depasse ? AppColors.refus : AppColors.grisDark,
                          ),
                        ),
                      ),
                      if (nb > 0)
                        _LienTexte(
                          libelle: 'Effacer',
                          onTap:
                              _saving ? null : () => setState(_selection.clear),
                        )
                      else
                        _LienTexte(
                          libelle: filtres.length > places
                              ? 'Sélectionner $places'
                              : 'Tout sélectionner',
                          onTap: _saving || filtres.isEmpty
                              ? null
                              : () => _toutSelectionner(filtres, places),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 264),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.grisMedium),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: filtres.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Aucun appartement ne correspond à la recherche.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12.5, color: AppColors.grisText),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: filtres.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, indent: 12, endIndent: 12),
                            itemBuilder: (_, i) {
                              final a = filtres[i];
                              final coche = _selection.contains(a.id);
                              return _LigneAppartement(
                                appartement: a,
                                selectionne: coche,
                                desactive: _saving || (!coche && complet),
                                onTap: () => _basculer(a, places),
                              );
                            },
                          ),
                  ),
                ],

                // ── Note appartements masqués ──────────
                if (nbMasques > 0) ...[
                  const SizedBox(height: 10),
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
    );
  }
}

/// Choix Matin / Après-midi du dialogue d'ajout, avec les places libres.
class _ChoixPeriode extends StatelessWidget {
  final PeriodeType periode;
  final int placesMatin;
  final int placesApresMidi;
  final ValueChanged<PeriodeType>? onChanged;

  const _ChoixPeriode({
    required this.periode,
    required this.placesMatin,
    required this.placesApresMidi,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget option(PeriodeType p, IconData icone, int places) {
      final actif = periode == p;
      return Expanded(
        child: Material(
          color: actif ? AppColors.rouge : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onChanged == null || actif ? null : () => onChanged!(p),
            child: SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icone,
                      size: 16,
                      color: actif ? Colors.white : AppColors.grisDark),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${_periodeLabel(p)} · '
                      '${places == 0 ? 'complet' : '$places libre${places > 1 ? 's' : ''}'}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: actif ? Colors.white : AppColors.grisDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Row(
        children: [
          option(PeriodeType.am, Icons.wb_sunny_outlined, placesMatin),
          const SizedBox(width: 3),
          option(PeriodeType.pm, Icons.wb_twilight_rounded, placesApresMidi),
        ],
      ),
    );
  }
}

class _LienTexte extends StatelessWidget {
  final String libelle;
  final VoidCallback? onTap;

  const _LienTexte({required this.libelle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.rouge,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: Text(libelle),
    );
  }
}

/// Recherche d'appartement : numéro (« 12 » trouve 112, 1204…) ou taille
/// (« 3 1/2 », « 3½ » ou simplement « 3 »).
bool _correspond(Appartement a, String recherche) {
  final q = recherche.trim().toLowerCase().replaceAll('½', ' 1/2');
  if (q.isEmpty) return true;
  return a.numero.toLowerCase().contains(q) ||
      a.taille
          .toLowerCase()
          .replaceAll(' ', '')
          .contains(q.replaceAll(' ', ''));
}

class _ChampRechercheAppartement extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final bool dense;

  const _ChampRechercheAppartement({
    required this.controller,
    required this.onChanged,
    this.autofocus = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final bord = OutlineInputBorder(
      borderRadius: BorderRadius.circular(dense ? 8 : 10),
      borderSide: const BorderSide(color: AppColors.grisMedium),
    );
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      style: TextStyle(fontSize: dense ? 12.5 : 13.5),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        hintText: dense ? 'N° ou taille' : 'Rechercher par numéro ou taille',
        hintStyle:
            TextStyle(fontSize: dense ? 12 : 13, color: AppColors.grisText),
        prefixIcon: Icon(Icons.search_rounded, size: dense ? 16 : 18),
        prefixIconConstraints: BoxConstraints(minWidth: dense ? 30 : 40),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Effacer',
                visualDensity: VisualDensity.compact,
                iconSize: dense ? 15 : 18,
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 10, vertical: dense ? 9 : 12),
        border: bord,
        enabledBorder: bord,
        focusedBorder: bord.copyWith(
          borderSide: const BorderSide(color: AppColors.rouge, width: 1.4),
        ),
      ),
    );
  }
}

class _LigneAppartement extends StatelessWidget {
  final Appartement appartement;
  final bool selectionne;

  /// Plus de place libre dans la période (ou ajout en cours).
  final bool desactive;
  final VoidCallback onTap;

  const _LigneAppartement({
    required this.appartement,
    required this.selectionne,
    required this.desactive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = appartement;
    final couleur = _tailleColor(a.taille);
    return Opacity(
      opacity: desactive && !selectionne ? 0.45 : 1,
      child: Material(
        color: selectionne
            ? AppColors.rouge.withValues(alpha: 0.07)
            : Colors.transparent,
        child: InkWell(
          onTap: desactive ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: couleur, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Apt. ${a.numero}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.noir,
                    ),
                  ),
                ),
                Text(
                  '${a.taille}  ·  ${a.minutesBase} min',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.grisText),
                ),
                const SizedBox(width: 10),
                Icon(
                  selectionne
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: selectionne ? AppColors.rouge : AppColors.grisText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  final IconData icone;
  final String libelle;

  const _Pastille({required this.icone, required this.libelle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: AppColors.grisDark),
          const SizedBox(width: 5),
          Text(
            libelle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.grisDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErreurInline extends StatelessWidget {
  final String message;
  const _ErreurInline(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.refus.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.refus.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 15, color: AppColors.refus),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.refus),
            ),
          ),
        ],
      ),
    );
  }
}
