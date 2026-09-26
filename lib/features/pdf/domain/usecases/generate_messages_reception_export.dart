import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../modele_pdf.dart';

import '../../../reception/domain/reception_messages_models.dart';

String _date(DateTime? d) => d == null ? '' : MessageTransmis.formater(d);

String _employe(MessageTransmis m) => !m.transmisEmploye
    ? ''
    : (m.employePrenom?.isNotEmpty ?? false)
        ? m.employePrenom!
        : 'Oui';

class GenerateMessagesReceptionPdf {
  const GenerateMessagesReceptionPdf();

  Future<Uint8List> call({
    required List<MessageTransmis> messages,
    required String filtres,
    required String generatedBy,
  }) async {
    const titre = 'Messages de la réception';
    final document =
        await ModelePdf.document(titre: titre, auteur: generatedBy);
    int nb(StatutMessage s) => messages.where((m) => m.statut == s).length;

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
            ('Messages', '${messages.length}'),
            ('En attente', '${nb(StatutMessage.enAttente)}'),
            ('Répondues', '${nb(StatutMessage.repondue)}'),
            ('Résolues', '${nb(StatutMessage.resolue)}'),
          ]),
          pw.SizedBox(height: 16),
          if (messages.isEmpty)
            ModelePdf.etatVide('Aucun message ne correspond aux filtres.')
          else
            ModelePdf.tableau(
              entetes: const [
                'N°',
                'Apt',
                'Nature',
                'Message',
                'Envoyé le',
                'Par',
                'Employé prévenu',
                'Statut',
                'Réponse',
              ],
              largeurs: const {
                0: pw.FlexColumnWidth(0.45),
                1: pw.FlexColumnWidth(0.6),
                2: pw.FlexColumnWidth(1.1),
                3: pw.FlexColumnWidth(2.8),
                4: pw.FlexColumnWidth(1.1),
                5: pw.FlexColumnWidth(0.9),
                6: pw.FlexColumnWidth(0.9),
                7: pw.FlexColumnWidth(0.9),
                8: pw.FlexColumnWidth(2.4),
              },
              centrees: const {0, 1},
              accentuees: const {1},
              taille: 8,
              lignes: [
                for (final (i, m) in messages.indexed)
                  [
                    '${i + 1}',
                    m.numero,
                    m.nature.libelle,
                    m.message,
                    m.envoyeLe,
                    m.auteurPrenom,
                    _employe(m),
                    m.statut.libelle,
                    m.reponse,
                  ],
              ],
            ),
        ],
      ),
    );

    return document.save();
  }
}

class GenerateMessagesReceptionExcel {
  const GenerateMessagesReceptionExcel();

  void call({
    required List<MessageTransmis> messages,
    required String filtres,
  }) {
    final excel = Excel.createExcel();
    const feuille = 'Messages';
    excel.setDefaultSheet(feuille);
    final sheet = excel[feuille];
    const entetes = [
      'Appartement',
      'Nature',
      'Message',
      'Envoyé le',
      'Par',
      'Employé prévenu',
      'Statut',
      'Réponse',
      'Répondue le',
      'Résolue le',
      'Filtre appliqué',
    ];
    sheet.appendRow([for (final e in entetes) TextCellValue(e)]);
    for (final m in messages) {
      sheet.appendRow([
        TextCellValue(m.numero),
        TextCellValue(m.nature.libelle),
        TextCellValue(m.message),
        TextCellValue(m.envoyeLe),
        TextCellValue(m.auteurPrenom),
        TextCellValue(_employe(m)),
        TextCellValue(m.statut.libelle),
        TextCellValue(m.reponse ?? ''),
        TextCellValue(_date(m.dateReponse)),
        TextCellValue(_date(m.dateResolution)),
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
      12.0,
      18.0,
      44.0,
      16.0,
      14.0,
      16.0,
      12.0,
      36.0,
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
    excel.save(fileName: 'messages-reception.xlsx');
  }
}
