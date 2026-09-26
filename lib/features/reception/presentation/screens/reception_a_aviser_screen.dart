import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';
import '../../domain/reception_avis_models.dart';
import '../../domain/reception_residents_repository.dart' show ReceptionErreur;
import '../providers/reception_avis_provider.dart';
import 'package:cleanops/core/widgets/espace_barre_mobile.dart';
import 'package:cleanops/core/widgets/notification_app.dart';

const _kPageSize = 10;

enum _Filtre { aTraiter, traites, tous }

/// Section « À aviser » de la vue Réception : les résidents SANS application
/// dont le ménage a changé et que quelqu'un doit prévenir. La Réception
/// indique Appelé(e), Note laissée ou Reporter, avec un commentaire facultatif.
/// Un badge rouge signale un avis ouvert depuis plus de 2 heures.
class ReceptionAAviserScreen extends ConsumerStatefulWidget {
  const ReceptionAAviserScreen({super.key});

  @override
  ConsumerState<ReceptionAAviserScreen> createState() =>
      _ReceptionAAviserScreenState();
}

class _ReceptionAAviserScreenState
    extends ConsumerState<ReceptionAAviserScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  _Filtre _filtre = _Filtre.aTraiter;
  int _page = 0;
  Timer? _rafraichir;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase().trim();
        _page = 0;
      });
    });
    // Les durées et le badge rouge avancent avec le temps.
    _rafraichir = Timer.periodic(
      const Duration(minutes: 1),
      (_) => ref.invalidate(receptionAvisProvider),
    );
  }

  @override
  void dispose() {
    _rafraichir?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AvisResident> _filtered(List<AvisResident> all) {
    return all.where((a) {
      final matchSearch = _searchQuery.isEmpty ||
          a.nomComplet.toLowerCase().contains(_searchQuery) ||
          a.numero.toLowerCase().contains(_searchQuery);
      final matchFiltre = switch (_filtre) {
        _Filtre.aTraiter => a.ouvert,
        _Filtre.traites => !a.ouvert,
        _Filtre.tous => true,
      };
      return matchSearch && matchFiltre;
    }).toList();
  }

  void _reinitialiser() {
    _searchCtrl.clear();
    setState(() {
      _filtre = _Filtre.aTraiter;
      _page = 0;
    });
  }

  Future<void> _ouvrirTraitement(AvisResident avis, [ActionAvis? action]) {
    return showDialog<void>(
      context: context,
      builder: (_) => _TraitementDialog(avis: avis, actionInitiale: action),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liste = ref.watch(receptionAvisProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final ouverts = liste.valueOrNull?.where((a) => a.ouvert).length;

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'À aviser${ouverts == null || ouverts == 0 ? '' : '  ($ouverts)'}',
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

  Widget _corps(AsyncValue<List<AvisResident>> liste, bool isDesktop) {
    return liste.when(
      loading: () => const AppSkeletonList(),
      error: (erreur, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: AppErrorNotice(
            error: erreur.toString(),
            onRetry: () => ref.invalidate(receptionAvisProvider),
          ),
        ),
      ),
      data: (tous) {
        final enRetard = tous.where((a) => a.enRetard).length;
        final bandeau = enRetard == 0 ? null : _BandeauRetard(nombre: enRetard);

        if (tous.isEmpty) return const _EmptyState();

        final filtered = _filtered(tous);
        if (filtered.isEmpty) {
          return Column(
            children: [
              if (bandeau != null) bandeau,
              Expanded(
                child: _filtre == _Filtre.aTraiter && _searchQuery.isEmpty
                    ? const _EmptyAJour()
                    : _EmptySearch(onClear: _reinitialiser),
              ),
            ],
          );
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
          final a = paginated[i];
          return _AvisRow(
            key: ValueKey(a.id),
            avis: a,
            isAlternate: i.isOdd,
            onOuvrir: () => _ouvrirTraitement(a),
            onAction: (action) => _ouvrirTraitement(a, action),
          );
        }

        if (isDesktop) {
          return Column(
            children: [
              if (bandeau != null) bandeau,
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
                                ref.invalidate(receptionAvisProvider),
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
              if (paginationBar != null)
                AuDessusDeLaBarre(child: paginationBar),
            ],
          );
        }

        return Column(
          children: [
            if (bandeau != null) bandeau,
            Expanded(
              child: RefreshIndicator(
                color: AppColors.rouge,
                onRefresh: () async => ref.invalidate(receptionAvisProvider),
                child: ListView.builder(
                  padding: paginationBar == null
                      ? const EdgeInsets.symmetric(vertical: AppSizes.sm)
                          .plusBarre(context)
                      : const EdgeInsets.symmetric(vertical: AppSizes.sm),
                  itemCount: paginated.length,
                  itemBuilder: (_, i) => ligne(i),
                ),
              ),
            ),
            if (paginationBar != null) AuDessusDeLaBarre(child: paginationBar),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
// BANDEAU : AVIS EN RETARD
// ══════════════════════════════════════════════════════════

class _BandeauRetard extends StatelessWidget {
  final int nombre;

  const _BandeauRetard({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, 0),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.refus.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
          border: Border.all(color: AppColors.refus.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: AppColors.refus),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                nombre == 1
                    ? '1 résident attend depuis plus de 2 heures.'
                    : '$nombre résidents attendent depuis plus de 2 heures.',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.refus,
                ),
              ),
            ),
          ],
        ),
      ),
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
          Expanded(flex: 2, child: Text('RÉSIDENT', style: labelStyle)),
          Expanded(child: Text('APPARTEMENT', style: labelStyle)),
          Expanded(flex: 2, child: Text('RAISON', style: labelStyle)),
          Expanded(flex: 2, child: Text('DEPUIS', style: labelStyle)),
          Expanded(child: Text('STATUT', style: labelStyle)),
          SizedBox(width: 100, child: Text('ACTIONS', style: labelStyle)),
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
      (_Filtre.aTraiter, 'À traiter'),
      (_Filtre.traites, "Traités aujourd'hui"),
      (_Filtre.tous, 'Tous'),
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

class _AvisRow extends StatelessWidget {
  final AvisResident avis;
  final bool isAlternate;
  final VoidCallback onOuvrir;
  final ValueChanged<ActionAvis> onAction;

  const _AvisRow({
    super.key,
    required this.avis,
    required this.isAlternate,
    required this.onOuvrir,
    required this.onAction,
  });

  List<Widget> get _actions => avis.ouvert
      ? [
          _IconBtn(
            icon: Icons.phone_in_talk_outlined,
            color: AppColors.fait,
            tooltip: 'Appelé(e)',
            onTap: () => onAction(ActionAvis.appele),
          ),
          _IconBtn(
            icon: Icons.sticky_note_2_outlined,
            color: AppColors.rouge,
            tooltip: 'Note laissée',
            onTap: () => onAction(ActionAvis.noteLaissee),
          ),
          _IconBtn(
            icon: Icons.schedule_rounded,
            color: AppColors.aVerifier,
            tooltip: 'Reporter',
            onTap: () => onAction(ActionAvis.reporter),
          ),
        ]
      : const [];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return isDesktop ? _buildRow() : _buildCard();
  }

  Widget _depuis() {
    if (!avis.ouvert) {
      return const Text('—',
          style: TextStyle(fontSize: 12.5, color: AppColors.grisText));
    }
    return Row(
      children: [
        Flexible(
          child: Text(
            avis.depuis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.grisText),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (avis.enRetard) ...[
          const SizedBox(width: 6),
          const _BadgeRetard(),
        ],
      ],
    );
  }

  Widget _buildRow() {
    return Material(
      color: isAlternate
          ? AppColors.grisLight.withValues(alpha: 0.4)
          : Colors.white,
      child: InkWell(
        onTap: avis.ouvert ? onOuvrir : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 9,
          ),
          child: Row(
            children: [
              _AvatarCircle(
                  proprietaire: ProprietairePhoto(
                      TypeProprietairePhoto.resident, avis.residentId),
                  initiales: avis.initiales,
                  size: 30,
                  fontSize: 11),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                flex: 2,
                child: Text(
                  avis.nomComplet,
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
                  'Apt ${avis.numero}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.grisText,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      avis.type.libelle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.grisText,
                      ),
                    ),
                    if (avis.commentaire != null)
                      Text(
                        '« ${avis.commentaire} »',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: AppColors.grisDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Expanded(flex: 2, child: _depuis()),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatutBadge(statut: avis.statut),
                ),
              ),
              SizedBox(
                width: 100,
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
        onTap: avis.ouvert ? onOuvrir : null,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              _AvatarCircle(
                  proprietaire: ProprietairePhoto(
                      TypeProprietairePhoto.resident, avis.residentId),
                  initiales: avis.initiales,
                  size: 42,
                  fontSize: 14),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      avis.nomComplet,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.noir,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Apt ${avis.numero} · ${avis.type.libelle}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grisText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatutBadge(statut: avis.statut),
                        if (avis.ouvert)
                          Text(
                            avis.depuis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.grisText,
                            ),
                          ),
                        if (avis.enRetard) const _BadgeRetard(),
                      ],
                    ),
                    if (avis.commentaire != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '« ${avis.commentaire} »',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: AppColors.grisDark,
                        ),
                      ),
                    ],
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
  final ProprietairePhoto proprietaire;
  final String initiales;
  final double size;
  final double fontSize;

  const _AvatarCircle({
    required this.proprietaire,
    required this.initiales,
    required this.size,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return AvatarProfil(
      proprietaire: proprietaire,
      initiales: initiales,
      rayon: size / 2,
      couleurFond: AppColors.rouge.withValues(alpha: 0.12),
      couleurTexte: AppColors.rouge,
      tailleTexte: fontSize,
    );
  }
}

class _BadgeRetard extends StatelessWidget {
  const _BadgeRetard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.refus,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'En retard',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final StatutAvis statut;

  const _StatutBadge({required this.statut});

  Color get _color => switch (statut) {
        StatutAvis.aAviser => AppColors.rouge,
        StatutAvis.reporte => AppColors.aVerifier,
        StatutAvis.appele || StatutAvis.noteLaissee => AppColors.fait,
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
// TRAITEMENT D'UN AVIS
// ══════════════════════════════════════════════════════════

class _TraitementDialog extends ConsumerStatefulWidget {
  final AvisResident avis;
  final ActionAvis? actionInitiale;

  const _TraitementDialog({required this.avis, this.actionInitiale});

  @override
  ConsumerState<_TraitementDialog> createState() => _TraitementDialogState();
}

class _TraitementDialogState extends ConsumerState<_TraitementDialog> {
  static const _longueurMax = 500;

  final _ctrl = TextEditingController();
  late ActionAvis? _action = widget.actionInitiale;
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirmer() async {
    final action = _action;
    final auteur = ref.read(employeeCourantProvider);
    if (action == null) return;
    if (auteur == null) {
      setState(() => _erreur = 'Votre session a expiré. Reconnectez-vous.');
      return;
    }

    setState(() {
      _envoi = true;
      _erreur = null;
    });

    try {
      await ref.read(receptionAvisRepositoryProvider).traiter(
            avisId: widget.avis.id,
            auteurId: auteur.id,
            action: action,
            commentaire: _ctrl.text.trim().isEmpty ? null : _ctrl.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(receptionAvisProvider);
      Navigator.of(context).pop();
      NotificationApp.succes(context, 'Avis enregistré : ${action.libelle}.');
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
    final avis = widget.avis;

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
                        '${avis.nomComplet} · Apt ${avis.numero}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      icon: const Icon(Icons.close_rounded),
                      onPressed:
                          _envoi ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Text(
                  '${avis.type.libelle} · ${avis.depuis}',
                  style: const TextStyle(color: AppColors.grisDark),
                ),
                const SizedBox(height: AppSizes.md),
                const Text(
                  'À annoncer au résident',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSizes.xs),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.sm + 4),
                  decoration: BoxDecoration(
                    color: AppColors.grisLight,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
                  ),
                  child: Text(avis.message,
                      style: const TextStyle(fontSize: 13.5, height: 1.4)),
                ),
                const SizedBox(height: AppSizes.md),
                const Text(
                  'Ce qui a été fait',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSizes.xs),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final a in ActionAvis.values)
                      ChoiceChip(
                        label: Text(a.libelle),
                        selected: _action == a,
                        onSelected:
                            _envoi ? null : (_) => setState(() => _action = a),
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                TextField(
                  controller: _ctrl,
                  enabled: !_envoi,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: _longueurMax,
                  decoration: InputDecoration(
                    labelText: 'Commentaire (facultatif)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                ),
                if (_erreur != null) ...[
                  const SizedBox(height: AppSizes.xs),
                  Text(_erreur!,
                      style: const TextStyle(color: AppColors.refus)),
                ],
                const SizedBox(height: AppSizes.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _action == null || _envoi ? null : _confirmer,
                    icon: _envoi
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Confirmer'),
                  ),
                ),
              ],
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
              Icons.notifications_active_outlined,
              size: 56,
              color: AppColors.rouge,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          const Text(
            'Aucun résident à aviser',
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
              "Les résidents sans application dont le ménage change\n"
              "apparaîtront ici.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grisDark, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAJour extends StatelessWidget {
  const _EmptyAJour();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 48, color: AppColors.fait),
          SizedBox(height: AppSizes.md),
          Text(
            'Tout le monde est prévenu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.noir,
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
            'Aucun avis ne correspond\nà votre recherche ou filtre.',
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
