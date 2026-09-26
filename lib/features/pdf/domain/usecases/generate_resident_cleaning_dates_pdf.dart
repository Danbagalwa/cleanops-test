import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../resident_espace/domain/entities/tache_resident.dart';
import '../modele_pdf.dart';

class GenerateResidentCleaningDatesPdf {
  const GenerateResidentCleaningDatesPdf();

  Future<Uint8List> call({
    required List<TacheResident> taches,
    required String residentName,
    required String apartmentNumber,
  }) async {
    const titre = 'Dates de ménage';
    final document = await ModelePdf.document(titre: titre, auteur: 'CleanOps');
    final dates = [...taches]
      ..sort((a, b) => a.dateReelle.compareTo(b.dateReelle));
    final confirmees = dates.where((t) => !t.estProjection).length;

    String jour(DateTime d) {
      final texte = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(d);
      return texte[0].toUpperCase() + texte.substring(1);
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 30),
        header: (context) => ModelePdf.enTete(
          context,
          titre: titre,
          sousTitre: '$residentName · Appartement $apartmentNumber',
          infos: [
            ('Résident', residentName),
            ('Appartement', apartmentNumber),
            ('Édité le', ModelePdf.dateGeneration()),
          ],
        ),
        footer: ModelePdf.piedDePage,
        build: (_) => [
          ModelePdf.chiffresCles([
            ('Passages prévus', '${dates.length}'),
            ('Confirmés', '$confirmees'),
            ('À confirmer', '${dates.length - confirmees}'),
          ]),
          pw.SizedBox(height: 16),
          if (dates.isEmpty)
            ModelePdf.etatVide('Aucune date planifiée pour cette période.')
          else
            ModelePdf.tableau(
              entetes: const ['Jour et date', 'Période', 'Préposée', 'Statut'],
              largeurs: const {
                0: pw.FlexColumnWidth(2.4),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(1.4),
                3: pw.FlexColumnWidth(1.1),
              },
              centrees: const {1, 3},
              accentuees: const {0},
              taille: 9,
              lignes: [
                for (final t in dates)
                  [
                    jour(t.dateReelle),
                    t.periodeDisplayLabel,
                    t.prenomPreposee ?? 'À confirmer',
                    t.estProjection ? 'Planifié' : 'Confirmé',
                  ],
              ],
            ),
          pw.SizedBox(height: 12),
          ModelePdf.note(
            'Les dates planifiées peuvent être modifiées. '
            'Vous serez informé en cas de changement.',
          ),
        ],
      ),
    );
    return document.save();
  }
}
