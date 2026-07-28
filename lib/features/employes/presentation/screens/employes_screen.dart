import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../domain/usecases/add_employe.dart';
import '../../domain/usecases/update_employe.dart';
import '../providers/employes_provider.dart';
import '../widgets/employe_form_widget.dart';
import '../widgets/employe_list_item.dart';

const _kPageSize = 12;
const _kRolesFiltres = [
  RoleType.employe,
  RoleType.superviseurMenage,
  RoleType.reception,
  RoleType.direction,
];

class EmployesScreen extends ConsumerStatefulWidget {
  const EmployesScreen({super.key});

  @override
  ConsumerState<EmployesScreen> createState() => _EmployesScreenState();
}

class _EmployesScreenState extends ConsumerState<EmployesScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  RoleType? _filterRole;
  bool? _filterActif; // null = tous, true = actifs, false = inactifs
  int _page = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(employesNotifierProvider.notifier).charger(),
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

  List<Employee> _filtered(List<Employee> all) {
    return all.where((e) {
      final matchSearch = _searchQuery.isEmpty ||
          e.nomComplet.toLowerCase().contains(_searchQuery) ||
          (e.numeroPointeuse?.contains(_searchQuery) ?? false);
      final matchRole = _filterRole == null || e.role == _filterRole;
      final matchActif = _filterActif == null || e.isActif == _filterActif;
      return matchSearch && matchRole && matchActif;
    }).toList();
  }

  void _ouvrirFormulaire({Employee? employe}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormDialog(employe: employe),
    );
  }

  void _confirmerToggle(Employee emp) {
    final desactiver = emp.isActif;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        title: Text(
            desactiver ? 'Désactiver l\'employé ?' : 'Activer l\'employé ?'),
        content: Text(
          desactiver
              ? '${emp.nomComplet} ne sera plus affiché dans le planning.'
              : '${emp.nomComplet} sera à nouveau disponible dans le planning.',
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
              await ref
                  .read(employesNotifierProvider.notifier)
                  .toggleActif(emp.id, isActif: !emp.isActif);
            },
            style: FilledButton.styleFrom(
              backgroundColor:
                  desactiver ? AppColors.refus : AppColors.jourVert,
            ),
            child: Text(desactiver ? 'Désactiver' : 'Activer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employesNotifierProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final filtered = _filtered(state.employes);
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
          'Employés${state.total > 0 ? '  (${state.total})' : ''}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.md),
              child: FilledButton.icon(
                onPressed: () => _ouvrirFormulaire(),
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
              onPressed: () => _ouvrirFormulaire(),
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
                filterRole: _filterRole,
                filterActif: _filterActif,
                onRoleChanged: (r) => setState(() {
                  _filterRole = r;
                  _page = 0;
                }),
                onActifChanged: (a) => setState(() {
                  _filterActif = a;
                  _page = 0;
                }),
              ),
              if (state.isLoading && state.employes.isNotEmpty)
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
    required EmployesState state,
    required List<Employee> filtered,
    required List<Employee> paginated,
    required int totalPages,
    required int currentPage,
    required bool isDesktop,
  }) {
    if (state.isLoading && state.employes.isEmpty) {
      return const AppSkeletonList();
    }

    if (state.error != null && state.employes.isEmpty) {
      return _ErrorState(
        message: state.error!,
        onRetry: () => ref.read(employesNotifierProvider.notifier).charger(),
      );
    }

    if (state.employes.isEmpty) {
      return _EmptyState(onAdd: () => _ouvrirFormulaire());
    }

    if (filtered.isEmpty) {
      return _EmptySearch(
        onClear: () {
          _searchCtrl.clear();
          setState(() {
            _filterRole = null;
            _filterActif = null;
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
                            .read(employesNotifierProvider.notifier)
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
                            final emp = paginated[i];
                            return EmployeListItem(
                              employe: emp,
                              onEdit: () => _ouvrirFormulaire(employe: emp),
                              onToggleActif: () => _confirmerToggle(emp),
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
                ref.read(employesNotifierProvider.notifier).charger(),
            child: ListView.builder(
              padding: const EdgeInsets.only(
                top: AppSizes.sm,
                bottom: AppSizes.md,
              ),
              itemCount: paginated.length,
              itemBuilder: (context, i) {
                final emp = paginated[i];
                return EmployeListItem(
                  employe: emp,
                  onEdit: () => _ouvrirFormulaire(employe: emp),
                  onToggleActif: () => _confirmerToggle(emp),
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
          SizedBox(width: 32 + AppSizes.sm), // aligné sur l'avatar
          Expanded(flex: 3, child: Text('NOM', style: labelStyle)),
          Expanded(flex: 2, child: Text('RÔLE', style: labelStyle)),
          Expanded(child: Text('POINTEUSE', style: labelStyle)),
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
  final RoleType? filterRole;
  final bool? filterActif;
  final ValueChanged<RoleType?> onRoleChanged;
  final ValueChanged<bool?> onActifChanged;

  const _SearchFilterBar({
    required this.controller,
    required this.hasText,
    required this.filterRole,
    required this.filterActif,
    required this.onRoleChanged,
    required this.onActifChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.sm,
        AppSizes.md,
        AppSizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom...',
              hintStyle: const TextStyle(fontSize: 14),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.grisText,
              ),
              suffixIcon: hasText
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
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
                borderSide:
                    const BorderSide(color: AppColors.rouge, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filtre statut
                _Chip(
                  label: 'Tous',
                  selected: filterActif == null,
                  onTap: () => onActifChanged(null),
                ),
                _Chip(
                  label: 'Actifs',
                  selected: filterActif == true,
                  color: AppColors.jourVert,
                  onTap: () =>
                      onActifChanged(filterActif == true ? null : true),
                ),
                _Chip(
                  label: 'Inactifs',
                  selected: filterActif == false,
                  color: AppColors.grisDark,
                  onTap: () =>
                      onActifChanged(filterActif == false ? null : false),
                ),

                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 20,
                  color: AppColors.grisMedium,
                ),
                const SizedBox(width: 8),

                // Filtre rôle
                ..._kRolesFiltres.map((r) => _Chip(
                      label: roleDisplay(r),
                      selected: filterRole == r,
                      color: roleColor(r),
                      onTap: () => onRoleChanged(filterRole == r ? null : r),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.rouge;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? c.withValues(alpha: 0.1) : AppColors.grisLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? c : AppColors.grisMedium,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? c : AppColors.grisDark,
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
            duration: const Duration(milliseconds: 160),
            width: 30,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: active ? AppColors.rouge : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 13,
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
          top: BorderSide(color: AppColors.grisMedium),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
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
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                color: AppColors.grisDark,
              ),
              ..._buildPageNumbers(),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: currentPage < totalPages - 1
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                iconSize: 20,
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
  final Employee? employe;
  const _FormDialog({this.employe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      employesNotifierProvider.select((s) => s.isLoading),
    );

    return EmployeFormWidget(
      employe: employe,
      isLoading: isLoading,
      onSave: ({
        required String nom,
        required String prenom,
        required RoleType role,
        String? numeroPointeuse,
        String? motDePasse,
        required bool isActif,
      }) async {
        final notifier = ref.read(employesNotifierProvider.notifier);
        final bool ok;

        if (employe == null) {
          ok = await notifier.ajouter(AddEmployeParams(
            nom: nom,
            prenom: prenom,
            role: role,
            numeroPointeuse: numeroPointeuse,
            motDePasse: motDePasse,
          ));
        } else {
          ok = await notifier.modifier(UpdateEmployeParams(
            id: employe!.id,
            nom: nom,
            prenom: prenom,
            role: role,
            isActif: isActif,
            numeroPointeuse: numeroPointeuse,
            motDePasse: motDePasse,
          ));
        }

        if (ok && context.mounted) Navigator.of(context).pop();
        if (!ok && context.mounted) {
          final error = ref.read(employesNotifierProvider).error;
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
              Icons.group_rounded,
              size: 56,
              color: AppColors.rouge,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          const Text(
            'Aucun employé',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.noir,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          const Text(
            'Ajoutez votre premier employé\npour commencer la configuration.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisDark, height: 1.5),
          ),
          const SizedBox(height: AppSizes.xl),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Ajouter un employé'),
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
          const Icon(Icons.search_off_rounded,
              size: 48, color: AppColors.grisDark),
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
            'Aucun employé ne correspond\nà votre recherche ou filtre.',
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
