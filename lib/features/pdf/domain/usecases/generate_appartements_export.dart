import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../appartements/domain/entities/appartement.dart';

class GenerateAppartementsPdf {
  const GenerateAppartementsPdf();

  Future<Uint8List> call({
    required List<Appartement> appartements,
    required String filterDescription,
    required String generatedBy,
  }) async {
    final document = pw.Document(
      title: 'Liste des appartements',
      author: generatedBy,
      creator: 'CleanOps',
    );
    final sorted = [...appartements]
      ..sort((a, b) => a.numero.compareTo(b.numero));
    final totalMinutes = sorted.fold<int>(
      0,
      (total, appartement) => total + appartement.minutesBase,
    );
    final average = sorted.isEmpty ? 0 : (totalMinutes / sorted.length).round();
    final primary = PdfColor.fromHex('#3732C9');
    final border = PdfColor.fromHex('#D9DDE7');
    final muted = PdfColor.fromHex('#667085');
    final background = PdfColor.fromHex('#F7F8FA');

    pw.Widget cell(
      String value, {
      bool bold = false,
      pw.TextAlign align = pw.TextAlign.left,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(
          value,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    pw.Widget headerCell(String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: pw.Text(
          value,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 34),
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
                      'Liste des appartements',
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
                label: 'Appartements',
                value: '${sorted.length}',
                background: background,
                border: border,
                muted: muted,
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                label: 'Durée totale',
                value: _duration(totalMinutes),
                background: background,
                border: border,
                muted: muted,
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                label: 'Durée moyenne',
                value: '$average min',
                background: background,
                border: border,
                muted: muted,
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
                'Aucun appartement ne correspond aux filtres sélectionnés.',
                style: pw.TextStyle(fontSize: 10, color: muted),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: border, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.7),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primary),
                  children: [
                    headerCell('N°'),
                    headerCell('Appartement'),
                    headerCell('Taille'),
                    headerCell('Durée'),
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
                          cell(
                            'Appartement ${entry.value.numero}',
                            bold: true,
                          ),
                          cell(
                            entry.value.taille,
                            align: pw.TextAlign.center,
                          ),
                          cell(
                            '${entry.value.minutesBase} min',
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
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _summaryCard({
    required String label,
    required String value,
    required PdfColor background,
    required PdfColor border,
    required PdfColor muted,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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

  static String _duration(int minutes) {
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (hours == 0) return '$remaining min';
    if (remaining == 0) return '${hours}h';
    return '${hours}h${remaining.toString().padLeft(2, '0')}';
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
