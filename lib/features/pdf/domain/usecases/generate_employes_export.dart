import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../auth/domain/entities/employee.dart';

class GenerateEmployesPdf {
  const GenerateEmployesPdf();

  Future<Uint8List> call({
    required List<Employee> employees,
    required String filterDescription,
    required String generatedBy,
  }) async {
    final document = pw.Document(
      title: 'Liste des employés',
      author: generatedBy,
      creator: 'CleanOps',
    );
    final sorted = [...employees]
      ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));
    final activeCount = sorted.where((employee) => employee.isActif).length;
    final primary = PdfColor.fromHex('#3732C9');
    final border = PdfColor.fromHex('#D9DDE7');
    final muted = PdfColor.fromHex('#667085');
    final background = PdfColor.fromHex('#F7F8FA');

    pw.Widget headerCell(String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        child: pw.Text(
          value,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 8.5,
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
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: pw.Text(
          value,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
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
                      'Liste des employés',
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
                'Employés',
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
                'Inactifs',
                '${sorted.length - activeCount}',
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
                'Aucun employé ne correspond aux filtres sélectionnés.',
                style: pw.TextStyle(fontSize: 10, color: muted),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: border, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.55),
                1: pw.FlexColumnWidth(2.2),
                2: pw.FlexColumnWidth(1.6),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primary),
                  children: [
                    headerCell('N°'),
                    headerCell('Nom complet'),
                    headerCell('Rôle'),
                    headerCell('Statut'),
                    headerCell('Pointeuse'),
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
                          cell(_roleLabel(entry.value.role)),
                          cell(
                            entry.value.isActif ? 'Actif' : 'Inactif',
                            align: pw.TextAlign.center,
                          ),
                          cell(
                            entry.value.numeroPointeuse ?? '—',
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

  static pw.Widget _summaryCard(
    String label,
    String value,
    PdfColor background,
    PdfColor border,
    PdfColor muted,
  ) {
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
}

class GenerateEmployesExcel {
  const GenerateEmployesExcel();

  void call({
    required List<Employee> employees,
    required String filterDescription,
  }) {
    final excel = Excel.createExcel();
    const sheetName = 'Employés';
    final sheet = excel[sheetName];
    excel.delete('Sheet1');
    excel.setDefaultSheet(sheetName);
    final sorted = [...employees]
      ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));

    sheet.appendRow([
      TextCellValue('Prénom'),
      TextCellValue('Nom'),
      TextCellValue('Rôle'),
      TextCellValue('Statut'),
      TextCellValue('Numéro de pointeuse'),
      TextCellValue('Filtre appliqué'),
    ]);
    for (final employee in sorted) {
      sheet.appendRow([
        TextCellValue(employee.prenom),
        TextCellValue(employee.nom),
        TextCellValue(_roleLabel(employee.role)),
        TextCellValue(employee.isActif ? 'Actif' : 'Inactif'),
        TextCellValue(employee.numeroPointeuse ?? ''),
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
    const widths = [20.0, 22.0, 24.0, 14.0, 23.0, 34.0];
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

    excel.save(fileName: 'liste-employes.xlsx');
  }
}

String _roleLabel(RoleType role) {
  return switch (role) {
    RoleType.employe => 'Préposé(e)',
    RoleType.superviseurMenage => 'Superviseur ménage',
    RoleType.direction => 'Direction',
    RoleType.reception => 'Réception',
    RoleType.admin => 'Administration',
    RoleType.resident => 'Résident',
  };
}
