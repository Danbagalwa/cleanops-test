import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../modele_pdf.dart';

import '../../../demandes_equipe/domain/entities/demande_equipe.dart';
import '../../../demandes_equipe/presentation/widgets/demande_equipe_elements.dart'
    show
        dateEnvoiDemande,
        joursDemande,
        libelleStatutDemande,
        nomDemandeur,
        periodeDemande;

class GenerateDemandesEquipePdf {
  const GenerateDemandesEquipePdf();

  Future<Uint8List> call({
    required List<DemandeEquipe> demandes,
    required String filtres,
    required String generatedBy,
  }) async {
    const titre = 'Demandes de l’équipe';
    final document =
        await ModelePdf.document(titre: titre, auteur: generatedBy);
    int nb(bool Function(DemandeEquipe) test) => demandes.where(test).length;

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
            ('En attente', '${nb((d) => d.enAttente)}'),
            ('Approuvées', '${nb((d) => d.estApprouvee)}'),
            ('Refusées', '${nb((d) => d.estRefusee)}'),
            ('Vues', '${nb((d) => d.estVue)}'),
          ]),
          pw.SizedBox(height: 16),
          if (demandes.isEmpty)
            ModelePdf.etatVide('Aucune demande ne correspond aux filtres.')
          else
            ModelePdf.tableau(
              entetes: const [
                'N°',
                'Employé',
                'Type',
                'Période',
                'Jours',
                'Motif',
                'Envoyée le',
                'Statut',
                'Réponse',
              ],
              largeurs: const {
                0: pw.FlexColumnWidth(0.45),
                1: pw.FlexColumnWidth(1.5),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FlexColumnWidth(1.9),
                4: pw.FlexColumnWidth(0.6),
                5: pw.FlexColumnWidth(2.6),
                6: pw.FlexColumnWidth(1.1),
                7: pw.FlexColumnWidth(1),
                8: pw.FlexColumnWidth(2),
              },
              centrees: const {0, 4, 7},
              accentuees: const {1},
              taille: 8,
              lignes: [
                for (final (i, d) in demandes.indexed)
                  [
                    '${i + 1}',
                    nomDemandeur(d),
                    d.type.libelle,
                    periodeDemande(d),
                    joursDemande(d)?.toString(),
                    d.motif,
                    dateEnvoiDemande(d),
                    libelleStatutDemande(d),
                    d.noteResponsable,
                  ],
              ],
            ),
        ],
      ),
    );

    return document.save();
  }
}

class GenerateDemandesEquipeExcel {
  const GenerateDemandesEquipeExcel();

  void call({
    required List<DemandeEquipe> demandes,
    required String filtres,
  }) {
    final excel = Excel.createExcel();
    const feuille = 'Demandes';
    excel.setDefaultSheet(feuille);
    final sheet = excel[feuille];
    const entetes = [
      'Employé',
      'Type',
      'Date de début',
      'Date de fin',
      'Jours',
      'Motif',
      'Envoyée le',
      'Statut',
      'Réponse',
      'Traitée le',
      'Document joint',
      'Filtre appliqué',
    ];
    String date(DateTime? d) =>
        d == null ? '' : DateFormat('dd/MM/yyyy').format(d.toLocal());
    sheet.appendRow([for (final e in entetes) TextCellValue(e)]);
    for (final d in demandes) {
      final sansDate = d.type == TypeDemandeEquipe.autre;
      sheet.appendRow([
        TextCellValue(nomDemandeur(d)),
        TextCellValue(d.type.libelle),
        TextCellValue(sansDate ? '' : date(d.dateDebut)),
        TextCellValue(sansDate ? '' : date(d.dateFin ?? d.dateDebut)),
        TextCellValue(joursDemande(d)?.toString() ?? ''),
        TextCellValue(d.motif),
        TextCellValue(date(d.createdAt)),
        TextCellValue(libelleStatutDemande(d)),
        TextCellValue(d.noteResponsable ?? ''),
        TextCellValue(date(d.dateTraitement)),
        TextCellValue(d.documentNom ?? ''),
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
      18.0,
      14.0,
      14.0,
      8.0,
      40.0,
      14.0,
      12.0,
      34.0,
      14.0,
      22.0,
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
    excel.save(fileName: 'demandes-equipe.xlsx');
  }
}
