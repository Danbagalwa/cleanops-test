import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/export_menu_button.dart'
    show showExportSuccess;
import '../../../../core/widgets/mise_en_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pdf/domain/usecases/generate_statistiques_export.dart';
import '../../../pdf/presentation/screens/statistiques_pdf_preview_screen.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart' show StatutTache;
import '../../domain/entities/statistiques_menages.dart';
import '../providers/statistiques_provider.dart';
import '../widgets/cartes_statistiques.dart';

final _fmtDate = DateFormat('dd/MM/yyyy');

class StatistiquesScreen extends ConsumerStatefulWidget {
  const StatistiquesScreen({super.key});

  @override
  ConsumerState<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends ConsumerState<StatistiquesScreen> {
  // Filtres en cours de saisie : appliqués par « Rechercher ».
  late DateTime _debut;
  late DateTime _fin;
  String? _employe;
  bool _filtresOuverts = true;

  StatistiquesNotifier get _notifier =>
      ref.read(statistiquesNotifierProvider.notifier);

  @override
  void initState() {
    super.initState();
    final s = ref.read(statistiquesNotifierProvider);
    _debut = s.dateDebut;
    _fin = s.dateFin;
    _employe = s.employeId;
  }

  bool get _datesValides => !_debut.isAfter(_fin);

  void _rechercher() {
    if (!_datesValides) return;
    _notifier.rechercher(
      dateDebut: _debut,
      dateFin: _fin,
      employeId: _employe,
      garderPreposee: false,
    );
  }

  void _periodeRapide(PeriodeRapide p) {
    final b = p.bornes();
    setState(() {
      _debut = b.debut;
      _fin = b.fin;
    });
    _rechercher();
  }

  String _nomPreposee(StatistiquesState s) {
    final id = s.employeId;
    if (id == null) return 'Toutes les préposées';
    final p = s.donnees?.preposees.where((p) => p.id == id);
    return (p == null || p.isEmpty) ? 'Préposée' : p.first.nom;
  }

  void _exporterPdf(StatistiquesState s) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatistiquesPdfPreviewScreen(
          stats: s.vue!,
          filtres: _nomPreposee(s),
          generatedBy:
              ref.read(employeeCourantProvider)?.nomComplet ?? 'CleanOps',
        ),
      ),
    );
  }

  void _exporterExcel(StatistiquesState s) {
    try {
      const GenerateStatistiquesExcel()(
          stats: s.vue!, filtres: _nomPreposee(s));
      showExportSuccess(context, 'Les statistiques ont été téléchargées.');
    } catch (error) {
      AppFeedback.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isResponsable = ref.watch(isResponsableProvider);
    if (!isResponsable) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Accès réservé au responsable.',
            style: TextStyle(color: AppColors.grisText),
          ),
        ),
      );
    }

    final s = ref.watch(statistiquesNotifierProvider);
    final vue = s.vue;
    final compact = estCompact(context);
    final marge = compact ? 12.0 : 24.0;
    final nbJours = s.dateFin.difference(s.dateDebut).inDays + 1;
    final periode = 'Du ${_fmtDate.format(s.dateDebut)} au '
        '${_fmtDate.format(s.dateFin)} (soit une période de $nbJours '
        'jour${nbJours > 1 ? 's' : ''})';
    final sousTitre =
        s.employeId == null ? periode : '$periode · ${_nomPreposee(s)}';
    final exportable = vue != null && !s.isLoading;

    Widget corps;
    if (s.error != null && s.donnees == null) {
      corps = CarteContenu(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: AppErrorNotice(error: s.error!, onRetry: _notifier.charger),
      );
    } else if (vue == null) {
      corps = const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.rouge)),
      );
    } else {
      corps = _Tableau(stats: vue);
    }

    return PageAvecEnTete(
      chargement: s.isLoading,
      enTete: const EnTetePage(
        icone: Icons.insights_rounded,
        titre: 'Statistiques',
        sousTitre: 'Chiffres clés des ménages : volume, réalisation et suivi '
            'par préposée et par appartement.',
      ),
      contenu: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _notifier.charger,
        child: ListView(
          padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
              .plusBarre(context),
          children: [
            BarreSection(
              titre: 'Chiffres clés des ménages',
              sousTitre: sousTitre,
              onRetour: () => context.backOrHome(AppRoutes.employerDashboard),
              actions: [
                ActionSection(
                  icone: Icons.print_rounded,
                  infoBulle: 'Imprimer ou exporter en PDF',
                  onPressed: exportable ? () => _exporterPdf(s) : null,
                ),
                ActionSection(
                  icone: Icons.download_rounded,
                  infoBulle: 'Télécharger en Excel',
                  onPressed: exportable ? () => _exporterExcel(s) : null,
                ),
                ActionSection(
                  icone: Icons.refresh_rounded,
                  infoBulle: 'Actualiser',
                  onPressed: s.isLoading ? null : _notifier.charger,
                ),
                ActionSection(
                  icone: _filtresOuverts
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  infoBulle: _filtresOuverts
                      ? 'Masquer les filtres'
                      : 'Afficher les filtres',
                  onPressed: () =>
                      setState(() => _filtresOuverts = !_filtresOuverts),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _filtresOuverts
                  ? _PanneauFiltres(
                      debut: _debut,
                      fin: _fin,
                      employe: _employe,
                      preposees: s.donnees?.preposees ?? const [],
                      enCours: s.isLoading,
                      datesValides: _datesValides,
                      nonApplique: _debut != s.dateDebut ||
                          _fin != s.dateFin ||
                          _employe != s.employeId,
                      onDebut: (d) => setState(() => _debut = d),
                      onFin: (d) => setState(() => _fin = d),
                      onEmploye: (e) => setState(() => _employe = e),
                      onPeriodeRapide: _periodeRapide,
                      onRechercher: _rechercher,
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: AppSizes.md),
            corps,
          ],
        ),
      ),
    );
  }
}

