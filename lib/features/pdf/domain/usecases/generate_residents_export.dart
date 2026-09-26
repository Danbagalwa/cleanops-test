import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../modele_pdf.dart';

import '../../../residents/domain/entities/resident.dart';

class GenerateResidentsPdf {
  const GenerateResidentsPdf();

  Future<Uint8List> call({
    required List<Resident> residents,
    required String filterDescription,
    required String generatedBy,
  }) async {
    const titre = 'Liste des résidents';
    final document =
        await ModelePdf.document(titre: titre, auteur: generatedBy);
    final sorted = [...residents]
      ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));
    final activeCount = sorted.where((resident) => resident.isActif).length;
    final registeredCount = sorted
        .where((resident) => resident.isActif && resident.aApplication)
        .length;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 28),
        header: (context) => ModelePdf.enTete(
          context,
          titre: titre,
          sousTitre: filterDescription,
          infos: ModelePdf.infosGeneration(generatedBy),
        ),
        footer: ModelePdf.piedDePage,
        build: (context) => [
          ModelePdf.chiffresCles([
            ('Résidents', '${sorted.length}'),
            ('Actifs', '$activeCount'),
            ('Avec application', '$registeredCount'),
            ('Sans application', '${activeCount - registeredCount}'),
          ]),
          pw.SizedBox(height: 16),
          if (sorted.isEmpty)
            ModelePdf.etatVide(
                'Aucun résident ne correspond aux filtres sélectionnés.')
          else
            ModelePdf.tableau(
              entetes: const [
                'N°',
                'Nom complet',
                'Appartement',
                'Taille',
                'Statut',
                'Application',
                'Inscription',
              ],
              largeurs: const {
                0: pw.FlexColumnWidth(0.45),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(0.9),
                4: pw.FlexColumnWidth(1),
                5: pw.FlexColumnWidth(1.1),
                6: pw.FlexColumnWidth(1.1),
              },
              centrees: const {0, 2, 3, 4, 5, 6},
              accentuees: const {1},
              lignes: [
                for (final (i, r) in sorted.indexed)
                  [
                    '${i + 1}',
                    r.nomComplet,
                    r.numeroAppartement,
                    r.tailleAppartement,
                    r.isActif ? 'Actif' : 'Inactif',
                    r.aApplication ? 'Oui' : 'Non',
                    DateFormat('dd/MM/yyyy').format(r.dateCreation),
                  ],
              ],
            ),
          pw.SizedBox(height: 10),
          ModelePdf.note(
            'Document confidentiel — aucune donnée d’authentification '
            'n’est incluse.',
          ),
        ],
      ),
    );

    return document.save();
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
