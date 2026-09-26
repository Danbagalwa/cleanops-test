import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart' show StatutTache;
import '../../domain/entities/statistiques_menages.dart';

// ── Couleurs et libellés des statuts ───────────────────────

const couleurMatin = Color(0xFF5DB2EC);
const couleurApresMidi = Color(0xFF3732C9);

Color couleurStatut(StatutTache s) => switch (s) {
      StatutTache.fait => AppColors.fait,
      StatutTache.nonCommence => const Color(0xFFB4BAC6),
      StatutTache.absent => const Color(0xFF5DB2EC),
      StatutTache.refus => const Color(0xFFF58A9E),
      StatutTache.annule => const Color(0xFF757575),
    };

String libelleStatut(StatutTache s) => switch (s) {
      StatutTache.fait => 'Fait',
      StatutTache.nonCommence => 'Non commencé',
      StatutTache.absent => 'Absent',
      StatutTache.refus => 'Refus',
      StatutTache.annule => 'Annulé',
    };

String pourcentage(double v) => '${v.round()} %';

// ── Carte à deux vues (graphique / tableau) ────────────────

/// Carte titrée avec un menu ⋮ pour passer du graphique au tableau.
class CarteStatistique extends StatefulWidget {
  final String titre;
  final WidgetBuilder graphique;
  final WidgetBuilder tableau;

  /// Hauteur du graphique (le tableau prend sa hauteur naturelle).
  final double hauteur;

  const CarteStatistique({
    super.key,
    required this.titre,
    required this.graphique,
    required this.tableau,
    this.hauteur = 320,
  });

  @override
  State<CarteStatistique> createState() => _CarteStatistiqueState();
}

