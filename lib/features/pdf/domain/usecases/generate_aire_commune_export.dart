import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../modele_pdf.dart';

import '../../../aire_commune/domain/entities/tache_aire_commune.dart';

/// Zones triées par catégorie (ordre de l'app) puis par nom.
List<TacheAireCommune> _trier(List<TacheAireCommune> zones) =>
    [...zones]..sort((a, b) {
        final c = a.categorie.index.compareTo(b.categorie.index);
        return c != 0 ? c : comparerZones(a.zone, b.zone);
      });

String? _confirmeeLe(TacheAireCommune t) => t.confirmeLE == null
    ? null
    : DateFormat('EEE d MMM HH:mm', 'fr_FR').format(t.confirmeLE!.toLocal());

class GenerateAireCommunePdf {
  const GenerateAireCommunePdf();

  Future<Uint8List> call({
    required List<TacheAireCommune> zones,
    required String semaine,
    required String filtres,
    required String generatedBy,
  }) async {
    const titre = 'Entretien des aires communes';
    final document =
        await ModelePdf.document(titre: titre, auteur: generatedBy);
    final lignes = _trier(zones);
    final faites = lignes.where((t) => t.estFait).length;
    final pct = lignes.isEmpty ? 0 : (faites * 100 / lignes.length).round();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 30),
        header: (context) => ModelePdf.enTete(
          context,
          titre: titre,
          sousTitre: filtres.isEmpty ? semaine : '$semaine — $filtres',
          infos: ModelePdf.infosGeneration(generatedBy),
        ),
        footer: ModelePdf.piedDePage,
        build: (context) => [
          ModelePdf.chiffresCles([
            ('Zones', '${lignes.length}'),
            ('Confirmées', '$faites'),
            ('À confirmer', '${lignes.length - faites}'),
            ('Avancement', '$pct %'),
          ]),
          pw.SizedBox(height: 16),
          if (lignes.isEmpty)
            ModelePdf.etatVide('Aucune zone ne correspond aux filtres.')
          else
            ModelePdf.tableau(
              entetes: const [
                'N°',
                'Catégorie',
                'Zone',
                'Statut',
                'Confirmée par',
                'Le',
              ],
              largeurs: const {
                0: pw.FlexColumnWidth(0.5),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(1.1),
                4: pw.FlexColumnWidth(1.3),
                5: pw.FlexColumnWidth(1.4),
              },
              centrees: const {0, 3},
              accentuees: const {2},
              lignes: [
                for (final (i, t) in lignes.indexed)
                  [
                    '${i + 1}',
                    t.categorie.libelle,
                    formatZoneAire(t.zone),
                    t.estFait ? 'Confirmée' : 'À confirmer',
                    t.confirmeParPrenom,
                    _confirmeeLe(t),
                  ],
              ],
            ),
        ],
      ),
    );

    return document.save();
  }
}

class GenerateAireCommuneExcel {
  const GenerateAireCommuneExcel();

  void call({
    required List<TacheAireCommune> zones,
    required String semaine,
    required String nomFichier,
  }) {
    final excel = Excel.createExcel();
    const feuille = 'Aires communes';
    excel.setDefaultSheet(feuille);
    final sheet = excel[feuille];
    const entetes = [
      'Catégorie',
      'Zone',
      'Statut',
      'Confirmée par',
      'Confirmée le',
      'Semaine',
    ];
    sheet.appendRow([for (final e in entetes) TextCellValue(e)]);
    for (final t in _trier(zones)) {
      sheet.appendRow([
        TextCellValue(t.categorie.libelle),
        TextCellValue(formatZoneAire(t.zone)),
        TextCellValue(t.estFait ? 'Confirmée' : 'À confirmer'),
        TextCellValue(t.confirmeParPrenom ?? ''),
        TextCellValue(t.confirmeLE == null
            ? ''
            : DateFormat('dd/MM/yyyy HH:mm').format(t.confirmeLE!.toLocal())),
        TextCellValue(semaine),
      ]);
    }

    final styleEntete = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#3732C9'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final styleCorps = CellStyle(
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );
    const largeurs = [16.0, 26.0, 14.0, 18.0, 18.0, 28.0];
    for (var c = 0; c < largeurs.length; c++) {
      sheet.setColumnWidth(c, largeurs[c]);
    }
    for (var r = 0; r < sheet.maxRows; r++) {
      for (var c = 0; c < entetes.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .cellStyle = r == 0 ? styleEntete : styleCorps;
      }
    }
    excel.delete('Sheet1');
    excel.save(fileName: nomFichier);
  }
}
