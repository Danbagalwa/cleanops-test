import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/export_menu_button.dart'
    show showExportSuccess;
import '../../../../core/widgets/mise_en_page.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../pdf/domain/usecases/generate_aire_commune_export.dart';
import '../../../pdf/presentation/screens/aire_commune_pdf_preview_screen.dart';
import '../../domain/entities/reset_aire_commune.dart';
import '../../domain/entities/tache_aire_commune.dart';
import '../providers/aire_commune_provider.dart';
import '../widgets/aire_commune_actions.dart';

enum _Statut { toutes, aConfirmer, confirmees }

enum _Tri { categorie, zone, statut }

class AireCommuneScreen extends ConsumerStatefulWidget {
  const AireCommuneScreen({super.key});

  @override
  ConsumerState<AireCommuneScreen> createState() => _AireCommuneScreenState();
}

class _AireCommuneScreenState extends ConsumerState<AireCommuneScreen> {
  AireCategorie? _categorie;
  _Statut _statut = _Statut.toutes;
  String _recherche = '';
  _Tri _tri = _Tri.categorie;
  bool _croissant = true;
  int _page = 0;
  int _parPage = 20;

  /// `null` : choisi selon la largeur (grille sur téléphone, tableau sinon).
  ModeAffichage? _mode;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final n = ref.read(aireCommuneNotifierProvider.notifier);
      n.loadTaches();
      n.loadHistoriqueResets();
      n.loadConfig();
    });
  }

  Future<void> _charger() =>
      ref.read(aireCommuneNotifierProvider.notifier).loadTaches();

  void _changer(VoidCallback maj) => setState(() {
        maj();
        _page = 0;
      });

  void _trier(_Tri tri) => _changer(() {
        _croissant = _tri == tri ? !_croissant : true;
        _tri = tri;
      });

  List<TacheAireCommune> _lignes(List<TacheAireCommune> toutes) {
    final q = _recherche.trim().toLowerCase();
    int parCategorie(TacheAireCommune a, TacheAireCommune b) {
      final c = a.categorie.index.compareTo(b.categorie.index);
      return c != 0 ? c : comparerZones(a.zone, b.zone);
    }

    int sens(int c) => _croissant ? c : -c;
    return toutes.where((t) {
      if (_categorie != null && t.categorie != _categorie) return false;
      if (_statut == _Statut.aConfirmer && t.estFait) return false;
      if (_statut == _Statut.confirmees && !t.estFait) return false;
      return q.isEmpty ||
          formatZoneAire(t.zone).toLowerCase().contains(q) ||
          t.categorie.libelle.toLowerCase().contains(q) ||
          (t.confirmeParPrenom ?? '').toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => switch (_tri) {
            _Tri.categorie => sens(parCategorie(a, b)),
            _Tri.zone => sens(
                comparerZones(formatZoneAire(a.zone), formatZoneAire(b.zone))),
            _Tri.statut => a.estFait == b.estFait
                ? parCategorie(a, b)
                : sens(a.estFait ? 1 : -1),
          });
  }

  String _semaine(List<TacheAireCommune> toutes) {
    if (toutes.isEmpty) return 'Semaine en cours';
    return 'Semaine du '
        '${DateFormat('d MMMM yyyy', 'fr_FR').format(toutes.first.semaineDate)}';
  }

  String get _descriptionFiltres => [
        if (_categorie != null) _categorie!.libelle,
        if (_statut == _Statut.aConfirmer) 'à confirmer',
        if (_statut == _Statut.confirmees) 'confirmées',
        if (_recherche.trim().isNotEmpty) '« ${_recherche.trim()} »',
      ].join(' · ');

  String _nomFichier(List<TacheAireCommune> toutes) => toutes.isEmpty
      ? 'aires-communes'
      : 'aires-communes-${DateFormat('yyyy-MM-dd').format(toutes.first.semaineDate)}';

  void _exporterPdf(List<TacheAireCommune> lignes, String semaine,
      List<TacheAireCommune> toutes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AireCommunePdfPreviewScreen(
          zones: lignes,
          semaine: semaine,
          filtres: _descriptionFiltres,
          nomFichier: '${_nomFichier(toutes)}.pdf',
          generatedBy:
              ref.read(employeeCourantProvider)?.nomComplet ?? 'CleanOps',
        ),
      ),
    );
  }

  void _exporterExcel(List<TacheAireCommune> lignes, String semaine,
      List<TacheAireCommune> toutes) {
    try {
      const GenerateAireCommuneExcel()(
        zones: lignes,
        semaine: semaine,
        nomFichier: '${_nomFichier(toutes)}.xlsx',
      );
      showExportSuccess(
          context, 'Le suivi Excel des aires communes a été téléchargé.');
    } catch (error) {
      AppFeedback.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aireCommuneNotifierProvider);
    final isResponsable = ref.watch(isResponsableProvider);
    final compact = estCompact(context);
    final mode =
        compact ? ModeAffichage.grille : (_mode ?? ModeAffichage.tableau);
    final marge = compact ? 12.0 : 24.0;

    final toutes = state.tachesParCategorie.values.expand((l) => l).toList();
    final semaine = _semaine(toutes);
    final faites = toutes.where((t) => t.estFait).length;
    final lignes = _lignes(toutes);
    final nbPages = lignes.isEmpty ? 1 : ((lignes.length - 1) ~/ _parPage) + 1;
    final page = _page.clamp(0, nbPages - 1);
    final visibles = lignes.skip(page * _parPage).take(_parPage).toList();

    FiltreSection filtre(_Statut s, IconData icone, String info) =>
        FiltreSection(
          icone: icone,
          infoBulle: info,
          actif: _statut == s,
          onTap: () => _changer(() => _statut = s),
        );

    final recherche = ChampRecherche(
      indice: 'Rechercher une zone, une catégorie ou une préposée',
      onChanged: (v) => _changer(() => _recherche = v),
    );

    Widget corps;
    if (state.isLoading && toutes.isEmpty) {
      corps = const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.rouge)),
      );
    } else if (state.error != null && toutes.isEmpty) {
      corps = CarteContenu(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: AppErrorNotice(error: state.error!, onRetry: _charger),
      );
    } else if (toutes.isEmpty) {
      corps = _EtatVide(jour: state.jourResetConfig);
    } else if (lignes.isEmpty) {
      corps = const CarteContenu(
        padding: EdgeInsets.all(AppSizes.xl),
        child: Text(
          'Aucune zone ne correspond aux filtres.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.grisDark),
        ),
      );
    } else {
      corps = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == ModeAffichage.tableau)
            _TableauZones(
              lignes: visibles,
              premierNumero: page * _parPage + 1,
              tri: _tri,
              croissant: _croissant,
              onTrier: _trier,
              isResponsable: isResponsable,
            )
          else
            _GrilleZones(lignes: visibles, isResponsable: isResponsable),
          const SizedBox(height: AppSizes.md),
          BarrePagination(
            page: page,
            parPage: _parPage,
            total: lignes.length,
            onPage: (p) => setState(() => _page = p),
            onParPage: (n) => _changer(() => _parPage = n),
          ),
        ],
      );
    }

    return PageAvecEnTete(
      chargement: state.isLoading || state.isResetting,
      enTete: EnTetePage(
        icone: Icons.cleaning_services_rounded,
        titre: 'Aires communes',
        sousTitre: toutes.isEmpty
            ? semaine
            : '$semaine — $faites / ${toutes.length} zones confirmées',
      ),
      contenu: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _charger,
        child: ListView(
          padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
              .plusBarre(context),
          children: [
            BarreSection(
              titre: 'Zones de la semaine (${lignes.length})',
              onRetour: () => context.backOrHome(isResponsable
                  ? AppRoutes.employerDashboard
                  : AppRoutes.employeeDashboard),
              filtres: [
                filtre(
                    _Statut.toutes, Icons.list_alt_rounded, 'Toutes les zones'),
                filtre(_Statut.aConfirmer, Icons.radio_button_unchecked_rounded,
                    'À confirmer'),
                filtre(_Statut.confirmees, Icons.check_circle_outline_rounded,
                    'Confirmées'),
              ],
              actions: [
                if (isResponsable) ...[
                  ActionSection(
                    icone: Icons.print_rounded,
                    infoBulle: 'Imprimer ou exporter en PDF',
                    onPressed: toutes.isEmpty
                        ? null
                        : () => _exporterPdf(lignes, semaine, toutes),
                  ),
                  ActionSection(
                    icone: Icons.download_rounded,
                    infoBulle: 'Télécharger en Excel',
                    onPressed: toutes.isEmpty
                        ? null
                        : () => _exporterExcel(lignes, semaine, toutes),
                  ),
                  ActionSection(
                    icone: Icons.tune_rounded,
                    infoBulle: 'Réglages',
                    onPressed: () => context.push('/aire-commune/config'),
                  ),
                ],
                ActionSection(
                  icone: Icons.refresh_rounded,
                  infoBulle: 'Actualiser',
                  onPressed: state.isLoading ? null : _charger,
                ),
              ],
            ),
            if (toutes.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              _Avancement(faites: faites, total: toutes.length),
              const SizedBox(height: AppSizes.md),
              _FiltreCategories(
                taches: toutes,
                selection: _categorie,
                onChanged: (c) => _changer(() => _categorie = c),
              ),
              const SizedBox(height: AppSizes.md),
              if (compact)
                recherche
              else
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: recherche,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    BasculeAffichage(
                      mode: mode,
                      onChanged: (m) => setState(() => _mode = m),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: AppSizes.md),
            corps,
            if (isResponsable && state.historiqueResets.isNotEmpty) ...[
              const SizedBox(height: AppSizes.lg),
              _HistoriqueResets(resets: state.historiqueResets),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Avancement global ──────────────────────────────────────

class _Avancement extends StatelessWidget {
  final int faites;
  final int total;
  const _Avancement({required this.faites, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? faites / total : 0.0;
    final couleur = pct >= 1
        ? AppColors.fait
        : pct > 0
            ? AppColors.aVerifier
            : AppColors.refus;
    final compact = estCompact(context);

    Widget chiffre(String valeur, String libelle, Color c) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valeur,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c,
                    height: 1.1)),
            Text(libelle,
                style:
                    const TextStyle(fontSize: 11.5, color: AppColors.grisText)),
          ],
        );

    final barre = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Avancement de la semaine',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.noir),
            ),
            const Spacer(),
            Text(
              '${(pct * 100).round()} %',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: couleur),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: AppColors.grisMedium,
            valueColor: AlwaysStoppedAnimation(couleur),
          ),
        ),
      ],
    );

    final chiffres = [
      chiffre('$total', 'Zones', AppColors.noir),
      chiffre('$faites', 'Confirmées', AppColors.fait),
      chiffre('${total - faites}', 'À confirmer',
          total - faites == 0 ? AppColors.grisText : AppColors.refus),
    ];

    return CarteContenu(
      padding: const EdgeInsets.all(AppSizes.md),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                barre,
                const SizedBox(height: AppSizes.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: chiffres,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: barre),
                for (final c in chiffres) ...[
                  const SizedBox(width: 32),
                  c,
                ],
              ],
            ),
    );
  }
}

