import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/export_menu_button.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pdf/domain/usecases/generate_appartements_export.dart';
import '../../../pdf/presentation/screens/appartements_pdf_preview_screen.dart';
import '../../domain/entities/appartement.dart';
import '../providers/appartements_provider.dart';
import '../widgets/appartement_form_widget.dart';
import '../widgets/appartement_list_item.dart';

const _kPageSize = 10;
const _kTailles = ['2 1/2', '3 1/2', '4 1/2', '5 1/2'];

class AppartementsScreen extends ConsumerStatefulWidget {
  const AppartementsScreen({super.key});

  @override
  ConsumerState<AppartementsScreen> createState() => _AppartementsScreenState();
}

class _AppartementsScreenState extends ConsumerState<AppartementsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _filterTaille;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(appartementsNotifierProvider.notifier).charger(),
    );
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

  List<Appartement> _filtered(List<Appartement> all) {
    return all.where((a) {
      final matchSearch =
          _searchQuery.isEmpty || a.numero.toLowerCase().contains(_searchQuery);
      final matchTaille = _filterTaille == null || a.taille == _filterTaille;
      return matchSearch && matchTaille;
    }).toList();
  }

  String _filterDescription() {
    final filters = <String>[];
    if (_searchQuery.isNotEmpty) {
      filters.add('Recherche : "${_searchCtrl.text.trim()}"');
    }
    if (_filterTaille != null) {
      filters.add('Taille : $_filterTaille');
    }
    return filters.isEmpty ? 'Tous les appartements' : filters.join(' · ');
  }

  void _ouvrirFormulaire({Appartement? appartement}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormDialog(appartement: appartement),
    );
  }

  void _confirmerSuppression(Appartement appt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        title: const Text('Supprimer l\'appartement ?'),
        content: Text(
          'L\'appartement ${appt.numero} sera définitivement supprimé.',
          style: const TextStyle(color: AppColors.grisDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await ref
                  .read(appartementsNotifierProvider.notifier)
                  .supprimer(appt.id);
              if (!ok && mounted) _showError();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showError() {
    final error = ref.read(appartementsNotifierProvider).error;
    if (error == null) return;
    AppFeedback.showError(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appartementsNotifierProvider);
    final currentEmployee = ref.watch(employeeCourantProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final filtered = _filtered(state.appartements);
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
        title: Text(
          'Appartements${state.total > 0 ? '  (${state.total})' : ''}',
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
                builder: (_) => AppartementsPdfPreviewScreen(
                  appartements: filtered,
                  filterDescription: filterDescription,
                  generatedBy: currentEmployee?.nomComplet ?? 'CleanOps',
                ),
              ),
            ),
            onExcel: () {
              try {
                const GenerateAppartementsExcel()(
                  appartements: filtered,
                  filterDescription: filterDescription,
                );
                showExportSuccess(
                  context,
                  'La liste Excel des appartements a été téléchargée.',
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
                onPressed: () => _ouvrirFormulaire(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ajouter'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.rouge,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Ajouter un appartement',
                onPressed: () => _ouvrirFormulaire(),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.rouge,
                  backgroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 1100 : double.infinity,
          ),
          child: Column(
            children: [
              // Barre recherche + filtres (une seule ligne sur desktop)
              _SearchFilterBar(
                controller: _searchCtrl,
                hasText: _searchQuery.isNotEmpty,
                filterTaille: _filterTaille,
                isDesktop: isDesktop,
                onFilterChanged: (t) => setState(() {
                  _filterTaille = t;
                  _page = 0;
                }),
              ),

              // Barre de progression (refresh en arrière-plan)
              if (state.isLoading && state.appartements.isNotEmpty)
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
    required AppartementsState state,
    required List<Appartement> filtered,
    required List<Appartement> paginated,
    required int totalPages,
    required int currentPage,
    required bool isDesktop,
  }) {
    if (state.isLoading && state.appartements.isEmpty) {
      return const AppSkeletonList();
    }

    if (state.error != null && state.appartements.isEmpty) {
      return _ErrorState(
        message: state.error!,
        onRetry: () =>
            ref.read(appartementsNotifierProvider.notifier).charger(),
      );
    }

    if (state.appartements.isEmpty) {
      return _EmptyState(onAdd: () => _ouvrirFormulaire());
    }

    if (filtered.isEmpty) {
      return _EmptySearch(
        onClear: () {
          _searchCtrl.clear();
          setState(() {
            _filterTaille = null;
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
                      height: 1,
                      thickness: 1,
                      color: AppColors.grisMedium,
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.rouge,
                        onRefresh: () => ref
                            .read(appartementsNotifierProvider.notifier)
                            .charger(),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: paginated.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.grisMedium,
                          ),
                          itemBuilder: (context, i) {
                            final appt = paginated[i];
                            return AppartementListItem(
                              appartement: appt,
                              isAlternate: i.isOdd,
                              onEdit: () =>
                                  _ouvrirFormulaire(appartement: appt),
                              onDelete: () => _confirmerSuppression(appt),
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

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.rouge,
            onRefresh: () =>
                ref.read(appartementsNotifierProvider.notifier).charger(),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: paginated.length,
              separatorBuilder: (_, __) => const SizedBox.shrink(),
              itemBuilder: (context, i) {
                final appt = paginated[i];
                return AppartementListItem(
                  appartement: appt,
                  isAlternate: i.isOdd,
                  onEdit: () => _ouvrirFormulaire(appartement: appt),
                  onDelete: () => _confirmerSuppression(appt),
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

// ── En-tête de colonnes (desktop) ─────────────────────────
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: 8,
      ),
      child: const Row(
        children: [
          SizedBox(width: 42 + AppSizes.md), // aligné sur l'icône de la row
          Expanded(flex: 2, child: Text('NUMÉRO', style: labelStyle)),
          Expanded(child: Text('TAILLE', style: labelStyle)),
          Expanded(child: Text('DURÉE', style: labelStyle)),
          SizedBox(width: 96, child: Text('ACTIONS', style: labelStyle)),
        ],
      ),
    );
  }
}

// ── Barre recherche + filtres ─────────────────────────────
class _SearchFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final String? filterTaille;
  final bool isDesktop;
  final ValueChanged<String?> onFilterChanged;

  const _SearchFilterBar({
    required this.controller,
    required this.hasText,
    required this.filterTaille,
    required this.isDesktop,
    required this.onFilterChanged,
  });

  Widget _buildSearchField() {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Rechercher par numéro...',
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChipFiltre(
          label: 'Tous',
          selected: filterTaille == null,
          onTap: () => onFilterChanged(null),
        ),
        ..._kTailles.map((t) => _ChipFiltre(
              label: t,
              selected: filterTaille == t,
              onTap: () => onFilterChanged(filterTaille == t ? null : t),
            )),
      ],
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
          // ── Desktop : recherche + filtres sur une seule ligne ──
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
          // ── Mobile : empilé verticalement ──────────────────
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

// ── Pagination ────────────────────────────────────────────
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.grisMedium, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
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

// ── Dialog formulaire ─────────────────────────────────────
class _FormDialog extends ConsumerWidget {
  final Appartement? appartement;
  const _FormDialog({this.appartement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      appartementsNotifierProvider.select((s) => s.isLoading),
    );

    return AppartementFormWidget(
      appartement: appartement,
      isLoading: isLoading,
      onSave: (numero, taille, minutes) async {
        final notifier = ref.read(appartementsNotifierProvider.notifier);
        final bool ok;

        if (appartement == null) {
          ok = await notifier.ajouter(
            numero: numero,
            taille: taille,
            minutesBase: minutes,
          );
        } else {
          ok = await notifier.modifier(
            id: appartement!.id,
            numero: numero,
            taille: taille,
            minutesBase: minutes,
          );
        }

        if (ok && context.mounted) Navigator.of(context).pop();
        if (!ok && context.mounted) {
          final error = ref.read(appartementsNotifierProvider).error;
          if (error != null) {
            AppFeedback.showError(context, error);
          }
        }
      },
    );
  }
}

// ── États visuels ─────────────────────────────────────────

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
              Icons.apartment_rounded,
              size: 56,
              color: AppColors.rouge,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          const Text(
            'Aucun appartement',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.noir,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          const Text(
            'Ajoutez votre premier appartement\npour commencer la configuration.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisDark, height: 1.5),
          ),
          const SizedBox(height: AppSizes.xl),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter un appartement'),
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
          const Icon(
            Icons.search_off_rounded,
            size: 48,
            color: AppColors.grisDark,
          ),
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
            'Aucun appartement ne correspond\nà votre recherche ou filtre.',
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