// ── Filtres ────────────────────────────────────────────────

class _PanneauFiltres extends StatelessWidget {
  final DateTime debut;
  final DateTime fin;
  final String? employe;
  final List<({String id, String nom})> preposees;
  final bool enCours;
  final bool datesValides;
  final bool nonApplique;
  final ValueChanged<DateTime> onDebut;
  final ValueChanged<DateTime> onFin;
  final ValueChanged<String?> onEmploye;
  final ValueChanged<PeriodeRapide> onPeriodeRapide;
  final VoidCallback onRechercher;

  const _PanneauFiltres({
    required this.debut,
    required this.fin,
    required this.employe,
    required this.preposees,
    required this.enCours,
    required this.datesValides,
    required this.nonApplique,
    required this.onDebut,
    required this.onFin,
    required this.onEmploye,
    required this.onPeriodeRapide,
    required this.onRechercher,
  });

  @override
  Widget build(BuildContext context) {
    final compact = estCompact(context);
    // La préposée choisie peut ne plus figurer dans la nouvelle période.
    final valeurEmploye =
        preposees.any((p) => p.id == employe) ? employe : null;

    final champDebut = _ChampDate(
      libelle: 'Date de début',
      valeur: debut,
      onChanged: onDebut,
    );
    final champFin = _ChampDate(
      libelle: 'Date de fin',
      valeur: fin,
      onChanged: onFin,
      erreur: datesValides ? null : 'Doit suivre la date de début',
    );
    final champPreposee = _Libelle(
      libelle: 'Préposée',
      child: DropdownButtonFormField<String?>(
        // Reconstruit quand la liste ou le choix change (nouvelle période).
        key: ValueKey('${valeurEmploye}_${preposees.length}'),
        initialValue: valeurEmploye,
        isExpanded: true,
        decoration: _decoration(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        items: [
          const DropdownMenuItem(
              value: null, child: Text('Toutes les préposées')),
          for (final p in preposees)
            DropdownMenuItem(
              value: p.id,
              child: Text(p.nom, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onEmploye,
      ),
    );
    final periodes = PopupMenuButton<PeriodeRapide>(
      tooltip: 'Périodes rapides',
      onSelected: onPeriodeRapide,
      offset: const Offset(0, 48),
      itemBuilder: (_) => [
        for (final p in PeriodeRapide.values)
          PopupMenuItem(value: p, child: Text(p.libelle)),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.rouge.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: AppColors.rouge),
      ),
    );
    final rechercher = FilledButton(
      onPressed: datesValides && !enCours ? onRechercher : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.rouge,
        shape: const StadiumBorder(),
        minimumSize: const Size(130, 44),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      child: const Text('Rechercher'),
    );

    final Widget contenu;
    if (compact) {
      contenu = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: champDebut),
              const SizedBox(width: 10),
              Expanded(child: champFin),
            ],
          ),
          const SizedBox(height: 12),
          champPreposee,
          const SizedBox(height: 14),
          Row(
            children: [
              periodes,
              const SizedBox(width: 12),
              Expanded(child: rechercher),
            ],
          ),
        ],
      );
    } else {
      contenu = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: champDebut),
          const SizedBox(width: 18),
          Expanded(child: champFin),
          const SizedBox(width: 18),
          Expanded(child: champPreposee),
          const SizedBox(width: 18),
          Padding(
            padding: EdgeInsets.only(bottom: datesValides ? 0 : 20),
            child: periodes,
          ),
          const SizedBox(width: 36),
          Padding(
            padding: EdgeInsets.only(bottom: datesValides ? 0 : 20),
            child: rechercher,
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.grisMedium)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          contenu,
          if (nonApplique && datesValides) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 15, color: AppColors.grisDark),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Cliquez sur « Rechercher » pour appliquer ces filtres.',
                    style: TextStyle(fontSize: 12, color: AppColors.grisDark),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