// ── Filtre par catégorie (avec avancement de chacune) ─────

class _FiltreCategories extends StatelessWidget {
  final List<TacheAireCommune> taches;
  final AireCategorie? selection;
  final ValueChanged<AireCategorie?> onChanged;

  const _FiltreCategories({
    required this.taches,
    required this.selection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final presentes = AireCategorie.values
        .where((c) => taches.any((t) => t.categorie == c))
        .toList();
    final tuiles = [
      _TuileCategorie(
        icone: Icons.apps_rounded,
        couleur: AppColors.rouge,
        libelle: 'Toutes',
        faites: taches.where((t) => t.estFait).length,
        total: taches.length,
        actif: selection == null,
        onTap: () => onChanged(null),
      ),
      for (final c in presentes)
        () {
          final dans = taches.where((t) => t.categorie == c);
          final (icone, couleur) = _style(c);
          return _TuileCategorie(
            icone: icone,
            couleur: couleur,
            libelle: c.libelle,
            faites: dans.where((t) => t.estFait).length,
            total: dans.length,
            actif: selection == c,
            onTap: () => onChanged(selection == c ? null : c),
          );
        }(),
    ];

    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      const minimum = 140.0;
      final tiennent =
          c.maxWidth >= tuiles.length * minimum + ecart * (tuiles.length - 1);
      if (tiennent) {
        return Row(
          children: [
            for (final (i, t) in tuiles.indexed) ...[
              if (i > 0) const SizedBox(width: ecart),
              Expanded(child: t),
            ],
          ],
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, t) in tuiles.indexed) ...[
              if (i > 0) const SizedBox(width: ecart),
              SizedBox(width: minimum, child: t),
            ],
          ],
        ),
      );
    });
  }
}

