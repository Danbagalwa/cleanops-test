import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../modele_pdf.dart';

import '../../../presences/domain/entities/presence.dart';

/// Libellé court du type d'absence (tableaux, exports).
String typeAbsence(StatutPresence statut) => switch (statut) {
      StatutPresence.absentMatin => 'Matin (AM)',
      StatutPresence.absentApresMidi => 'Après-midi (PM)',
      StatutPresence.present => 'Présente',
      StatutPresence.absent => 'Journée complète',
    };

String nomPreposee(Presence p) {
  final nom = p.employee?.nomComplet.trim() ?? '';
  return nom.isEmpty ? 'Préposée' : nom;
}

String _jour(DateTime d) => DateFormat('EEE d MMM yyyy', 'fr_FR').format(d);
String? _signalee(Presence p) => p.confirmedLe == null
    ? null
    : DateFormat('dd/MM HH:mm', 'fr_FR').format(p.confirmedLe!.toLocal());

List<Presence> _trier(List<Presence> presences) => [...presences]..sort((a, b) {
    final parDate = b.date.compareTo(a.date);
    return parDate != 0 ? parDate : nomPreposee(a).compareTo(nomPreposee(b));
  });

class GenerateAbsencesPdf {
  const GenerateAbsencesPdf();

  Future<Uint8List> call({
    required List<Presence> absences,
    required List<Presence> horaires,
    required String periode,
    required String filtres,
    required String generatedBy,
  }) async {
    const titre = 'Registre des absences';
    final document =
        await ModelePdf.document(titre: titre, auteur: generatedBy);
    final lignes = _trier(absences);
    final registre = _trier(horaires);
    int nb(StatutPresence s) => lignes.where((p) => p.statut == s).length;
    final preposees = lignes.map((p) => p.employeeId).toSet().length;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 30),
        header: (context) => ModelePdf.enTete(
          context,
          titre: titre,
          sousTitre: filtres.isEmpty ? periode : '$periode — $filtres',
          infos: ModelePdf.infosGeneration(generatedBy),
        ),
        footer: ModelePdf.piedDePage,
        build: (context) => [
          ModelePdf.chiffresCles([
            ('Absences', '${lignes.length}'),
            ('Journée complète', '${nb(StatutPresence.absent)}'),
            ('Matin', '${nb(StatutPresence.absentMatin)}'),
            ('Après-midi', '${nb(StatutPresence.absentApresMidi)}'),
            ('Préposées', '$preposees'),
          ]),
          pw.SizedBox(height: 16),
          if (lignes.isEmpty)
            ModelePdf.etatVide(
                'Aucune absence ne correspond à la période et aux filtres.')
          else
            ModelePdf.tableau(
              entetes: const [
                'N°',
                'Date',
                'Préposée',
                'Absence',
                'Signalée le'
              ],
              largeurs: const {
                0: pw.FlexColumnWidth(0.5),
                1: pw.FlexColumnWidth(1.5),
                2: pw.FlexColumnWidth(2.2),
                3: pw.FlexColumnWidth(1.5),
                4: pw.FlexColumnWidth(1.1),
              },
              centrees: const {0, 4},
              accentuees: const {2},
              lignes: [
                for (final (i, p) in lignes.indexed)
                  [
                    '${i + 1}',
                    _jour(p.date),
                    nomPreposee(p),
                    typeAbsence(p.statut),
                    _signalee(p),
                  ],
              ],
            ),
          if (registre.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            ModelePdf.titreSection('Horaires précisés'),
            ModelePdf.note(
                'À titre informatif — ces horaires n’affectent pas les tâches.'),
            pw.SizedBox(height: 6),
            ModelePdf.tableau(
              entetes: const ['Date', 'Préposée', 'Horaire'],
              largeurs: const {
                0: pw.FlexColumnWidth(1.5),
                1: pw.FlexColumnWidth(2.2),
                2: pw.FlexColumnWidth(1.2),
              },
              centrees: const {2},
              accentuees: const {1},
              lignes: [
                for (final p in registre)
                  [
                    _jour(p.date),
                    nomPreposee(p),
                    '${p.heureDebut} → ${p.heureFin}',
                  ],
              ],
            ),
          ],
        ],
      ),
    );

    return document.save();
  }
}

class GenerateAbsencesExcel {
  const GenerateAbsencesExcel();

  void call({
    required List<Presence> absences,
    required List<Presence> horaires,
    required String periode,
    required String nomFichier,
  }) {
    final excel = Excel.createExcel();
    const feuille = 'Absences';
    excel.setDefaultSheet(feuille);
    _remplir(
      excel[feuille],
      entetes: const ['Date', 'Préposée', 'Absence', 'Signalée le', 'Période'],
      largeurs: const [16, 28, 20, 16, 30],
      lignes: [
        for (final p in _trier(absences))
          [
            DateFormat('dd/MM/yyyy').format(p.date),
            nomPreposee(p),
            typeAbsence(p.statut),
            _signalee(p) ?? '',
            periode,
          ],
      ],
    );
    if (horaires.isNotEmpty) {
      _remplir(
        excel['Horaires précisés'],
        entetes: const ['Date', 'Préposée', 'Début', 'Fin'],
        largeurs: const [16, 28, 10, 10],
        lignes: [
          for (final p in _trier(horaires))
            [
              DateFormat('dd/MM/yyyy').format(p.date),
              nomPreposee(p),
              p.heureDebut ?? '',
              p.heureFin ?? '',
            ],
        ],
      );
    }
    excel.delete('Sheet1');
    excel.save(fileName: nomFichier);
  }

  void _remplir(
    Sheet sheet, {
    required List<String> entetes,
    required List<double> largeurs,
    required List<List<String>> lignes,
  }) {
    sheet.appendRow([for (final e in entetes) TextCellValue(e)]);
    for (final ligne in lignes) {
      sheet.appendRow([for (final v in ligne) TextCellValue(v)]);
    }
    final styleEntete = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#3732C9'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final styleCorps = CellStyle(
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );
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
  }
}