InputDecoration _decoration({String? erreur}) => InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      errorText: erreur,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.grisMedium),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.grisMedium),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.rouge, width: 1.5),
      ),
    );

class _Libelle extends StatelessWidget {
  final String libelle;
  final Widget child;
  const _Libelle({required this.libelle, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(libelle,
              style: const TextStyle(fontSize: 12, color: AppColors.grisDark)),
          const SizedBox(height: 6),
          child,
        ],
      );
}

class _ChampDate extends StatelessWidget {
  final String libelle;
  final DateTime valeur;
  final ValueChanged<DateTime> onChanged;
  final String? erreur;

  const _ChampDate({
    required this.libelle,
    required this.valeur,
    required this.onChanged,
    this.erreur,
  });

  Future<void> _choisir(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: valeur,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      locale: const Locale('fr', 'CA'),
      helpText: libelle,
    );
    if (d != null) onChanged(DateTime(d.year, d.month, d.day));
  }

  @override
  Widget build(BuildContext context) {
    return _Libelle(
      libelle: libelle,
      child: InkWell(
        onTap: () => _choisir(context),
        borderRadius: BorderRadius.circular(6),
        child: InputDecorator(
          decoration: _decoration(erreur: erreur),
          child: Row(
            children: [
              Expanded(
                child: Text(_fmtDate.format(valeur),
                    style:
                        const TextStyle(fontSize: 14, color: AppColors.noir)),
              ),
              const Icon(Icons.calendar_month_rounded,
                  size: 18, color: AppColors.grisDark),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tableau de bord ────────────────────────────────────────

class _Tableau extends StatelessWidget {
  final StatistiquesMenages stats;
  const _Tableau({required this.stats});

  @override
  Widget build(BuildContext context) {
    final c = stats.comptes;
    final faits = stats.faitsParPeriode;

    final realises = CarteStatistique(
      titre: 'Ménages réalisés | Total : ${c.fait}',
      graphique: (_) => Camembert(
        vide: 'Aucun ménage réalisé sur la période.',
        parts: [
          (libelle: 'Matin', valeur: faits.matin, couleur: couleurMatin),
          (
            libelle: 'Après-midi',
            valeur: faits.apresMidi,
            couleur: couleurApresMidi
          ),
        ],
      ),
      tableau: (_) => TableauStat(
        vide: 'Aucun ménage réalisé sur la période.',
        entetes: const ['Période', 'Ménages', 'Part'],
        lignes: c.fait == 0
            ? const []
            : [
                ['Matin', '${faits.matin}', _part(faits.matin, c.fait)],
                [
                  'Après-midi',
                  '${faits.apresMidi}',
                  _part(faits.apresMidi, c.fait)
                ],
              ],
      ),
    );

    const nonRealisesStatuts = [
      StatutTache.nonCommence,
      StatutTache.absent,
      StatutTache.refus,
      StatutTache.annule,
    ];
    final nonRealises = CarteStatistique(
      titre: 'Ménages non réalisés | Total : ${c.nonRealises}',
      graphique: (_) => Camembert(
        vide: 'Tous les ménages ont été réalisés.',
        parts: [
          for (final s in nonRealisesStatuts)
            (
              libelle: libelleStatut(s),
              valeur: c.de(s),
              couleur: couleurStatut(s)
            ),
        ],
      ),
      tableau: (_) => TableauStat(
        vide: 'Tous les ménages ont été réalisés.',
        entetes: const ['Statut', 'Ménages', 'Part'],
        lignes: c.nonRealises == 0
            ? const []
            : [
                for (final s in nonRealisesStatuts)
                  [
                    libelleStatut(s),
                    '${c.de(s)}',
                    _part(c.de(s), c.nonRealises)
                  ],
              ],
      ),
    );

    final parJour = CarteStatistique(
      titre: 'Réalisation par jour | ${stats.parJour.length} '
          'jour${stats.parJour.length > 1 ? 's' : ''}',
      hauteur: 300,
      graphique: (_) => GraphiqueParJour(jours: stats.parJour),
      tableau: (_) => TableauStat(
        vide: 'Aucun ménage sur la période.',
        poidsPremiere: 3,
        entetes: const [
          'Jour',
          'Planifiés',
          'Faits',
          'Absents',
          'Refus',
          'Réalisation',
        ],
        lignes: [
          for (final j in stats.parJour)
            [
              DateFormat('EEE dd/MM/yyyy', 'fr_FR').format(j.date),
              '${j.comptes.total}',
              '${j.comptes.fait}',
              '${j.comptes.absent}',
              '${j.comptes.refus}',
              pourcentage(j.comptes.taux),
            ],
        ],
      ),
    );

    final preposees = stats.parPreposee;
    final maxPreposee = preposees.isEmpty
        ? 0
        : preposees.map((p) => p.comptes.total).reduce((a, b) => a > b ? a : b);
    final parPreposee = CarteStatistique(
      titre: 'Par préposée | ${preposees.length}',
      graphique: (_) => BarresHorizontales(
        vide: 'Aucune préposée sur la période.',
        maximum: maxPreposee,
        legende: [
          (libelle: 'Fait', couleur: couleurStatut(StatutTache.fait)),
          (libelle: 'Absent', couleur: couleurStatut(StatutTache.absent)),
          (libelle: 'Refus', couleur: couleurStatut(StatutTache.refus)),
          (
            libelle: 'Non commencé',
            couleur: couleurStatut(StatutTache.nonCommence)
          ),
        ],
        lignes: [
          for (final p in preposees)
            (
              libelle: p.nom,
              detail: '${p.comptes.fait}/${p.comptes.total}',
              valeur: pourcentage(p.comptes.taux),
              segments: [
                for (final s in const [
                  StatutTache.fait,
                  StatutTache.absent,
                  StatutTache.refus,
                  StatutTache.nonCommence,
                  StatutTache.annule,
                ])
                  (valeur: p.comptes.de(s), couleur: couleurStatut(s)),
              ],
            ),
        ],
      ),
      tableau: (_) => TableauStat(
        vide: 'Aucune préposée sur la période.',
        entetes: const [
          'Préposée',
          'Planifiés',
          'Faits',
          'Absents',
          'Refus',
          'Réalisation',
        ],
        lignes: [
          for (final p in preposees)
            [
              p.nom,
              '${p.comptes.total}',
              '${p.comptes.fait}',
              '${p.comptes.absent}',
              '${p.comptes.refus}',
              pourcentage(p.comptes.taux),
            ],
        ],
      ),
    );

    final aSurveiller = stats.appartementsASurveiller;
    final top = aSurveiller.take(10).toList();
    final maxAppt = top.isEmpty ? 0 : top.first.comptes.problemes;
    final appartements = CarteStatistique(
      titre: 'Appartements à surveiller | ${aSurveiller.length}',
      graphique: (_) => BarresHorizontales(
        vide: 'Aucune absence ni aucun refus sur la période.',
        maximum: maxAppt,
        legende: [
          (libelle: 'Absent', couleur: couleurStatut(StatutTache.absent)),
          (libelle: 'Refus', couleur: couleurStatut(StatutTache.refus)),
        ],
        lignes: [
          for (final a in top)
            (
              libelle: 'Apt ${a.numero}',
              detail: a.taille.isEmpty ? null : a.taille,
              valeur: '${a.comptes.problemes}',
              segments: [
                (
                  valeur: a.comptes.absent,
                  couleur: couleurStatut(StatutTache.absent)
                ),
                (
                  valeur: a.comptes.refus,
                  couleur: couleurStatut(StatutTache.refus)
                ),
              ],
            ),
        ],
      ),
      tableau: (_) => TableauStat(
        vide: 'Aucune absence ni aucun refus sur la période.',
        entetes: const ['Appartement', 'Planifiés', 'Absents', 'Refus'],
        lignes: [
          for (final a in aSurveiller)
            [
              a.taille.isEmpty
                  ? 'Apt ${a.numero}'
                  : 'Apt ${a.numero} · ${a.taille}',
              '${a.comptes.total}',
              '${a.comptes.absent}',
              '${a.comptes.refus}',
            ],
        ],
      ),
    );

    return LayoutBuilder(builder: (context, contraintes) {
      final deux = contraintes.maxWidth >= 900;
      Widget paire(Widget a, Widget b) => deux
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: a),
                const SizedBox(width: 24),
                Expanded(child: b),
              ],
            )
          : Column(
              children: [a, const SizedBox(height: AppSizes.md), b],
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BandeauTotal(stats: stats),
          const SizedBox(height: 24),
          paire(realises, nonRealises),
          const SizedBox(height: 24),
          parJour,
          const SizedBox(height: 24),
          paire(parPreposee, appartements),
        ],
      );
    });
  }

  static String _part(int n, int total) =>
      total == 0 ? '—' : pourcentage(n * 100 / total);
}

// ── Bandeau du total ───────────────────────────────────────

class _BandeauTotal extends StatelessWidget {
  final StatistiquesMenages stats;
  const _BandeauTotal({required this.stats});

  @override
  Widget build(BuildContext context) {
    final c = stats.comptes;
    final compact = estCompact(context);
    Widget indicateur(String libelle, String valeur, Color couleur) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text.rich(
            TextSpan(
              text: '$libelle  ',
              style: const TextStyle(fontSize: 12.5, color: AppColors.grisDark),
              children: [
                TextSpan(
                  text: valeur,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: couleur),
                ),
              ],
            ),
          ),
        );

    return CarteContenu(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              text: 'TOTAL DES MÉNAGES PLANIFIÉS : ',
              style: TextStyle(
                fontSize: compact ? 14 : 17,
                fontWeight: FontWeight.w700,
                color: AppColors.grisDark,
              ),
              children: [
                TextSpan(
                  text: '${c.total}',
                  style: TextStyle(
                    fontSize: compact ? 19 : 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.rouge,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              indicateur('Réalisation', pourcentage(c.taux), AppColors.rouge),
              indicateur('Faits', '${c.fait}', AppColors.fait),
              indicateur('Absents', '${c.absent}', AppColors.absent),
              indicateur('Refus', '${c.refus}', AppColors.refus),
              if (c.annule > 0)
                indicateur('Annulés', '${c.annule}', AppColors.annule),
              if (stats.ajoutes > 0)
                indicateur('Ajoutés au planning', '${stats.ajoutes}',
                    AppColors.grisDark),
            ],
          ),
        ],
      ),
    );
  }
}
