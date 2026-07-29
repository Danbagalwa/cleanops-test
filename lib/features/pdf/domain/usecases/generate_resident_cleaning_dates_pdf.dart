import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../resident_espace/domain/entities/tache_resident.dart';

class GenerateResidentCleaningDatesPdf {
  const GenerateResidentCleaningDatesPdf();

  Future<Uint8List> call({
    required List<TacheResident> taches,
    required String residentName,
    required String apartmentNumber,
  }) async {
    final pdf = pw.Document(
      title: 'Mes dates de ménage',
      author: 'CleanOps',
    );
    final dates = [...taches]
      ..sort((a, b) => a.dateReelle.compareTo(b.dateReelle));
    final primary = PdfColor.fromHex('#3732C9');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Mes dates de ménage',
              style: pw.TextStyle(
                color: primary,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('$residentName · Appartement $apartmentNumber'),
            pw.Divider(color: primary),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount} · CleanOps',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 12),
          if (dates.isEmpty)
            pw.Text('Aucune date planifiée pour cette période.')
          else
            pw.TableHelper.fromTextArray(
              headerDecoration: pw.BoxDecoration(color: primary),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              headers: const [
                'Jour et date',
                'Période',
                'Préposée',
                'Statut',
              ],
              data: dates
                  .map((t) => [
                        DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                            .format(t.dateReelle),
                        t.periodeDisplayLabel,
                        t.prenomPreposee ?? 'À confirmer',
                        t.estProjection ? 'Planifié' : 'Confirmé',
                      ])
                  .toList(),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.all(7),
            ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Les dates planifiées peuvent être modifiées. '
            'Vous serez informé en cas de changement.',
            style: pw.TextStyle(
              color: PdfColors.grey700,
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }
}