class _TuileCategorie extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String libelle;
  final int faites;
  final int total;
  final bool actif;
  final VoidCallback onTap;

  const _TuileCategorie({
    required this.icone,
    required this.couleur,
    required this.libelle,
    required this.faites,
    required this.total,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final complet = total > 0 && faites == total;
    return Material(
      color: actif ? AppColors.rouge.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: actif ? AppColors.rouge : AppColors.grisMedium,
          width: actif ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icone, size: 18, color: couleur),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      libelle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: actif ? AppColors.rouge : AppColors.noir,
                      ),
                    ),
                  ),
                  if (complet)
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: AppColors.fait),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$faites / $total',
                style:
                    const TextStyle(fontSize: 11.5, color: AppColors.grisDark),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: total > 0 ? faites / total : 0,
                  minHeight: 4,
                  backgroundColor: AppColors.grisMedium,
                  valueColor: AlwaysStoppedAnimation(
                      complet ? AppColors.fait : couleur),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Style d'une catégorie ──────────────────────────────────

(IconData, Color) _style(AireCategorie c) => switch (c) {
      AireCategorie.ascenseur => (Icons.elevator_rounded, AppColors.absent),
      AireCategorie.corridor => (Icons.door_sliding_outlined, AppColors.refus),
      AireCategorie.tapis => (Icons.layers_outlined, const Color(0xFF00897B)),
      AireCategorie.chute => (Icons.delete_outline_rounded, AppColors.grisDark),
      AireCategorie.salon => (Icons.weekend_outlined, const Color(0xFF7B1FA2)),
      AireCategorie.wc => (Icons.wc_rounded, AppColors.rouge),
    };

