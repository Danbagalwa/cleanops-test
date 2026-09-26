import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../modele_pdf.dart';

import '../../../auth/domain/entities/employee.dart';

class GenerateEmployesPdf {
  const GenerateEmployesPdf();

  Future<Uint8List> call({
    required List<Employee> employees,
    required String filterDescription,
    required String generatedBy,
  }) async {
    const titre = 'Liste des employés';
    final document =
        await ModelePdf.document(titre: titre, auteur: generatedBy);
    final sorted = [...employees]
      ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));
    final activeCount = sorted.where((employee) => employee.isActif).length;

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
            ('Employés', '${sorted.length}'),
            ('Actifs', '$activeCount'),
            ('Inactifs', '${sorted.length - activeCount}'),
          ]),
          pw.SizedBox(height: 16),
          if (sorted.isEmpty)
            ModelePdf.etatVide(
                'Aucun employé ne correspond aux filtres sélectionnés.')
          else
            ModelePdf.tableau(
              entetes: const [
                'N°',
                'Nom complet',
                'Rôle',
                'Statut',
                'Pointeuse',
              ],
              largeurs: const {
                0: pw.FlexColumnWidth(0.55),
                1: pw.FlexColumnWidth(2.2),
                2: pw.FlexColumnWidth(1.6),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(1.2),
              },
              centrees: const {0, 3, 4},
              accentuees: const {1},
              lignes: [
                for (final (i, e) in sorted.indexed)
                  [
                    '${i + 1}',
                    e.nomComplet,
                    _roleLabel(e.role),
                    e.isActif ? 'Actif' : 'Inactif',
                    e.numeroPointeuse,
                  ],
              ],
            ),
        ],
      ),
    );

    return document.save();
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