class _CarteStatistiqueState extends State<CarteStatistique> {
  bool _tableau = false;

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 6, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.titre.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.noir,
                    ),
                  ),
                ),
                PopupMenuButton<bool>(
                  tooltip: 'Options',
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.rouge),
                  onSelected: (t) => setState(() => _tableau = t),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: false,
                      enabled: _tableau,
                      child: const Row(
                        children: [
                          Icon(Icons.pie_chart_outline_rounded,
                              size: 18, color: AppColors.rouge),
                          SizedBox(width: 10),
                          Text('Afficher le graphique'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: true,
                      enabled: !_tableau,
                      child: const Row(
                        children: [
                          Icon(Icons.table_rows_outlined,
                              size: 18, color: AppColors.rouge),
                          SizedBox(width: 10),
                          Text('Afficher le tableau'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.grisMedium),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _tableau
                ? KeyedSubtree(
                    key: const ValueKey('tableau'),
                    child: widget.tableau(context),
                  )
                : Padding(
                    key: const ValueKey('graphique'),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: SizedBox(
                      height: widget.hauteur,
                      child: widget.graphique(context),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Camembert ──────────────────────────────────────────────

typedef PartCamembert = ({String libelle, int valeur, Color couleur});

class Camembert extends StatelessWidget {
  final List<PartCamembert> parts;
  final String vide;

  const Camembert({super.key, required this.parts, required this.vide});

  @override
  Widget build(BuildContext context) {
    final total = parts.fold<int>(0, (s, p) => s + p.valeur);
    if (total == 0) return MessageVide(vide);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final rayon = math.min(c.maxWidth, c.maxHeight) / 2 - 4;
            return PieChart(
              PieChartData(
                centerSpaceRadius: 0,
                sectionsSpace: 1.5,
                startDegreeOffset: -90,
                sections: [
                  for (final p in parts)
                    if (p.valeur > 0)
                      PieChartSectionData(
                        value: p.valeur.toDouble(),
                        color: p.couleur,
                        radius: rayon,
                        title: '${(p.valeur * 100 / total).round()}%',
                        showTitle: p.valeur * 100 / total >= 4,
                        titlePositionPercentageOffset: 0.62,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Legende([
          for (final p in parts)
            (libelle: '${p.libelle} (${p.valeur})', couleur: p.couleur),
        ]),
      ],
    );
  }
}

class Legende extends StatelessWidget {
  final List<({String libelle, Color couleur})> entrees;
  const Legende(this.entrees, {super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final e in entrees)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 10,
                decoration: BoxDecoration(
                  color: e.couleur,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(e.libelle,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.grisDark)),
            ],
          ),
      ],
    );
  }
}

class MessageVide extends StatelessWidget {
  final String texte;
  const MessageVide(this.texte, {super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.donut_large_rounded,
                size: 40, color: AppColors.grisMedium),
            const SizedBox(height: 10),
            Text(texte,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.grisText)),
          ],
        ),
      );
}

// ── Tableau simple ─────────────────────────────────────────

/// Tableau compact : première colonne à gauche, les autres centrées.
class TableauStat extends StatelessWidget {
  final List<String> entetes;
  final List<List<String>> lignes;
  final String vide;

  /// Poids de la première colonne par rapport aux autres.
  final int poidsPremiere;

  const TableauStat({
    super.key,
    required this.entetes,
    required this.lignes,
    required this.vide,
    this.poidsPremiere = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (lignes.isEmpty) {
      return SizedBox(height: 160, child: MessageVide(vide));
    }
    const styleEntete = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.grisDark);
    Widget ligne(List<String> cellules, {required bool entete}) => Row(
          children: [
            for (final (i, c) in cellules.indexed)
              Expanded(
                flex: i == 0 ? poidsPremiere : 2,
                child: Text(
                  c,
                  textAlign: i == 0 ? TextAlign.left : TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: entete
                      ? styleEntete
                      : TextStyle(
                          fontSize: 13,
                          fontWeight:
                              i == 0 ? FontWeight.w600 : FontWeight.normal,
                          color: AppColors.noir,
                        ),
                ),
              ),
          ],
        );
    return Column(
      children: [
        Container(
          color: const Color(0xFFF7F8FA),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: ligne(entetes, entete: true),
        ),
        for (final l in lignes) ...[
          const Divider(height: 1, color: AppColors.grisMedium),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ligne(l, entete: false),
          ),
        ],
      ],
    );
  }
}

// ── Réalisation par jour (barres empilées) ─────────────────

class GraphiqueParJour extends StatelessWidget {
  final List<StatJour> jours;
  const GraphiqueParJour({super.key, required this.jours});

  static const _ordre = [
    StatutTache.fait,
    StatutTache.nonCommence,
    StatutTache.absent,
    StatutTache.refus,
    StatutTache.annule,
  ];

  @override
  Widget build(BuildContext context) {
    if (jours.isEmpty) return const MessageVide('Aucun ménage sur la période.');
    final maxY = jours.map((j) => j.comptes.total).reduce(math.max).toDouble();
    final pas = maxY <= 5 ? 1.0 : (maxY / 5).ceilToDouble();
    final fmt = DateFormat('dd/MM');
    final fmtLong = DateFormat('EEEE d MMMM', 'fr_FR');
    // Une étiquette sur n quand les jours sont nombreux.
    final saut = math.max(1, (jours.length / 12).ceil());

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final largeur =
                ((c.maxWidth - 40) / jours.length * 0.6).clamp(4.0, 28.0);
            return BarChart(
              BarChartData(
                maxY: maxY + pas * 0.3,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: pas,
                  getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.grisMedium, strokeWidth: 0.8),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: pas,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text('${v.toInt()}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.grisText)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= jours.length || i % saut != 0) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(fmt.format(jours[i].date),
                              style: const TextStyle(
                                  fontSize: 10.5, color: AppColors.grisDark)),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.noir,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, _, __, ___) {
                      final j = jours[group.x];
                      final c = j.comptes;
                      final details = [
                        for (final s in _ordre)
                          if (c.de(s) > 0) '${libelleStatut(s)} : ${c.de(s)}',
                      ].join('\n');
                      return BarTooltipItem(
                        '${fmtLong.format(j.date)}\n',
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                        children: [
                          TextSpan(
                            text: '$details\nRéalisation : '
                                '${pourcentage(c.taux)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                                fontSize: 11.5),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (final (i, j) in jours.indexed)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: j.comptes.total.toDouble(),
                          width: largeur,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3)),
                          rodStackItems: _pile(j.comptes),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Legende([
          for (final s in _ordre)
            (libelle: libelleStatut(s), couleur: couleurStatut(s)),
        ]),
      ],
    );
  }

  static List<BarChartRodStackItem> _pile(Comptes c) {
    var bas = 0.0;
    return [
      for (final s in _ordre)
        if (c.de(s) > 0)
          () {
            final item =
                BarChartRodStackItem(bas, bas + c.de(s), couleurStatut(s));
            bas += c.de(s);
            return item;
          }(),
    ];
  }
}

// ── Barres horizontales (préposées, appartements) ──────────

/// Une ligne : libellé, barre découpée en segments, valeur à droite.
typedef LigneBarre = ({
  String libelle,
  String? detail,
  List<({int valeur, Color couleur})> segments,
  String valeur,
});

class BarresHorizontales extends StatelessWidget {
  final List<LigneBarre> lignes;

  /// Valeur qui remplit toute la barre.
  final int maximum;
  final String vide;
  final List<({String libelle, Color couleur})> legende;

  const BarresHorizontales({
    super.key,
    required this.lignes,
    required this.maximum,
    required this.vide,
    required this.legende,
  });

  @override
  Widget build(BuildContext context) {
    if (lignes.isEmpty) return MessageVide(vide);
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: lignes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _Barre(ligne: lignes[i], maximum: maximum),
          ),
        ),
        const SizedBox(height: 12),
        Legende(legende),
      ],
    );
  }
}

class _Barre extends StatelessWidget {
  final LigneBarre ligne;
  final int maximum;
  const _Barre({required this.ligne, required this.maximum});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: ligne.libelle,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.noir),
                  children: [
                    if (ligne.detail != null)
                      TextSpan(
                        text: '  ${ligne.detail}',
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: AppColors.grisText),
                      ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(ligne.valeur,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grisDark)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            child: LayoutBuilder(builder: (context, c) {
              return Stack(
                children: [
                  Container(color: const Color(0xFFF0F1F5)),
                  Row(
                    children: [
                      for (final s in ligne.segments)
                        if (s.valeur > 0 && maximum > 0)
                          Container(
                            width: c.maxWidth * s.valeur / maximum,
                            color: s.couleur,
                          ),
                    ],
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
