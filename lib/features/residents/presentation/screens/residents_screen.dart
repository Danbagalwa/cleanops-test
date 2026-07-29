import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/export_menu_button.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pdf/domain/usecases/generate_residents_export.dart';
import '../../../pdf/presentation/screens/residents_pdf_preview_screen.dart';
import '../../domain/entities/resident.dart';
import '../providers/resident_provider.dart';
import '../widgets/creer_resident_dialog.dart';
import '../widgets/desactivation_dialog.dart';
import '../widgets/pin_attribution_dialog.dart';
import '../widgets/resident_list_item.dart';

const _kPageSize = 10;

enum _FiltreStatut { tous, actifs, inscrits, sansApp, inactifs }

class ResidentsScreen extends ConsumerStatefulWidget {
  const ResidentsScreen({super.key});

  @override
  ConsumerState<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends ConsumerState<ResidentsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  _FiltreStatut _filtre = _FiltreStatut.tous;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase().trim();
        _page = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Resident> _filtered(List<Resident> all) {
    return all.where((r) {
      final matchSearch = _searchQuery.isEmpty ||
          r.nomComplet.toLowerCase().contains(_searchQuery) ||
          (r.numeroAppartement?.toLowerCase().contains(_searchQuery) ?? false);
      final matchFiltre = switch (_filtre) {
        _FiltreStatut.tous => true,
        _FiltreStatut.actifs => r.isActif,
        _FiltreStatut.inscrits => r.isActif && r.aApplication,
        _FiltreStatut.sansApp => r.isActif && !r.aApplication,
        _FiltreStatut.inactifs => !r.isActif,
      };
      return matchSearch && matchFiltre;
    }).toList();
  }

  String _filterDescription() {
    final filters = <String>[];
    if (_searchQuery.isNotEmpty) {
      filters.add('Recherche : "${_searchCtrl.text.trim()}"');
    }
    final status = switch (_filtre) {
      _FiltreStatut.tous => null,
      _FiltreStatut.actifs => 'Actifs',
      _FiltreStatut.inscrits => 'Inscrits',
      _FiltreStatut.sansApp => 'Sans application',
      _FiltreStatut.inactifs => 'Inactifs',
    };
    if (status != null) filters.add('Statut : $status');
    return filters.isEmpty ? 'Tous les résidents' : filters.join(' · ');
  }

  // ── Actions ────────────────────────────────────────────────