String? _confirmation(TacheAireCommune t) {
  if (!t.estFait) return null;
  final quand = t.confirmeLE == null
      ? null
      : DateFormat('EEE d MMM, HH:mm', 'fr_FR').format(t.confirmeLE!.toLocal());
  final parts = [
    if (t.confirmeParPrenom != null) t.confirmeParPrenom!,
    if (quand != null) quand,
  ];
  return parts.isEmpty ? null : parts.join(' — ');
}

class _BadgeStatut extends StatelessWidget {
  final bool fait;
  const _BadgeStatut(this.fait);

  @override
  Widget build(BuildContext context) {
    final couleur = fait ? AppColors.fait : AppColors.aVerifier;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        fait ? 'Confirmée' : 'À confirmer',
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w600, color: couleur),
      ),
    );
  }
}

/// Confirmer (zone à faire) ou, pour un responsable, annuler la
/// confirmation (zone faite).
class _ActionZone extends ConsumerStatefulWidget {
  final TacheAireCommune tache;
  final bool isResponsable;
  const _ActionZone({required this.tache, required this.isResponsable});

  @override
  ConsumerState<_ActionZone> createState() => _ActionZoneState();
}

class _ActionZoneState extends ConsumerState<_ActionZone> {
  bool _enCours = false;

  Future<void> _confirmer() async {
    setState(() => _enCours = true);
    await ref
        .read(aireCommuneNotifierProvider.notifier)
        .confirmerZone(widget.tache.id);
    if (!mounted) return;
    setState(() => _enCours = false);

    final error = ref.read(aireCommuneNotifierProvider).error;
    if (error != null) {
      AppFeedback.showError(
        context,
        'La zone n’a pas pu être confirmée. Vérifiez votre connexion et '
        'réessayez.',
      );
    } else {
      NotificationApp.succes(
          context, '${formatZoneAire(widget.tache.zone)} confirmée.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tache;
    if (t.estFait) {
      if (!widget.isResponsable) {
        return const Icon(Icons.check_circle_rounded,
            color: AppColors.fait, size: 22);
      }
      return IconButton(
        tooltip: 'Annuler la confirmation',
        onPressed: () => annulerConfirmationAire(context, ref, t),
        icon: const Icon(Icons.undo_rounded, color: AppColors.refus),
      );
    }
    return SizedBox(
      height: 36,
      child: FilledButton.icon(
        onPressed: _enCours ? null : _confirmer,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.fait,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        icon: _enCours
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check_rounded, size: 16),
        label: const Text('Confirmer'),
      ),
    );
  }
}

// ── Tableau ────────────────────────────────────────────────

const _styleEnTete = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.grisDark,
);

