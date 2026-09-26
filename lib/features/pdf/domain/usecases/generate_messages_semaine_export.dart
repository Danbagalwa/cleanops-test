import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../modele_pdf.dart';

import '../../../messages_semaine/domain/entities/message_semaine.dart';

final _fmt = DateFormat('dd/MM/yyyy HH:mm');

String _date(DateTime? d) => d == null ? '' : _fmt.format(d.toLocal());

String libelleTypeMessage(MessageType t) => switch (t) {
      MessageType.personnalise => 'Personnalisé',
      MessageType.automatique => 'Suggéré',
      MessageType.fete => 'Fête',
    };

/// Nombre de jours d'affichage (jusqu'à aujourd'hui pour le message actif).
int joursAffichage(MessageSemaine m) {
  final fin = m.dateDesactivation ?? DateTime.now();
  return fin.difference(m.dateCreation).inDays + 1;
}

class GenerateMessagesSemainePdf {
  const GenerateMessagesSemainePdf();

  Future<Uint8List> call({
    required List<MessageSemaine> messages,
    required String filtres,
    required String generatedBy,
  }) async {
    const titre = 'Messages de la semaine';
    final document =
        await ModelePdf.document(titre: titre, auteur: generatedBy);

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
            ('Visible', '${messages.where((m) => m.isActif).length}'),
            for (final t in MessageType.values)
              (
                libelleTypeMessage(t),
                '${messages.where((m) => m.type == t).length}'
              ),
          ]),
          pw.SizedBox(height: 16),
          if (messages.isEmpty)
            ModelePdf.etatVide('Aucun message ne correspond aux filtres.')
          else
            ModelePdf.tableau(
              entetes: const [
                'N°',
                'Message',
                'Type',
                'Publié par',
                'Publié le',
                'Retiré le',
                'Jours',
                'Statut',
              ],
              largeurs: const {
                0: pw.FlexColumnWidth(0.4),
                1: pw.FlexColumnWidth(3.6),
                2: pw.FlexColumnWidth(0.9),
                3: pw.FlexColumnWidth(1.3),
                4: pw.FlexColumnWidth(1.1),
                5: pw.FlexColumnWidth(1.1),
                6: pw.FlexColumnWidth(0.5),
                7: pw.FlexColumnWidth(0.8),
              },
              centrees: const {0, 6, 7},
              taille: 8,
              lignes: [
                for (final (i, m) in messages.indexed)
                  [
                    '${i + 1}',
                    m.contenu,
                    libelleTypeMessage(m.type),
                    m.auteur,
                    _date(m.dateCreation),
                    m.isActif ? 'Visible' : _date(m.dateDesactivation),
                    '${joursAffichage(m)}',
                    m.isActif ? 'Actif' : 'Archivé',
                  ],
              ],
            ),
        ],
      ),
    );

    return document.save();
  }
}

class GenerateMessagesSemaineExcel {
  const GenerateMessagesSemaineExcel();

  void call({
    required List<MessageSemaine> messages,
    required String filtres,
  }) {
    final excel = Excel.createExcel();
    const feuille = 'Messages';
    excel.setDefaultSheet(feuille);
    final sheet = excel[feuille];
    const entetes = [
      'Message',
      'Type',
      'Publié par',
      'Publié le',
      'Retiré le',
      'Jours affiché',
      'Statut',
      'Filtre appliqué',
    ];
    sheet.appendRow([for (final e in entetes) TextCellValue(e)]);
    for (final m in messages) {
      sheet.appendRow([
        TextCellValue(m.contenu),
        TextCellValue(libelleTypeMessage(m.type)),
        TextCellValue(m.auteur),
        TextCellValue(_date(m.dateCreation)),
        TextCellValue(m.isActif ? '' : _date(m.dateDesactivation)),
        IntCellValue(joursAffichage(m)),
        TextCellValue(m.isActif ? 'Actif' : 'Archivé'),
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
    const largeurs = [50.0, 14.0, 22.0, 18.0, 18.0, 12.0, 10.0, 28.0];
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
    excel.save(fileName: 'messages-semaine.xlsx');
  }
}
