import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Briques communes des pages de contenu, dans l'ordre où elles s'empilent :
/// [EnTetePage] → [BarreSection] → [ChampRecherche] + [BasculeAffichage] →
/// contenu (tableau ou grille) → [BarrePagination].

/// Largeur sous laquelle les pages passent en disposition téléphone.
const double kLargeurCompacte = 700;

bool estCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kLargeurCompacte;

// ── En-tête de page ───────────────────────────────────────

/// Bande du haut : tuile avec icône, titre en majuscules, sous-titre.
class EnTetePage extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String? sousTitre;

  const EnTetePage({
    super.key,
    required this.icone,
    required this.titre,
    this.sousTitre,
  });

  @override
  Widget build(BuildContext context) {
    final compact = estCompact(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 14 : 18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.grisMedium)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 44 : 50,
            height: compact ? 44 : 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icone, color: AppColors.rouge, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.noir,
                    letterSpacing: 0.1,
                  ),
                ),
                if (sousTitre != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    sousTitre!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.grisDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page ──────────────────────────────────────────────────

/// Squelette des pages de contenu : l'[enTete] reste FIXE en haut, seul le
/// [contenu] (en général une liste défilante) défile dessous. Une fine barre
/// de progression apparaît sous l'en-tête pendant un [chargement].
class PageAvecEnTete extends StatelessWidget {
  final EnTetePage enTete;
  final Widget contenu;
  final bool chargement;

  const PageAvecEnTete({
    super.key,
    required this.enTete,
    required this.contenu,
    this.chargement = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisLight,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          enTete,
          // Hauteur réservée : l'apparition de la barre ne décale rien.
          SizedBox(
            height: 2,
            child: chargement
                ? const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.rouge,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          ),
          Expanded(child: contenu),
        ],
      ),
    );
  }
}

// ── Carte de base ─────────────────────────────────────────

BoxDecoration get _decorationCarte => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.grisMedium),
    );

/// Surface blanche bordée des blocs de contenu (tableau, grille vide…).
class CarteContenu extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const CarteContenu({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: _decorationCarte,
        child: child,
      );
}

// ── Barre de section ──────────────────────────────────────

/// Largeur d'un bouton de [BarreSection] (retour, filtre, action).
const double _kBouton = 48;

/// Filtre de [BarreSection] : icône ou court libellé ; l'actif est un carré
/// bleu plein. [pastille] signale un choix particulier (ex. semaine en cours).
class FiltreSection {
  final String? libelle;
  final IconData? icone;
  final String infoBulle;
  final bool actif;
  final bool pastille;
  final VoidCallback onTap;

  const FiltreSection({
    this.libelle,
    this.icone,
    required this.infoBulle,
    required this.actif,
    required this.onTap,
    this.pastille = false,
  }) : assert(libelle != null || icone != null);
}

/// ← puis filtres à gauche, titre centré (avec son compteur), actions à
/// droite. Sur téléphone, les filtres passent sur une seconde ligne et
/// plusieurs actions se replient dans un menu ⋮.
class BarreSection extends StatelessWidget {
  final String titre;

  /// Ligne bleue sous le titre (ex. la période affichée).
  final String? sousTitre;
  final VoidCallback? onRetour;
  final List<FiltreSection> filtres;
  final List<ActionSection> actions;

  const BarreSection({
    super.key,
    required this.titre,
    this.sousTitre,
    this.onRetour,
    this.filtres = const [],
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final compact = estCompact(context);
    final boutonsFiltres = [for (final f in filtres) _BoutonFiltre(f)];
    final gauche = <Widget>[
      if (onRetour != null)
        IconButton(
          tooltip: 'Retour',
          onPressed: onRetour,
          constraints:
              const BoxConstraints.tightFor(width: _kBouton, height: _kBouton),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.rouge),
        ),
      if (!compact) ...boutonsFiltres,
    ];
    final droite = <Widget>[
      if (compact && actions.length > 1) _MenuActions(actions) else ...actions,
    ];
    // Côtés de même largeur : le titre reste au centre de la barre.
    final cote = _kBouton *
        (gauche.length > droite.length ? gauche.length : droite.length);

    final texteTitre = Text(
      titre.toUpperCase(),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 12.5 : 14.5,
        fontWeight: FontWeight.w800,
        color: AppColors.noir,
      ),
    );
    final ligne = SizedBox(
      height: sousTitre == null ? 56 : (compact ? 72 : 64),
      child: Row(
        children: [
          SizedBox(width: cote, child: Row(children: gauche)),
          Expanded(
            child: sousTitre == null
                ? texteTitre
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      texteTitre,
                      const SizedBox(height: 3),
                      Text(
                        sousTitre!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 11.5 : 13,
                          color: AppColors.rouge,
                        ),
                      ),
                    ],
                  ),
          ),
          SizedBox(
            width: cote,
            child:
                Row(mainAxisAlignment: MainAxisAlignment.end, children: droite),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: _decorationCarte,
      child: compact && filtres.isNotEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ligne,
                const Divider(height: 1, color: AppColors.grisMedium),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: boutonsFiltres,
                  ),
                ),
              ],
            )
          : ligne,
    );
  }
}

class _BoutonFiltre extends StatelessWidget {
  final FiltreSection filtre;

  const _BoutonFiltre(this.filtre);