class _TableauZones extends StatelessWidget {
  final List<TacheAireCommune> lignes;
  final int premierNumero;
  final _Tri tri;
  final bool croissant;
  final ValueChanged<_Tri> onTrier;
  final bool isResponsable;

  const _TableauZones({
    required this.lignes,
    required this.premierNumero,
    required this.tri,
    required this.croissant,
    required this.onTrier,
    required this.isResponsable,
  });

  @override
  Widget build(BuildContext context) {
    Widget entete(String libelle, _Tri t) => _EnTeteTri(
          libelle: libelle,
          actif: tri == t,
          croissant: croissant,
          onTap: () => onTrier(t),
        );

    return CarteContenu(
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF7F8FA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                    width: 40, child: Text('N°', style: _styleEnTete)),
                Expanded(flex: 3, child: entete('Zone', _Tri.zone)),
                Expanded(flex: 2, child: entete('Catégorie', _Tri.categorie)),
                Expanded(flex: 2, child: entete('Statut', _Tri.statut)),
                const Expanded(
                    flex: 3, child: Text('Confirmée par', style: _styleEnTete)),
                const SizedBox(
                  width: 130,
                  child: Text('Action',
                      textAlign: TextAlign.center, style: _styleEnTete),
                ),
              ],
            ),
          ),
          for (final (i, t) in lignes.indexed) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.grisMedium),
            _LigneZone(
              tache: t,
              numero: premierNumero + i,
              isResponsable: isResponsable,
            ),
          ],
        ],
      ),
    );
  }
}

class _EnTeteTri extends StatelessWidget {
  final String libelle;
  final bool actif;
  final bool croissant;
  final VoidCallback onTap;

