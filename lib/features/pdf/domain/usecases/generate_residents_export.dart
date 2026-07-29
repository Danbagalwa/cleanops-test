import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../residents/domain/entities/resident.dart';

class GenerateResidentsPdf {
  const GenerateResidentsPdf();

  Future<Uint8List> call({
    required List<Resident> residents,
    required String filterDescription,
    required String generatedBy,
  }) async {
    final document = pw.Document(
      title: 'Liste des résidents',
      author: generatedBy,
      creator: 'CleanOps',
    );
    final sorted = [...residents]
      ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));
    final activeCount = sorted.where((resident) => resident.isActif).length;
    final registeredCount =
        sorted.where((resident) => resident.isActif && resident.aApplication).length;
    final primary = PdfColor.fromHex('#3732C9');
    final border = PdfColor.fromHex('#D9DDE7');
    final muted = PdfColor.fromHex('#667085');
    final background = PdfColor.fromHex('#F7F8FA');

    pw.Widget headerCell(String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: pw.Text(
          value,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
    }

    pw.Widget cell(
      String value, {
      bool bold = false,
      pw.TextAlign align = pw.TextAlign.left,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: pw.Text(
          value,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 34),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 16),
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: border)),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 34,
                height: 34,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: primary,
                  borderRadius: pw.BorderRadius.circular(9),
                ),
                child: pw.Text(
                  'C',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Liste des résidents',
                      style: pw.TextStyle(
                        color: primary,
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      filterDescription,
                      style: pw.TextStyle(fontSize: 9, color: muted),
                    ),
                  ],
                ),
              ),
              pw.Text(
                'CLEANOPS',
                style: pw.TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: muted),
          ),
        ),
        build: (context) => [
          pw.Row(
            children: [
              _summaryCard(
                'Résidents',
                '${sorted.length}',
                background,
                border,
                muted,
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                'Actifs',
                '$activeCount',
                background,
                border,
                muted,
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                'Avec application',
                '$registeredCount',
                background,
                border,
                muted,
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                'Sans application',
                '${activeCount - registeredCount}',
                background,
                border,
                muted,
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          if (sorted.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(24),
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: background,
                border: pw.Border.all(color: border),
              ),
              child: pw.Text(
                'Aucun résident ne correspond aux filtres sélectionnés.',
                style: pw.TextStyle(fontSize: 10, color: muted),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: border, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.45),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(0.9),
                4: pw.FlexColumnWidth(1),
                5: pw.FlexColumnWidth(1.1),
                6: pw.FlexColumnWidth(1.1),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primary),
                  children: [
                    headerCell('N°'),
                    headerCell('Nom complet'),
                    headerCell('Appartement'),
                    headerCell('Taille'),
                    headerCell('Statut'),
                    headerCell('Application'),
                    headerCell('Inscription'),
                  ],
                ),
                ...sorted.asMap().entries.map(
                      (entry) => pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: entry.key.isOdd
                              ? background
                              : PdfColors.white,
                        ),
                        children: [
                          cell('${entry.key + 1}', align: pw.TextAlign.center),
                          cell(entry.value.nomComplet, bold: true),
                          cell(
                            entry.value.numeroAppartement ?? '—',
                            align: pw.TextAlign.center,
                          ),
                          cell(
                            entry.value.tailleAppartement ?? '—',
                            align: pw.TextAlign.center,
                          ),
                          cell(
                            entry.value.isActif ? 'Actif' : 'Inactif',
                            align: pw.TextAlign.center,
                          ),
                          cell(
                            entry.value.aApplication ? 'Oui' : 'Non',
                            align: pw.TextAlign.center,
                          ),
                          cell(
                            DateFormat('dd/MM/yyyy')
                                .format(entry.value.dateCreation),
                            align: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Généré le ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(DateTime.now())}'
            ' par $generatedBy',
            style: pw.TextStyle(fontSize: 8, color: muted),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Document confidentiel — aucune donnée d’authentification n’est incluse.',
            style: pw.TextStyle(fontSize: 8, color: muted),
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _summaryCard(
    String label,
    String value,
    PdfColor background,
    PdfColor border,
    PdfColor muted,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: pw.BoxDecoration(
          color: background,
          border: pw.Border.all(color: border),
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 8, color: muted)),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GenerateResidentsExcel {
  const GenerateResidentsExcel();

  void call({
    required List<Resident> residents,
    required String filterDescription,
  }) {
    final excel = Excel.createExcel();
    const sheetName = 'Résidents';
    final sheet = excel[sheetName];
    excel.delete('Sheet1');
    excel.setDefaultSheet(sheetName);
    final sorted = [...residents]
      ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));

    sheet.appendRow([
      TextCellValue('Prénom'),
      TextCellValue('Nom'),
      TextCellValue('Appartement'),
      TextCellValue('Taille'),
      TextCellValue('Statut'),
      TextCellValue('Utilise l’application'),
      TextCellValue('Date d’inscription'),
      TextCellValue('Filtre appliqué'),
    ]);
    for (final resident in sorted) {
      sheet.appendRow([
        TextCellValue(resident.prenom),
        TextCellValue(resident.nom),
        TextCellValue(resident.numeroAppartement ?? ''),
        TextCellValue(resident.tailleAppartement ?? ''),
        TextCellValue(resident.isActif ? 'Actif' : 'Inactif'),
        TextCellValue(resident.aApplication ? 'Oui' : 'Non'),
        DateCellValue(
          year: resident.dateCreation.year,
          month: resident.dateCreation.month,
          day: resident.dateCreation.day,
        ),
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
    const widths = [20.0, 22.0, 18.0, 14.0, 14.0, 24.0, 22.0, 34.0];
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

    excel.save(fileName: 'liste-residents.xlsx');
  }
}
