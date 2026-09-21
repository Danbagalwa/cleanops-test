import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/reception_pin_models.dart';
import '../../domain/reception_residents_repository.dart' show ReceptionErreur;
import '../providers/reception_pin_provider.dart';

const _kPageSize = 10;

enum _Filtre { tous, sansPin, avecPin }

/// Section « PIN » de la vue Réception : générer ou réinitialiser le PIN d'un
/// résident. Le PIN est généré par le serveur et affiché UNE seule fois ; la
/// Réception ne le choisit pas et ne peut pas le relire.
class ReceptionPinScreen extends ConsumerStatefulWidget {
  const ReceptionPinScreen({super.key});

  @override
  ConsumerState<ReceptionPinScreen> createState() => _ReceptionPinScreenState();
}

class _ReceptionPinScreenState extends ConsumerState<ReceptionPinScreen> {
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

  List<ResidentPin> _filtered(List<ResidentPin> all) {
    return all.where((r) {
      final matchSearch = _searchQuery.isEmpty ||
          r.nomComplet.toLowerCase().contains(_searchQuery) ||
          r.numero.toLowerCase().contains(_searchQuery);
      final matchFiltre = switch (_filtre) {
        _Filtre.tous => true,
        _Filtre.sansPin => !r.aPin,
        _Filtre.avecPin => r.aPin,
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

  Future<void> _lancer(ResidentPin resident) async {
    final pin = await showDialog<PinGenere>(
      context: context,
      builder: (_) => _ConfirmationDialog(resident: resident),
    );
    if (pin == null || !mounted) return;

    ref.invalidate(receptionPinListeProvider);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AffichageDialog(resident: resident, pin: pin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liste = ref.watch(receptionPinListeProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final total = liste.valueOrNull?.length;

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'PIN${total == null || total == 0 ? '' : '  ($total)'}',
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

  Widget _corps(AsyncValue<List<ResidentPin>> liste, bool isDesktop) {
    return liste.when(
      loading: () => const AppSkeletonList(),
      error: (erreur, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: AppErrorNotice(
            error: erreur.toString(),
            onRetry: () => ref.invalidate(receptionPinListeProvider),
          ),
        ),
      ),
      data: (tous) {
        if (tous.isEmpty) return const _EmptyState();

        final filtered = _filtered(tous);
        if (filtered.isEmpty) {
          return _EmptySearch(onClear: _reinitialiser);
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
          return _PinRow(
            key: ValueKey('${r.residentId}-${r.appartementId}'),
            resident: r,
            isAlternate: i.isOdd,
            onPin: () => _lancer(r),
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
                                ref.invalidate(receptionPinListeProvider),
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
                onRefresh: () async => ref.invalidate(receptionPinListeProvider),
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
          Expanded(child: Text('STATUT', style: labelStyle)),
          Expanded(child: Text('PIN', style: labelStyle)),
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
  }

  Widget _buildChips() {
    const chips = [
      (_Filtre.tous, 'Tous'),
      (_Filtre.sansPin, 'Sans PIN'),
      (_Filtre.avecPin, 'PIN défini'),
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
// LIGNE DU TABLEAU (desktop) / CARTE (mobile)
// ══════════════════════════════════════════════════════════

class _PinRow extends StatelessWidget {
  final ResidentPin resident;
  final bool isAlternate;
  final VoidCallback onPin;

  const _PinRow({
    super.key,
    required this.resident,
    required this.isAlternate,
    required this.onPin,
  });

  String get _libelleAction =>
      resident.aPin ? 'Réinitialiser le PIN' : 'Générer le PIN';

  Widget _action() => _IconBtn(
        icon: resident.aPin ? Icons.lock_reset_rounded : Icons.key_rounded,
        color: resident.aPin ? AppColors.aVerifier : AppColors.rouge,
        tooltip: _libelleAction,
        onTap: onPin,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: 9,
        ),
        child: Row(
          children: [
            _AvatarCircle(initiales: resident.initiales, size: 30, fontSize: 11),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              flex: 2,
              child: Text(
                resident.nomComplet,
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
                'Apt ${resident.numero}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.grisText,
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Badge(
                  label: resident.aApplication ? 'Inscrit' : 'Sans app',
                  color: resident.aApplication
                      ? AppColors.fait
                      : AppColors.aVerifier,
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Badge(
                  label: resident.aPin ? 'Défini' : 'Non défini',
                  color: resident.aPin ? AppColors.fait : AppColors.grisDark,
                ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: 10,
        ),
        child: Row(
          children: [
            _AvatarCircle(initiales: resident.initiales, size: 42, fontSize: 14),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    resident.nomComplet,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.noir,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Apt ${resident.numero}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.grisText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Badge(
                        label: resident.aApplication ? 'Inscrit' : 'Sans app',
                        color: resident.aApplication
                            ? AppColors.fait
                            : AppColors.aVerifier,
                      ),
                      _Badge(
                        label: resident.aPin ? 'PIN défini' : 'PIN non défini',
                        color:
                            resident.aPin ? AppColors.fait : AppColors.grisDark,
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

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
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
// CONFIRMATION, PUIS AFFICHAGE UNIQUE DU PIN
// ══════════════════════════════════════════════════════════

class _ConfirmationDialog extends ConsumerStatefulWidget {
  final ResidentPin resident;

  const _ConfirmationDialog({required this.resident});

  @override
  ConsumerState<_ConfirmationDialog> createState() =>
      _ConfirmationDialogState();
}

class _ConfirmationDialogState extends ConsumerState<_ConfirmationDialog> {
  bool _envoi = false;
  String? _erreur;

  Future<void> _confirmer() async {
    final auteur = ref.read(employeeCourantProvider);
    if (auteur == null) {
      setState(() => _erreur = 'Votre session a expiré. Reconnectez-vous.');
      return;
    }

    setState(() {
      _envoi = true;
      _erreur = null;
    });

    try {
      final pin = await ref.read(receptionPinRepositoryProvider).genererPin(
            residentId: widget.resident.residentId,
            auteurId: auteur.id,
          );
      if (!mounted) return;
      Navigator.of(context).pop(pin);
    } on ReceptionErreur catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resident;
    final reinit = r.aPin;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      title: Text(reinit ? 'Réinitialiser le PIN' : 'Générer le PIN'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.nomComplet} · Apt ${r.numero}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSizes.sm),
            Text(
              reinit
                  ? "Un nouveau PIN de 4 chiffres sera généré. L'ancien PIN "
                      'ne fonctionnera plus.'
                  : 'Un PIN de 4 chiffres sera généré pour ce résident.',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: AppSizes.xs),
            const Text(
              'Il ne sera affiché qu\'une seule fois : notez-le ou '
              'communiquez-le tout de suite.',
              style: TextStyle(height: 1.4, color: AppColors.grisDark),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: AppSizes.sm),
              Text(_erreur!, style: const TextStyle(color: AppColors.refus)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : _confirmer,
          child: _envoi
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(reinit ? 'Réinitialiser' : 'Générer'),
        ),
      ],
    );
  }
}

class _AffichageDialog extends StatelessWidget {
  final ResidentPin resident;
  final PinGenere pin;

  const _AffichageDialog({required this.resident, required this.pin});

  Future<void> _copier(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: pin.pin));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('PIN copié.')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      title: Text(pin.reinitialise ? 'PIN réinitialisé' : 'PIN généré'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${resident.nomComplet} · Apt ${resident.numero}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSizes.md),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg, vertical: AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.grisLight,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: SelectableText(
                  pin.pin,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              pin.reinitialise
                  ? "L'ancien PIN ne fonctionne plus. Communiquez celui-ci au "
                      'résident maintenant.'
                  : 'Communiquez ce PIN au résident maintenant.',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: AppSizes.xs),
            const Text(
              'Il ne pourra plus être affiché après la fermeture de cette '
              'fenêtre. En cas d\'oubli, il faudra le réinitialiser.',
              style: TextStyle(height: 1.4, color: AppColors.grisDark),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _copier(context),
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copier'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Terminé'),
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
              Icons.pin_outlined,
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
