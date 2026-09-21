import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../domain/reception_equipe_models.dart';
import '../providers/reception_equipe_provider.dart';

enum _Filtre { tous, presents, absents, nonDeclares }

/// Section « Équipe » de la vue Réception : qui est présent aujourd'hui et
/// l'horaire du jour de chaque employé. Lecture seule.
class ReceptionEquipeScreen extends ConsumerStatefulWidget {
  const ReceptionEquipeScreen({super.key});

  @override
  ConsumerState<ReceptionEquipeScreen> createState() =>
      _ReceptionEquipeScreenState();
}

class _ReceptionEquipeScreenState extends ConsumerState<ReceptionEquipeScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  _Filtre _filtre = _Filtre.tous;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MembreEquipe> _filtered(List<MembreEquipe> all) {
    return all.where((m) {
      final matchSearch = _searchQuery.isEmpty ||
          m.nomComplet.toLowerCase().contains(_searchQuery);
      final matchFiltre = switch (_filtre) {
        _Filtre.tous => true,
        _Filtre.presents => m.presence == PresenceJour.presente,
        _Filtre.absents => m.presence.estAbsence,
        _Filtre.nonDeclares => m.presence == PresenceJour.nonDeclaree,
      };
      return matchSearch && matchFiltre;
    }).toList();
  }

  void _reinitialiser() {
    _searchCtrl.clear();
    setState(() => _filtre = _Filtre.tous);
  }

  @override
  Widget build(BuildContext context) {
    final equipe = ref.watch(receptionEquipeProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final total = equipe.valueOrNull?.membres.length;

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Équipe${total == null || total == 0 ? '' : '  ($total)'}',
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
                onFiltreChanged: (f) => setState(() => _filtre = f),
              ),
              if (equipe.isLoading && equipe.hasValue)
                const LinearProgressIndicator(
                  color: AppColors.rouge,
                  backgroundColor: Colors.transparent,
                  minHeight: 2,
                ),
              Expanded(child: _corps(equipe, isDesktop)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _corps(AsyncValue<EquipeDuJour> equipe, bool isDesktop) {
    return equipe.when(
      loading: () => const AppSkeletonList(),
      error: (erreur, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: AppErrorNotice(
            error: erreur.toString(),
            onRetry: () => ref.invalidate(receptionEquipeProvider),
          ),
        ),
      ),
      data: (donnees) {
        if (donnees.membres.isEmpty) return const _EmptyState();

        final filtered = _filtered(donnees.membres);

        Widget ligne(int i) {
          final m = filtered[i];
          return _MembreRow(
            key: ValueKey(m.id),
            membre: m,
            isAlternate: i.isOdd,
            onHoraire: () => _ouvrirHoraire(m, donnees.date),
          );
        }

        final entete = _JourEtAttente(donnees: donnees);

        if (filtered.isEmpty) {
          return Column(
            children: [
              entete,
              Expanded(child: _EmptySearch(onClear: _reinitialiser)),
            ],
          );
        }

        if (isDesktop) {
          return Column(
            children: [
              entete,
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
                                ref.invalidate(receptionEquipeProvider),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: filtered.length,
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
            ],
          );
        }

        return Column(
          children: [
            entete,
            Expanded(
              child: RefreshIndicator(
                color: AppColors.rouge,
                onRefresh: () async => ref.invalidate(receptionEquipeProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => ligne(i),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _ouvrirHoraire(MembreEquipe membre, DateTime date) {
    showDialog<void>(
      context: context,
      builder: (_) => _HoraireDialog(membre: membre, date: date),
    );
  }
}

// ══════════════════════════════════════════════════════════
// DATE DU JOUR + MÉNAGES EN ATTENTE D'ATTRIBUTION
// ══════════════════════════════════════════════════════════

String _dateLongue(DateTime date) {
  final texte = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date);
  return texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);
}

class _JourEtAttente extends StatelessWidget {
  final EquipeDuJour donnees;

  const _JourEtAttente({required this.donnees});

  @override
  Widget build(BuildContext context) {
    final attente = donnees.enAttente;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.md, AppSizes.sm, AppSizes.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aujourd\'hui — ${_dateLongue(donnees.date)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.grisDark,
            ),
          ),
          if (attente.isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.aVerifier.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
                border: Border.all(
                    color: AppColors.aVerifier.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      size: 16, color: AppColors.aVerifier),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      "${attente.length} ménage${attente.length > 1 ? 's' : ''} "
                      "en attente d'attribution : "
                      '${attente.map((t) => 'Apt ${t.numero} ${t.periode}').join(', ')}',
                      style: const TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSizes.xs),
        ],
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
          Expanded(flex: 2, child: Text('NOM', style: labelStyle)),
          Expanded(flex: 2, child: Text('PRÉSENCE', style: labelStyle)),
          Expanded(child: Text('HORAIRE', style: labelStyle)),
          Expanded(child: Text('MÉNAGES', style: labelStyle)),
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
        hintText: 'Nom ou prénom...',
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
      (_Filtre.presents, 'Présents'),
      (_Filtre.absents, 'Absents'),
      (_Filtre.nonDeclares, 'Non déclarés'),
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

class _MembreRow extends StatelessWidget {
  final MembreEquipe membre;
  final bool isAlternate;
  final VoidCallback onHoraire;

  const _MembreRow({
    super.key,
    required this.membre,
    required this.isAlternate,
    required this.onHoraire,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return isDesktop ? _buildRow() : _buildCard();
  }

  Widget _action() => _IconBtn(
        icon: Icons.event_note_outlined,
        color: AppColors.rouge,
        tooltip: "Voir l'horaire du jour",
        onTap: onHoraire,
      );

  Widget _buildRow() {
    return Material(
      color: isAlternate
          ? AppColors.grisLight.withValues(alpha: 0.4)
          : Colors.white,
      child: InkWell(
        onTap: onHoraire,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 9,
          ),
          child: Row(
            children: [
              _AvatarCircle(initiales: membre.initiales, size: 30, fontSize: 11),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                flex: 2,
                child: Text(
                  membre.nomComplet,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.noir,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _PresenceBadge(presence: membre.presence),
                ),
              ),
              Expanded(
                child: Text(
                  membre.horaire ?? '—',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.grisText,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  membre.resumeMenages,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.grisText,
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
        onTap: onHoraire,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              _AvatarCircle(initiales: membre.initiales, size: 42, fontSize: 14),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      membre.nomComplet,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.noir,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _PresenceBadge(presence: membre.presence),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (membre.horaire != null) membre.horaire!,
                        'Ménages : ${membre.resumeMenages}',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grisText,
                      ),
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

class _PresenceBadge extends StatelessWidget {
  final PresenceJour presence;

  const _PresenceBadge({required this.presence});

  Color get _color => switch (presence) {
        PresenceJour.presente => AppColors.fait,
        PresenceJour.absente => AppColors.refus,
        PresenceJour.absenteMatin ||
        PresenceJour.absenteApresMidi =>
          AppColors.aVerifier,
        PresenceJour.nonDeclaree => AppColors.grisDark,
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
        presence.libelle,
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
// HORAIRE DU JOUR D'UN EMPLOYÉ
// ══════════════════════════════════════════════════════════

class _HoraireDialog extends StatelessWidget {
  final MembreEquipe membre;
  final DateTime date;

  const _HoraireDialog({required this.membre, required this.date});

  Color _couleur(EtatTacheEquipe etat) => switch (etat) {
        EtatTacheEquipe.aFaire => AppColors.grisDark,
        EtatTacheEquipe.realise => AppColors.fait,
        EtatTacheEquipe.nonRealise => AppColors.refus,
      };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(AppSizes.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
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
                        membre.nomComplet,
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
                Text(
                  _dateLongue(date),
                  style: const TextStyle(color: AppColors.grisDark),
                ),
                const SizedBox(height: AppSizes.sm),
                _PresenceBadge(presence: membre.presence),
                if (membre.horaire != null) ...[
                  const SizedBox(height: AppSizes.xs),
                  Text('Horaire : ${membre.horaire}',
                      style: const TextStyle(color: AppColors.grisDark)),
                ],
                const SizedBox(height: AppSizes.md),
                const Text(
                  'Horaire du jour',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSizes.xs),
                if (membre.taches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
                    child: Text(
                      'Aucun ménage prévu aujourd\'hui.',
                      style: TextStyle(color: AppColors.grisDark),
                    ),
                  )
                else
                  for (final t in membre.taches)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              t.periode,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            child: Text('Apt ${t.numero}',
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Text(
                            t.etat.libelle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _couleur(t.etat),
                            ),
                          ),
                        ],
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
              Icons.group_outlined,
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
            'Aucun employé actif à afficher.',
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
