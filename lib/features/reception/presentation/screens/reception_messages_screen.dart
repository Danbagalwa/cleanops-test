import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../domain/reception_messages_models.dart';
import '../providers/reception_messages_provider.dart';

const _kPageSize = 10;

enum _Filtre { tous, enAttente, repondus, resolus }

/// Section « Messages transmis » de la vue Réception : la liste, en LECTURE
/// SEULE, des messages envoyés à l'administration, avec leur statut (En attente,
/// Répondue, Résolue) et la réponse éventuelle. La Réception ne modifie rien ici.
class ReceptionMessagesScreen extends ConsumerStatefulWidget {
  const ReceptionMessagesScreen({super.key});

  @override
  ConsumerState<ReceptionMessagesScreen> createState() =>
      _ReceptionMessagesScreenState();
}

class _ReceptionMessagesScreenState
    extends ConsumerState<ReceptionMessagesScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  _Filtre _filtre = _Filtre.tous;
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

  List<MessageTransmis> _filtered(List<MessageTransmis> all) {
    return all.where((m) {
      final matchSearch = _searchQuery.isEmpty ||
          m.numero.toLowerCase().contains(_searchQuery) ||
          m.message.toLowerCase().contains(_searchQuery);
      final matchFiltre = switch (_filtre) {
        _Filtre.tous => true,
        _Filtre.enAttente => m.statut == StatutMessage.enAttente,
        _Filtre.repondus => m.statut == StatutMessage.repondue,
        _Filtre.resolus => m.statut == StatutMessage.resolue,
      };
      return matchSearch && matchFiltre;
    }).toList();
  }

  void _reinitialiser() {
    _searchCtrl.clear();
    setState(() {
      _filtre = _Filtre.tous;
      _page = 0;
    });
  }

  void _ouvrir(MessageTransmis message) {
    showDialog<void>(
      context: context,
      builder: (_) => _DetailDialog(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liste = ref.watch(receptionMessagesProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final total = liste.valueOrNull?.length;

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Messages transmis${total == null || total == 0 ? '' : '  ($total)'}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(receptionMessagesProvider),
          ),
          const SizedBox(width: 4),
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

  Widget _corps(AsyncValue<List<MessageTransmis>> liste, bool isDesktop) {
    return liste.when(
      loading: () => const AppSkeletonList(),
      error: (erreur, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: AppErrorNotice(
            error: erreur.toString(),
            onRetry: () => ref.invalidate(receptionMessagesProvider),
          ),
        ),
      ),
      data: (tous) {
        if (tous.isEmpty) return const _EmptyState();

        final filtered = _filtered(tous);
        if (filtered.isEmpty) return _EmptySearch(onClear: _reinitialiser);

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
          final m = paginated[i];
          return _MessageRow(
            key: ValueKey(m.id),
            message: m,
            isAlternate: i.isOdd,
            onOuvrir: () => _ouvrir(m),
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
                                ref.invalidate(receptionMessagesProvider),
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
                onRefresh: () async => ref.invalidate(receptionMessagesProvider),
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
          Expanded(child: Text('APPARTEMENT', style: labelStyle)),
          Expanded(flex: 2, child: Text('NATURE', style: labelStyle)),
          Expanded(flex: 4, child: Text('MESSAGE', style: labelStyle)),
          Expanded(flex: 2, child: Text('ENVOYÉ', style: labelStyle)),
          Expanded(flex: 2, child: Text('STATUT', style: labelStyle)),
          SizedBox(width: 56, child: Text('ACTIONS', style: labelStyle)),
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
  final _Filtre filtre;
  final bool isDesktop;
  final ValueChanged<_Filtre> onFiltreChanged;

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
        hintText: 'Appartement ou texte du message...',
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
  }

  Widget _buildChips() {
    const chips = [
      (_Filtre.tous, 'Tous'),
      (_Filtre.enAttente, 'En attente'),
      (_Filtre.repondus, 'Répondus'),
      (_Filtre.resolus, 'Résolus'),
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
                SizedBox(width: 320, child: _buildSearchField()),
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
// LIGNE DU TABLEAU (desktop) / CARTE (mobile)
// ══════════════════════════════════════════════════════════

class _MessageRow extends StatelessWidget {
  final MessageTransmis message;
  final bool isAlternate;
  final VoidCallback onOuvrir;

  const _MessageRow({
    super.key,
    required this.message,
    required this.isAlternate,
    required this.onOuvrir,
  });

  Widget _action() => _IconBtn(
        icon: Icons.visibility_outlined,
        color: AppColors.rouge,
        tooltip: 'Voir le message',
        onTap: onOuvrir,
      );

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
        onTap: onOuvrir,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 9,
          ),
          child: Row(
            children: [
              const _IconeCercle(size: 30),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  'Apt ${message.numero}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.noir,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  message.nature.libelle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.grisText,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  message.message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.grisDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  message.envoyeLe,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.grisText,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatutBadge(statut: message.statut),
                ),
              ),
              SizedBox(
                width: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [_action()],
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
        onTap: onOuvrir,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              const _IconeCercle(size: 42),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Apt ${message.numero} · ${message.nature.libelle}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.noir,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message.message,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.grisDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatutBadge(statut: message.statut),
                        Text(
                          message.envoyeLe,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.grisText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _action(),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconeCercle extends StatelessWidget {
  final double size;

  const _IconeCercle({required this.size});

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
      child: Icon(Icons.forward_to_inbox_rounded,
          size: size * 0.5, color: AppColors.rouge),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final StatutMessage statut;

  const _StatutBadge({required this.statut});

  Color get _color => switch (statut) {
        StatutMessage.enAttente => AppColors.aVerifier,
        StatutMessage.repondue => AppColors.rouge,
        StatutMessage.resolue => AppColors.fait,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Text(
        statut.libelle,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color,
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
// DÉTAIL D'UN MESSAGE (lecture seule)
// ══════════════════════════════════════════════════════════

class _DetailDialog extends StatelessWidget {
  final MessageTransmis message;

  const _DetailDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    final m = message;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(AppSizes.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Message · Apt ${m.numero}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatutBadge(statut: m.statut),
                    Text(
                      'Envoyé le ${m.envoyeLe}'
                      '${m.auteurPrenom.isEmpty ? '' : ' par ${m.auteurPrenom}'}',
                      style: const TextStyle(color: AppColors.grisDark),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  m.signification,
                  style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  'Nature : ${m.nature.libelle}',
                  style: const TextStyle(color: AppColors.grisDark),
                ),
                const SizedBox(height: AppSizes.md),
                _Bloc(
                  titre: 'Votre message',
                  texte: m.message,
                ),
                if (m.transmisEmploye) ...[
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    m.employePrenom == null
                        ? "Transmis aussi à l'employé."
                        : "Transmis aussi à l'employé : ${m.employePrenom}.",
                    style: const TextStyle(color: AppColors.grisDark),
                  ),
                ],
                const SizedBox(height: AppSizes.md),
                if (m.reponse != null && m.reponse!.trim().isNotEmpty)
                  _Bloc(
                    titre: 'Réponse'
                        '${m.dateReponse == null ? '' : ' · ${MessageTransmis.formater(m.dateReponse!)}'}',
                    texte: m.reponse!,
                  ),
                if (m.statut == StatutMessage.resolue &&
                    m.dateResolution != null) ...[
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    'Résolue le ${MessageTransmis.formater(m.dateResolution!)}.',
                    style: const TextStyle(
                        color: AppColors.fait, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bloc extends StatelessWidget {
  final String titre;
  final String texte;

  const _Bloc({required this.titre, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSizes.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.sm + 4),
          decoration: BoxDecoration(
            color: AppColors.grisLight,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
          ),
          child: SelectableText(texte,
              style: const TextStyle(fontSize: 13.5, height: 1.4)),
        ),
      ],
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
              Icons.forward_to_inbox_outlined,
              size: 56,
              color: AppColors.rouge,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          const Text(
            'Aucun message transmis',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.noir,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Text(
              "Les messages envoyés à l'administration depuis la fiche d'un\n"
              'appartement apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grisDark, height: 1.5),
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
            'Aucun message ne correspond\nà votre recherche ou filtre.',
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
