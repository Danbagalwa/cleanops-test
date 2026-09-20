import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../domain/reception_models.dart';
import '../providers/reception_residents_provider.dart';
import '../reception_sections.dart';
import '../widgets/reception_actions.dart';

const _kPageSize = 10;

/// Section « Résidents » de la vue Réception : le tableau des résidents et de
/// leur appartement. Les actions partent de chaque ligne : voir la fiche,
/// imprimer le calendrier, envoyer un message. Lecture seule.
class ReceptionResidentsScreen extends ConsumerStatefulWidget {
  const ReceptionResidentsScreen({super.key});

  @override
  ConsumerState<ReceptionResidentsScreen> createState() =>
      _ReceptionResidentsScreenState();
}

class _ReceptionResidentsScreenState
    extends ConsumerState<ReceptionResidentsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
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

  List<ResidentLigne> _filtered(List<ResidentLigne> all) {
    if (_searchQuery.isEmpty) return all;
    return all
        .where((r) =>
            r.nomComplet.toLowerCase().contains(_searchQuery) ||
            r.numero.toLowerCase().contains(_searchQuery))
        .toList();
  }

  void _ouvrirFiche(ResidentLigne r) =>
      context.go(receptionFicheRoute(r.appartementId));

  @override
  Widget build(BuildContext context) {
    final liste = ref.watch(receptionResidentsListeProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final total = liste.valueOrNull?.length;

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Résidents${total == null || total == 0 ? '' : '  ($total)'}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 1100 : double.infinity,
          ),
          child: Column(
            children: [
              _SearchBar(controller: _searchCtrl, hasText: _searchQuery.isNotEmpty),
              if (liste.isLoading && liste.hasValue)
                const LinearProgressIndicator(
                  color: AppColors.rouge,
                  backgroundColor: Colors.transparent,
                  minHeight: 2,
                ),
              Expanded(child: _corps(liste, isDesktop)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _corps(AsyncValue<List<ResidentLigne>> liste, bool isDesktop) {
    return liste.when(
      loading: () => const AppSkeletonList(),
      error: (erreur, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: AppErrorNotice(
            error: erreur.toString(),
            onRetry: () => ref.invalidate(receptionResidentsListeProvider),
          ),
        ),
      ),
      data: (tous) {
        if (tous.isEmpty) return const _EmptyState();

        final filtered = _filtered(tous);
        if (filtered.isEmpty) {
          return _EmptySearch(onClear: _searchCtrl.clear);
        }

        final totalPages = (filtered.length / _kPageSize).ceil().clamp(1, 9999);
        final safePage = _page.clamp(0, totalPages - 1);
        final paginated =
            filtered.skip(safePage * _kPageSize).take(_kPageSize).toList();

        final paginationBar = totalPages > 1
            ? _PaginationBar(
                currentPage: safePage,
                totalPages: totalPages,
                totalItems: filtered.length,
                pageSize: _kPageSize,
                onPageChanged: (p) => setState(() => _page = p),
              )
            : null;

        Widget ligne(int i) {
          final r = paginated[i];
          return _ResidentRow(
            key: ValueKey('${r.residentId}-${r.appartementId}'),
            ligne: r,
            isAlternate: i.isOdd,
            onFiche: () => _ouvrirFiche(r),
            onImprimer: () => imprimerCalendrierDeLigne(context, ref, r),
            onMessage: () => ouvrirMessage(context, r),
          );
        }

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
                            color: AppColors.grisMedium),
                        Expanded(
                          child: RefreshIndicator(
                            color: AppColors.rouge,
                            onRefresh: () async =>
                                ref.invalidate(receptionResidentsListeProvider),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: paginated.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: AppColors.grisMedium),
                              itemBuilder: (_, i) => ligne(i),
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
                onRefresh: () async =>
                    ref.invalidate(receptionResidentsListeProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
                  itemCount: paginated.length,
                  itemBuilder: (_, i) => ligne(i),
                ),
              ),
            ),
            if (paginationBar != null) paginationBar,
          ],
        );
      },
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
          Expanded(child: Text('ÉTAGE', style: labelStyle)),
          SizedBox(width: 108, child: Text('ACTIONS', style: labelStyle)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// BARRE DE RECHERCHE
// ══════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;

  const _SearchBar({required this.controller, required this.hasText});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final field = TextField(
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
                tooltip: 'Effacer',
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

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: isDesktop
          ? Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 280, child: field),
            )
          : field,
    );
  }
}

// ══════════════════════════════════════════════════════════
// LIGNE DU TABLEAU (desktop) / CARTE (mobile)
// ══════════════════════════════════════════════════════════

class _ResidentRow extends StatelessWidget {
  final ResidentLigne ligne;
  final bool isAlternate;
  final VoidCallback onFiche;
  final VoidCallback onImprimer;
  final VoidCallback onMessage;

  const _ResidentRow({
    super.key,
    required this.ligne,
    required this.isAlternate,
    required this.onFiche,
    required this.onImprimer,
    required this.onMessage,
  });

  List<Widget> get _actions => [
        _IconBtn(
          icon: Icons.visibility_outlined,
          color: AppColors.rouge,
          tooltip: 'Voir la fiche',
          onTap: onFiche,
        ),
        _IconBtn(
          icon: Icons.print_outlined,
          color: AppColors.grisDark,
          tooltip: 'Imprimer le calendrier',
          onTap: onImprimer,
        ),
        _IconBtn(
          icon: Icons.mail_outline_rounded,
          color: AppColors.aVerifier,
          tooltip: 'Envoyer un message',
          onTap: onMessage,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return isDesktop ? _buildRow() : _buildCard();
  }

  Widget _buildRow() {
    return Material(
      color: isAlternate
          ? AppColors.grisLight.withValues(alpha: 0.4)
          : Colors.white,
      child: InkWell(
        onTap: onFiche,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 9,
          ),
          child: Row(
            children: [
              _AvatarCircle(initiales: ligne.initiales, size: 30, fontSize: 11),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                flex: 2,
                child: Text(
                  ligne.nomComplet,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.noir,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Text(
                  'Apt ${ligne.numero}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.grisText,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  ligne.etage == null ? '—' : 'Étage ${ligne.etage}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.grisText,
                  ),
                ),
              ),
              SizedBox(
                width: 108,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _actions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: onFiche,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              _AvatarCircle(initiales: ligne.initiales, size: 42, fontSize: 14),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ligne.nomComplet,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.noir,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ligne.etage == null
                          ? 'Apt ${ligne.numero}'
                          : 'Apt ${ligne.numero} · Étage ${ligne.etage}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grisText,
                      ),
                    ),
                  ],
                ),
              ),
              ..._actions,
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String initiales;
  final double size;
  final double fontSize;

  const _AvatarCircle({
    required this.initiales,
    required this.size,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initiales,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: AppColors.rouge,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
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
  const _EmptyState();

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
            'Aucun résident actif à afficher.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisDark, height: 1.5),
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
            'Aucun résident ne correspond\nà votre recherche.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisDark, height: 1.5),
          ),
          const SizedBox(height: AppSizes.lg),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded),
            label: const Text('Effacer la recherche'),
          ),
        ],
      ),
    );
  }
}
