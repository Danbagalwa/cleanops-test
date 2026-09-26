import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../modele_pdf.dart';

import '../../../resident_espace/domain/entities/demande_resident.dart';
import '../../../resident_espace/presentation/widgets/demande_resident_elements.dart';

String _proposition(DemandeResident d) => propositionDemande(d) ?? '';

class GenerateDemandesResidentsPdf {
  const GenerateDemandesResidentsPdf();

  Future<Uint8List> call({
    required List<DemandeResident> demandes,
    required String filtres,
    required String generatedBy,
  }) async {
    const titre = 'Demandes des résidents';
    final document =
        await ModelePdf.document(titre: titre, auteur: generatedBy);
    int nb(bool Function(DemandeResident) test) => demandes.where(test).length;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 28),
        header: (context) => ModelePdf.enTete(
          context,
          titre: titre,
          sousTitre: filtres,
          infos: ModelePdf.infosGeneration(generatedBy),
        ),
        footer: ModelePdf.piedDePage,
        build: (context) => [
          ModelePdf.chiffresCles([
            ('Demandes', '${demandes.length}'),
            ('À traiter', '${nb(aTraiterDemande)}'),
            (
              'Attendent le résident',
              '${nb((d) => d.repondue && d.residentAccepte == null)}'
            ),
            ('Résolues', '${nb((d) => d.resolue)}'),
            ('Urgentes', '${nb((d) => d.estUrgente)}'),
          ]),
          pw.SizedBox(height: 16),
          if (demandes.isEmpty)
            ModelePdf.etatVide('Aucune demande ne correspond aux filtres.')
          else
            ModelePdf.tableau(
              entetes: const [
                'N°',
                'Résident',
                'Apt',
                'Type',
                'Ménage visé',
                'Motif',
                'Envoyée le',
                'État',
                'Réponse',
                'Proposé',
              ],
              largeurs: const {
                0: pw.FlexColumnWidth(0.45),
                1: pw.FlexColumnWidth(1.4),
                2: pw.FlexColumnWidth(0.6),
                3: pw.FlexColumnWidth(1.1),
                4: pw.FlexColumnWidth(1.2),
                5: pw.FlexColumnWidth(2.4),
                6: pw.FlexColumnWidth(1.1),
                7: pw.FlexColumnWidth(1.1),
                8: pw.FlexColumnWidth(2),
                9: pw.FlexColumnWidth(1.1),
              },
              centrees: const {0, 2},
              accentuees: const {1},
              taille: 8,
              lignes: [
                for (final (i, d) in demandes.indexed)
                  [
                    '${i + 1}',
                    nomResidentDemande(d),
                    d.numeroAppartement,
                    '${libelleTypeDemandeResident(d.type)}'
                        '${d.estUrgente ? ' (urgent)' : ''}',
                    menageDemande(d),
                    d.motif,
                    dateEnvoiDemandeResident(d),
                    libelleEtatDemandeResident(d),
                    d.reponse,
                    _proposition(d),
                  ],
              ],
            ),
        ],
      ),
    );

    return document.save();
  }
}

class GenerateDemandesResidentsExcel {
  const GenerateDemandesResidentsExcel();

  void call({
    required List<DemandeResident> demandes,
    required String filtres,
  }) {
    final excel = Excel.createExcel();
    const feuille = 'Demandes';
    excel.setDefaultSheet(feuille);
    final sheet = excel[feuille];
    const entetes = [
      'Résident',
      'Appartement',
      'Type',
      'Urgent',
      'Ménage visé',
      'Motif',
      'Envoyée le',
      'État',
      'Réponse',
      'Créneau proposé',
      'Répondue le',
      'Résolue le',
      'Filtre appliqué',
    ];
    sheet.appendRow([for (final e in entetes) TextCellValue(e)]);
    for (final d in demandes) {
      sheet.appendRow([
        TextCellValue(nomResidentDemande(d)),
        TextCellValue(d.numeroAppartement ?? ''),
        TextCellValue(libelleTypeDemandeResident(d.type)),
        TextCellValue(d.estUrgente ? 'Oui' : ''),
        TextCellValue(menageDemande(d) ?? ''),
        TextCellValue(d.motif),
        TextCellValue(dateEnvoiDemandeResident(d)),
        TextCellValue(libelleEtatDemandeResident(d)),
        TextCellValue(d.reponse ?? ''),
        TextCellValue(_proposition(d)),
        TextCellValue(
            d.dateReponse == null ? '' : dateHeureDemande(d.dateReponse!)),
        TextCellValue(d.dateResolution == null
            ? ''
            : dateHeureDemande(d.dateResolution!)),
        TextCellValue(filtres),
      ]);
    }

    final styleEntete = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#3732C9'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final styleCorps = CellStyle(
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );
    const largeurs = [
      22.0,
      12.0,
      18.0,
      8.0,
      18.0,
      40.0,
      16.0,
      20.0,
      34.0,
      18.0,
      16.0,
      16.0,
      30.0,
    ];
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
    excel.save(fileName: 'demandes-residents.xlsx');
  }
}
