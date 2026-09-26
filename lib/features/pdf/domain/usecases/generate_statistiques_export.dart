import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../modele_pdf.dart';

import '../../../statistiques/domain/entities/statistiques_menages.dart';

final _date = DateFormat('dd/MM/yyyy');
final _jour = DateFormat('EEE dd/MM', 'fr_FR');

String _pct(double v) => '${v.round()} %';

/// Libellé de la période exportée.
String periodeStatistiques(StatistiquesMenages s) =>
    'Du ${_date.format(s.dateDebut)} au ${_date.format(s.dateFin)} '
    '(${s.nbJours} jour${s.nbJours > 1 ? 's' : ''})';

class GenerateStatistiquesPdf {
  const GenerateStatistiquesPdf();

  Future<Uint8List> call({
    required StatistiquesMenages stats,
    required String filtres,
    required String generatedBy,
  }) async {
    const titre = 'Chiffres clés des ménages';
    final document =
        await ModelePdf.document(titre: titre, auteur: generatedBy);
    final c = stats.comptes;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 28),
        header: (context) => ModelePdf.enTete(
          context,
          titre: titre,
          sousTitre: '${periodeStatistiques(stats)} · $filtres',
          infos: ModelePdf.infosGeneration(generatedBy),
        ),
        footer: ModelePdf.piedDePage,
        build: (context) => [
          ModelePdf.chiffresCles([
            ('Planifiés', '${c.total}'),
            ('Faits', '${c.fait}'),
            ('Réalisation', _pct(c.taux)),
            ('Absents', '${c.absent}'),
            ('Refus', '${c.refus}'),
          ]),
          pw.SizedBox(height: 14),
          if (stats.menages.isEmpty)
            ModelePdf.etatVide('Aucun ménage sur cette période.')
          else ...[
            ModelePdf.titreSection('Par préposée'),
            ModelePdf.tableau(
              entetes: const [
                'Préposée',
                'Planifiés',
                'Faits',
                'Absents',
                'Refus',
                'Annulés',
                'Réalisation',
              ],
              largeurs: const {0: pw.FlexColumnWidth(2.2)},
              centrees: const {1, 2, 3, 4, 5, 6},
              accentuees: const {0},
              lignes: [
                for (final p in stats.parPreposee)
                  [
                    p.nom,
                    '${p.comptes.total}',
                    '${p.comptes.fait}',
                    '${p.comptes.absent}',
                    '${p.comptes.refus}',
                    '${p.comptes.annule}',
                    _pct(p.comptes.taux),
                  ],
              ],
            ),
            pw.SizedBox(height: 14),
            ModelePdf.titreSection('Par jour'),
            ModelePdf.tableau(
              entetes: const [
                'Jour',
                'Planifiés',
                'Faits',
                'Non commencés',
                'Absents',
                'Refus',
                'Réalisation',
              ],
              largeurs: const {0: pw.FlexColumnWidth(1.6)},
              centrees: const {1, 2, 3, 4, 5, 6},
              lignes: [
                for (final j in stats.parJour)
                  [
                    _jour.format(j.date),
                    '${j.comptes.total}',
                    '${j.comptes.fait}',
                    '${j.comptes.nonCommence}',
                    '${j.comptes.absent}',
                    '${j.comptes.refus}',
                    _pct(j.comptes.taux),
                  ],
              ],
            ),
            if (stats.appartementsASurveiller.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              ModelePdf.titreSection('Appartements à surveiller'),
              ModelePdf.tableau(
                entetes: const [
                  'Appartement',
                  'Taille',
                  'Planifiés',
                  'Absents',
                  'Refus',
                ],
                centrees: const {2, 3, 4},
                accentuees: const {0},
                lignes: [
                  for (final a in stats.appartementsASurveiller)
                    [
                      'Apt ${a.numero}',
                      a.taille,
                      '${a.comptes.total}',
                      '${a.comptes.absent}',
                      '${a.comptes.refus}',
                    ],
                ],
              ),
            ],
          ],
        ],
      ),
    );

    return document.save();
  }
}

class GenerateStatistiquesExcel {
  const GenerateStatistiquesExcel();

  void call({
    required StatistiquesMenages stats,
    required String filtres,
  }) {
    final excel = Excel.createExcel();
    final styleEntete = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#3732C9'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    void feuille(String nom, List<String> entetes, List<List<Object>> lignes,
        List<double> largeurs) {
      final sheet = excel[nom];
      sheet.appendRow([for (final e in entetes) TextCellValue(e)]);
      for (final l in lignes) {
        sheet.appendRow([
          for (final v in l)
            v is int ? IntCellValue(v) : TextCellValue(v.toString()),
        ]);
      }
      for (var c = 0; c < entetes.length; c++) {
        sheet.setColumnWidth(c, largeurs[c]);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
            .cellStyle = styleEntete;
      }
    }

    final c = stats.comptes;
    feuille(
      'Synthèse',
      const ['Indicateur', 'Valeur'],
      [
        ['Période', periodeStatistiques(stats)],
        ['Filtre', filtres],
        ['Ménages planifiés', c.total],
        ['Faits', c.fait],
        ['Non commencés', c.nonCommence],
        ['Absents', c.absent],
        ['Refus', c.refus],
        ['Annulés', c.annule],
        ['Taux de réalisation', _pct(c.taux)],
        ['Faits le matin', stats.faitsParPeriode.matin],
        ['Faits l’après-midi', stats.faitsParPeriode.apresMidi],
        ['Ajoutés au planning', stats.ajoutes],
      ],
      const [28, 40],
    );
    excel.setDefaultSheet('Synthèse');

    feuille(
      'Par préposée',
      const [
        'Préposée',
        'Planifiés',
        'Faits',
        'Non commencés',
        'Absents',
        'Refus',
        'Annulés',
        'Réalisation',
      ],
      [
        for (final p in stats.parPreposee)
          [
            p.nom,
            p.comptes.total,
            p.comptes.fait,
            p.comptes.nonCommence,
            p.comptes.absent,
            p.comptes.refus,
            p.comptes.annule,
            _pct(p.comptes.taux),
          ],
      ],
      const [26, 12, 10, 16, 10, 10, 10, 14],
    );

    feuille(
      'Par jour',
      const [
        'Date',
        'Planifiés',
        'Faits',
        'Non commencés',
        'Absents',
        'Refus',
        'Annulés',
        'Réalisation',
      ],
      [
        for (final j in stats.parJour)
          [
            _date.format(j.date),
            j.comptes.total,
            j.comptes.fait,
            j.comptes.nonCommence,
            j.comptes.absent,
            j.comptes.refus,
            j.comptes.annule,
            _pct(j.comptes.taux),
          ],
      ],
      const [14, 12, 10, 16, 10, 10, 10, 14],
    );

    feuille(
      'Appartements',
      const ['Appartement', 'Taille', 'Planifiés', 'Absents', 'Refus'],
      [
        for (final a in stats.appartementsASurveiller)
          [
            a.numero,
            a.taille,
            a.comptes.total,
            a.comptes.absent,
            a.comptes.refus,
          ],
      ],
      const [14, 12, 12, 10, 10],
    );

    excel.delete('Sheet1');
    excel.save(fileName: 'statistiques-menages.xlsx');
  }
}