  const _EnTeteTri({
    required this.libelle,
    required this.actif,
    required this.croissant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? AppColors.rouge : AppColors.grisDark;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(libelle, style: _styleEnTete.copyWith(color: couleur)),
              const SizedBox(width: 4),
              Icon(
                !actif
                    ? Icons.swap_vert_rounded
                    : croissant
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                size: 14,
                color: couleur,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LigneZone extends StatelessWidget {
  final TacheAireCommune tache;
  final int numero;
  final bool isResponsable;

  const _LigneZone({
    required this.tache,
    required this.numero,
    required this.isResponsable,
  });

  @override
  Widget build(BuildContext context) {
    final t = tache;
    final (icone, couleur) = _style(t.categorie);
    const style = TextStyle(fontSize: 13, color: AppColors.noir);
    final confirmation = _confirmation(t);
    return Container(
      color: t.estFait ? AppColors.fait.withValues(alpha: 0.03) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('$numero', style: style)),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icone, size: 16, color: couleur),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formatZoneAire(t.zone),
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(t.categorie.libelle,
                style: style.copyWith(color: AppColors.grisDark)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _BadgeStatut(t.estFait),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              confirmation ?? '—',
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(
                color: confirmation == null
                    ? AppColors.grisText
                    : AppColors.grisDark,
              ),
            ),
          ),
          SizedBox(
            width: 130,
            child: Center(
              child: _ActionZone(tache: t, isResponsable: isResponsable),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grille ─────────────────────────────────────────────────

class _GrilleZones extends StatelessWidget {
  final List<TacheAireCommune> lignes;
  final bool isResponsable;
  const _GrilleZones({required this.lignes, required this.isResponsable});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      final colonnes = math.max(1, (c.maxWidth + ecart) ~/ (340 + ecart));
      final largeur = (c.maxWidth - ecart * (colonnes - 1)) / colonnes;
      return Wrap(
        spacing: ecart,
        runSpacing: ecart,
        children: [
          for (final t in lignes)
            SizedBox(
              width: largeur,
              child: _CarteZone(tache: t, isResponsable: isResponsable),
            ),
        ],
      );
    });
  }
}

class _CarteZone extends StatelessWidget {
  final TacheAireCommune tache;
  final bool isResponsable;
  const _CarteZone({required this.tache, required this.isResponsable});

  @override
  Widget build(BuildContext context) {
    final t = tache;
    final (icone, couleur) = _style(t.categorie);
    final confirmation = _confirmation(t);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: t.estFait ? AppColors.faitBg : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: t.estFait
              ? AppColors.fait.withValues(alpha: 0.3)
              : AppColors.grisMedium,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: couleur, size: 20),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatZoneAire(t.zone),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: t.estFait ? AppColors.fait : AppColors.noir,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  confirmation ?? '${t.categorie.libelle} · À confirmer',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.grisText),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          _ActionZone(tache: t, isResponsable: isResponsable),
        ],
      ),
    );
  }
}

// ── Historique des remises à zéro (responsable) ────────────

class _HistoriqueResets extends StatelessWidget {
  final List<ResetAireCommune> resets;
  const _HistoriqueResets({required this.resets});

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          childrenPadding:
              const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, 12),
          iconColor: AppColors.rouge,
          leading: const Icon(Icons.history_rounded,
              size: 20, color: AppColors.absent),
          title: Text(
            'Historique des remises à zéro (${resets.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.noir,
            ),
          ),
          children: [
            for (int i = 0; i < resets.length && i < 10; i++) ...[
              if (i > 0) const Divider(height: 14),
              _ResetRow(reset: resets[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResetRow extends StatelessWidget {
  final ResetAireCommune reset;
  const _ResetRow({required this.reset});

  @override
  Widget build(BuildContext context) {
    final isAuto = reset.automatique;
    final label = isAuto
        ? 'Remise à zéro automatique'
        : 'Remise à zéro manuelle — ${reset.prenomEffectuePar ?? "inconnu"}';
    final date = '${DateHelper.formatDate(reset.dateReset)}  '
        '${DateHelper.formatHeure(reset.dateReset)}';

    return Row(
      children: [
        Icon(
          isAuto ? Icons.autorenew_rounded : Icons.restart_alt_rounded,
          size: 16,
          color: AppColors.absent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.noir,
                fontWeight: FontWeight.w500),
          ),
        ),
        Text(date,
            style: const TextStyle(fontSize: 11.5, color: AppColors.grisText)),
      ],
    );
  }
}

// ── État vide ──────────────────────────────────────────────

class _EtatVide extends StatelessWidget {
  final String jour;
  const _EtatVide({required this.jour});

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          const Icon(Icons.apartment_outlined,
              size: 56, color: AppColors.grisMedium),
          const SizedBox(height: AppSizes.md),
          const Text(
            'Aucune tâche cette semaine',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.grisDark),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Les zones seront générées $jour matin.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grisText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
