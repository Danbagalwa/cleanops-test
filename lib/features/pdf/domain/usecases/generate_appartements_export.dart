import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../modele_pdf.dart';

import '../../../appartements/domain/entities/appartement.dart';

class GenerateAppartementsPdf {
  const GenerateAppartementsPdf();

  Future<Uint8List> call({
    required List<Appartement> appartements,
    required String filterDescription,
    required String generatedBy,
  }) async {
    const titre = 'Liste des appartements';
    final document =
        await ModelePdf.document(titre: titre, auteur: generatedBy);
    final sorted = [...appartements]
      ..sort((a, b) => a.numero.compareTo(b.numero));
    final totalMinutes = sorted.fold<int>(
      0,
      (total, appartement) => total + appartement.minutesBase,
    );
    final average = sorted.isEmpty ? 0 : (totalMinutes / sorted.length).round();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 30),
        header: (context) => ModelePdf.enTete(
          context,
          titre: titre,
          sousTitre: filterDescription,
          infos: ModelePdf.infosGeneration(generatedBy),
        ),
        footer: ModelePdf.piedDePage,
        build: (context) => [
          ModelePdf.chiffresCles([
            ('Appartements', '${sorted.length}'),
            ('Durée totale', ModelePdf.duree(totalMinutes) ?? ModelePdf.vide),
            ('Durée moyenne', ModelePdf.duree(average) ?? ModelePdf.vide),
          ]),
          pw.SizedBox(height: 16),
          if (sorted.isEmpty)
            ModelePdf.etatVide(
                'Aucun appartement ne correspond aux filtres sélectionnés.')
          else
            ModelePdf.tableau(
              entetes: const ['N°', 'Appartement', 'Taille', 'Durée de base'],
              largeurs: const {
                0: pw.FlexColumnWidth(0.6),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FlexColumnWidth(1.2),
              },
              centrees: const {0, 2, 3},
              accentuees: const {1},
              lignes: [
                for (final (i, a) in sorted.indexed)
                  [
                    '${i + 1}',
                    'Appartement ${a.numero}',
                    a.taille,
                    ModelePdf.duree(a.minutesBase),
                  ],
              ],
            ),
        ],
      ),
    );

    return document.save();
  }
}

class GenerateAppartementsExcel {
  const GenerateAppartementsExcel();

  void call({
    required List<Appartement> appartements,
    required String filterDescription,
  }) {
    final excel = Excel.createExcel();
    const sheetName = 'Appartements';
    final sheet = excel[sheetName];
    excel.delete('Sheet1');
    excel.setDefaultSheet(sheetName);
    final sorted = [...appartements]
      ..sort((a, b) => a.numero.compareTo(b.numero));

    sheet.appendRow([
      TextCellValue('Numéro'),
      TextCellValue('Taille'),
      TextCellValue('Durée de référence (min)'),
      TextCellValue('Filtre appliqué'),
    ]);
    for (final appartement in sorted) {
      sheet.appendRow([
        TextCellValue(appartement.numero),
        TextCellValue(appartement.taille),
        IntCellValue(appartement.minutesBase),
        TextCellValue(filterDescription),
      ]);
    }

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#3732C9'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final bodyStyle = CellStyle(
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );
    const widths = [18.0, 15.0, 26.0, 34.0];
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }
    for (var row = 0; row < sheet.maxRows; row++) {
      for (var column = 0; column < sheet.maxColumns; column++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: column,
                rowIndex: row,
              ),
            )
            .cellStyle = row == 0 ? headerStyle : bodyStyle;
      }
    }

    excel.save(fileName: 'liste-appartements.xlsx');
  }
}