  Future<void> _ouvrirCreation() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreerResidentDialog(
        onConfirmer: ({
          required String aptId,
          required String nom,
          required String prenom,
          required bool aApplication,
          required String pin,
        }) =>
            ref
                .read(residentNotifierProvider.notifier)
                .creerResidentAvecPin(aptId, nom, prenom, aApplication, pin),
      ),
    );
  }

  void _ouvrirPin(Resident resident) {
    showDialog<bool>(
      context: context,
      builder: (_) => PinAttributionDialog(
        nomComplet: resident.nomComplet,
        onConfirmer: (pin) => ref
            .read(residentNotifierProvider.notifier)
            .attribuerPin(resident.id, pin),
      ),
    );
  }

  void _confirmerDesactivation(Resident resident) {
    showDialog<bool>(
      context: context,
      builder: (_) => DesactivationDialog(
        nomComplet: resident.nomComplet,
        onConfirmer: () => ref
            .read(residentNotifierProvider.notifier)
            .desactiverResident(resident.id),
      ),
    );
  }

  void _activer(Resident resident) {
    ref.read(residentNotifierProvider.notifier).activerResident(resident.id);
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(residentNotifierProvider);
    final currentEmployee = ref.watch(employeeCourantProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final filtered = _filtered(state.residents);
    final filterDescription = _filterDescription();
    final totalPages = (filtered.length / _kPageSize).ceil().clamp(1, 9999);
    final safePage = _page.clamp(0, totalPages - 1);
    final paginated =
        filtered.skip(safePage * _kPageSize).take(_kPageSize).toList();

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.backOrHome(AppRoutes.employerDashboard),
        ),
        title: Text(
          'Résidents${state.residents.isNotEmpty ? '  (${state.totalActifs})' : ''}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          AppExportMenuButton(
            enabled: filtered.isNotEmpty && !state.isLoading,
            onPdf: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ResidentsPdfPreviewScreen(
                  residents: filtered,
                  filterDescription: filterDescription,
                  generatedBy: currentEmployee?.nomComplet ?? 'CleanOps',
                ),
              ),
            ),
            onExcel: () {
              try {
                const GenerateResidentsExcel()(
                  residents: filtered,
                  filterDescription: filterDescription,
                );
                showExportSuccess(
                  context,
                  'La liste Excel des résidents a été téléchargée.',
                );
              } catch (error) {
                AppFeedback.showError(context, error);
              }
            },
          ),
          const SizedBox(width: 8),
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.md),
              child: FilledButton.icon(
                onPressed: _ouvrirCreation,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Ajouter'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.rouge,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton(
              onPressed: _ouvrirCreation,
              backgroundColor: AppColors.rouge,
              child: const Icon(Icons.person_add_rounded, color: Colors.white),
            ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 1100 : double.infinity,
          ),
          child: Column(
            children: [
              _SearchFilterBar(
                controller: _searchCtrl,
                hasText: _searchQuery.isNotEmpty,
                filtre: _filtre,
                isDesktop: isDesktop,
                onFiltreChanged: (f) => setState(() {
                  _filtre = f;
                  _page = 0;
                }),
              ),

              if (state.isLoading && state.residents.isNotEmpty)
                const LinearProgressIndicator(
                  color: AppColors.rouge,
                  backgroundColor: Colors.transparent,
                  minHeight: 2,
                ),

              Expanded(
                child: _buildBody(
                  state: state,
                  filtered: filtered,
                  paginated: paginated,
                  totalPages: totalPages,
                  currentPage: safePage,
                  isDesktop: isDesktop,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required ResidentState state,
    required List<Resident> filtered,
    required List<Resident> paginated,
    required int totalPages,
    required int currentPage,
    required bool isDesktop,
  }) {
    if (state.isLoading && state.residents.isEmpty) {
      return const AppSkeletonList();
    }

    if (state.error != null && state.residents.isEmpty) {
      return _ErrorState(
        message: state.error!,
        onRetry: () =>
            ref.read(residentNotifierProvider.notifier).loadResidents(),
      );
    }

    if (state.residents.isEmpty) {
      return _EmptyState(onAdd: _ouvrirCreation);
    }

    if (filtered.isEmpty) {
      return _EmptySearch(
        onClear: () {
          _searchCtrl.clear();
          setState(() {
            _filtre = _FiltreStatut.tous;
            _page = 0;
          });
        },
      );
    }

    final paginationBar = totalPages > 1
        ? _PaginationBar(
            currentPage: currentPage,
            totalPages: totalPages,
            totalItems: filtered.length,
            pageSize: _kPageSize,
            onPageChanged: (p) => setState(() => _page = p),
          )
        : null;

    if (isDesktop) {
      return Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.grisMedium),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    const _ColumnHeader(),
                    const Divider(
                        height: 1, thickness: 1, color: AppColors.grisMedium),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.rouge,
                        onRefresh: () => ref
                            .read(residentNotifierProvider.notifier)
                            .loadResidents(),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: paginated.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              thickness: 1,
                              color: AppColors.grisMedium),
                          itemBuilder: (context, i) {
                            final r = paginated[i];
                            return ResidentListItem(
                              key: ValueKey(r.id),
                              resident: r,
                              isAlternate: i.isOdd,
                              onPin: () => _ouvrirPin(r),
                              onDesactiver: () => _confirmerDesactivation(r),
                              onActiver: () => _activer(r),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (paginationBar != null) paginationBar,
        ],
      );
    }

    // Mobile
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.rouge,
            onRefresh: () =>
                ref.read(residentNotifierProvider.notifier).loadResidents(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
              itemCount: paginated.length,
              separatorBuilder: (_, __) => const SizedBox.shrink(),
              itemBuilder: (context, i) {
                final r = paginated[i];
                return ResidentListItem(
                  key: ValueKey(r.id),
                  resident: r,
                  isAlternate: i.isOdd,
                  onPin: () => _ouvrirPin(r),
                  onDesactiver: () => _confirmerDesactivation(r),
                  onActiver: () => _activer(r),
                );
              },
            ),
          ),
        ),
        if (paginationBar != null) paginationBar,
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// EN-TÊTE DE COLONNES (desktop)
// ══════════════════════════════════════════════════════════

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.grisText,
      letterSpacing: 0.2,
    );

    return Container(
      color: AppColors.grisLight,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 8),
      child: const Row(
        children: [
          SizedBox(width: 30 + AppSizes.sm),
          Expanded(flex: 2, child: Text('NOM', style: labelStyle)),
          Expanded(child: Text('APPARTEMENT', style: labelStyle)),
          Expanded(child: Text('STATUT', style: labelStyle)),
          SizedBox(width: 56, child: Text('PIN', style: labelStyle)),
          SizedBox(width: 80, child: Text('ACTIONS', style: labelStyle)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// BARRE RECHERCHE + FILTRES
// ══════════════════════════════════════════════════════════

class _SearchFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final _FiltreStatut filtre;
  final bool isDesktop;
  final ValueChanged<_FiltreStatut> onFiltreChanged;

  const _SearchFilterBar({
    required this.controller,
    required this.hasText,
    required this.filtre,
    required this.isDesktop,
    required this.onFiltreChanged,
  });

  Widget _buildSearchField() {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Nom, prénom ou appartement...',
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 18,
          color: AppColors.grisText,
        ),
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 16),
                onPressed: controller.clear,
                color: AppColors.grisText,
              )
            : null,
        filled: true,
        fillColor: AppColors.grisLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
          borderSide: const BorderSide(color: AppColors.rouge, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildChips() {
    const chips = [
      (_FiltreStatut.tous, 'Tous'),
      (_FiltreStatut.actifs, 'Actifs'),
      (_FiltreStatut.inscrits, 'Inscrits'),
      (_FiltreStatut.sansApp, 'Sans app'),
      (_FiltreStatut.inactifs, 'Inactifs'),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: chips
          .map((c) => _ChipFiltre(
                label: c.$2,
                selected: filtre == c.$1,
                onTap: () => onFiltreChanged(c.$1),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: isDesktop
          ? Row(
              children: [
                SizedBox(width: 280, child: _buildSearchField()),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildChips(),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchField(),
                const SizedBox(height: AppSizes.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildChips(),
                ),
              ],
            ),
    );
  }
}

class _ChipFiltre extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipFiltre({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.rouge.withValues(alpha: 0.1)
                : AppColors.grisLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.rouge : AppColors.grisMedium,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? AppColors.rouge : AppColors.grisDark,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// PAGINATION
// ══════════════════════════════════════════════════════════

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
  });

  List<Widget> _buildPageNumbers() {
    final buttons = <Widget>[];
    final start =
        (currentPage - 2).clamp(0, (totalPages - 5).clamp(0, totalPages));
    final end = (start + 5).clamp(0, totalPages);

    for (int i = start; i < end; i++) {
      final active = i == currentPage;
      buttons.add(
        GestureDetector(
          onTap: active ? null : () => onPageChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 28,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: active ? AppColors.rouge : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? Colors.white : AppColors.grisDark,
              ),
            ),
          ),
        ),
      );
    }
    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    final start = currentPage * pageSize + 1;
    final end = ((currentPage + 1) * pageSize).clamp(0, totalItems);
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.grisMedium, width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? AppSizes.sm : AppSizes.md,
        vertical: 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$start–$end sur $totalItems',
            style: const TextStyle(fontSize: 12, color: AppColors.grisText),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: currentPage > 0
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                tooltip: 'Précédent',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                color: AppColors.grisDark,
              ),
              if (isCompact)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    'Page ${currentPage + 1}/$totalPages',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grisDark,
                    ),
                  ),
                )
              else
                ..._buildPageNumbers(),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: currentPage < totalPages - 1
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                tooltip: 'Suivant',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                color: AppColors.grisDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// ÉTATS VISUELS
// ══════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.xl),
            decoration: BoxDecoration(
              color: AppColors.rouge.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 56,
              color: AppColors.rouge,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          const Text(
            'Aucun résident',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.noir,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          const Text(
            'Ajoutez votre premier résident\npour commencer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisDark, height: 1.5),
          ),
          const SizedBox(height: AppSizes.xl),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Ajouter un résident'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rouge,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.lg,
                vertical: AppSizes.md,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  final VoidCallback onClear;
  const _EmptySearch({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: AppColors.grisDark),
          const SizedBox(height: AppSizes.md),
          const Text(
            'Aucun résultat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.noir,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          const Text(
            'Aucun résident ne correspond\nà votre recherche ou filtre.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisDark, height: 1.5),
          ),
          const SizedBox(height: AppSizes.lg),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded),
            label: const Text('Effacer les filtres'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: AppErrorNotice(error: message, onRetry: onRetry),
      ),
    );
  }
}