  @override
  Widget build(BuildContext context) {
    final f = filtre;
    final couleur = f.actif ? Colors.white : AppColors.rouge;
    return Tooltip(
      message: f.infoBulle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: f.actif ? AppColors.rouge : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: f.onTap,
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: _kBouton - 4,
              height: _kBouton - 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (f.icone != null)
                    Icon(f.icone, size: 20, color: couleur)
                  else
                    Text(
                      f.libelle!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: couleur,
                      ),
                    ),
                  if (f.pastille)
                    Positioned(
                      bottom: 5,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: couleur,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Action de [BarreSection] : icône bleue avec info-bulle.
class ActionSection extends StatelessWidget {
  final IconData icone;
  final String infoBulle;
  final VoidCallback? onPressed;

  const ActionSection({
    super.key,
    required this.icone,
    required this.infoBulle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: infoBulle,
        onPressed: onPressed,
        constraints:
            const BoxConstraints.tightFor(width: _kBouton, height: _kBouton),
        icon: Icon(icone, color: AppColors.rouge),
      );
}

/// Actions repliées dans un menu ⋮ (téléphone).
class _MenuActions extends StatelessWidget {
  final List<ActionSection> actions;

  const _MenuActions(this.actions);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.rouge),
      onSelected: (i) => actions[i].onPressed?.call(),
      itemBuilder: (_) => [
        for (final (i, a) in actions.indexed)
          PopupMenuItem(
            value: i,
            enabled: a.onPressed != null,
            child: Row(
              children: [
                Icon(a.icone, size: 20, color: AppColors.rouge),
                const SizedBox(width: 12),
                Text(a.infoBulle),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Recherche ─────────────────────────────────────────────

/// Champ de recherche arrondi, loupe à droite.
class ChampRecherche extends StatelessWidget {
  final String indice;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const ChampRecherche({
    super.key,
    required this.indice,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder bord(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: c, width: w),
        );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: indice,
        hintStyle: const TextStyle(color: AppColors.grisText, fontSize: 14),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        suffixIcon: const Icon(Icons.search_rounded, color: AppColors.rouge),
        border: bord(AppColors.grisMedium),
        enabledBorder: bord(AppColors.grisMedium),
        focusedBorder: bord(AppColors.rouge, 1.5),
      ),
    );
  }
}

// ── Affichage grille / tableau ────────────────────────────

enum ModeAffichage { grille, tableau }

class BasculeAffichage extends StatelessWidget {
  final ModeAffichage mode;
  final ValueChanged<ModeAffichage> onChanged;

  const BasculeAffichage({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ModeAffichage>(
      segments: const [
        ButtonSegment(
          value: ModeAffichage.grille,
          label: Text('Affichage grille'),
          icon: Icon(Icons.grid_view_rounded, size: 18),
        ),
        ButtonSegment(
          value: ModeAffichage.tableau,
          label: Text('Affichage tableau'),
          icon: Icon(Icons.table_rows_rounded, size: 18),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (s) => onChanged(s.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.noir,
        selectedBackgroundColor: AppColors.rouge.withValues(alpha: 0.10),
        selectedForegroundColor: AppColors.rouge,
        side: const BorderSide(color: AppColors.grisMedium),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ── Pagination ────────────────────────────────────────────

/// « Éléments par page », « 1 – 6 sur 12 », première / précédente / suivante /
/// dernière page. [page] commence à 0.
class BarrePagination extends StatelessWidget {
  final int page;
  final int parPage;
  final int total;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onParPage;
  final List<int> choixParPage;

  const BarrePagination({
    super.key,
    required this.page,
    required this.parPage,
    required this.total,
    required this.onPage,
    required this.onParPage,
    this.choixParPage = const [5, 10, 20, 50],
  });

  int get nbPages => total == 0 ? 1 : ((total - 1) ~/ parPage) + 1;

  @override
  Widget build(BuildContext context) {
    final compact = estCompact(context);
    final debut = total == 0 ? 0 : page * parPage + 1;
    final fin = ((page + 1) * parPage).clamp(0, total);
    final premiere = page > 0;
    final derniere = page < nbPages - 1;
    const style = TextStyle(fontSize: 12.5, color: AppColors.noir);

    Widget bouton(IconData icone, String infoBulle, bool actif, int cible) =>
        IconButton(
          tooltip: infoBulle,
          visualDensity: VisualDensity.compact,
          onPressed: actif ? () => onPage(cible) : null,
          icon: Icon(icone, size: 22),
          color: AppColors.grisDark,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: _decorationCarte,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!compact) ...[
            const Text('Éléments par page :', style: style),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.grisMedium),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: parPage,
                isDense: true,
                style: style,
                items: [
                  for (final n in choixParPage)
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (n) {
                  if (n != null) onParPage(n);
                },
              ),
            ),
          ),
          SizedBox(width: compact ? 8 : 24),
          Text('$debut – $fin sur $total', style: style),
          SizedBox(width: compact ? 4 : 16),
          if (!compact)
            bouton(Icons.first_page_rounded, 'Première page', premiere, 0),
          bouton(Icons.chevron_left_rounded, 'Page précédente', premiere,
              page - 1),
          bouton(
              Icons.chevron_right_rounded, 'Page suivante', derniere, page + 1),
          if (!compact)
            bouton(Icons.last_page_rounded, 'Dernière page', derniere,
                nbPages - 1),
        ],
      ),
    );
  }
}
