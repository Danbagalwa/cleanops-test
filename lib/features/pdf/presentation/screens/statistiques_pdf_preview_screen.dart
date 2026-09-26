import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/widgets/lecteur_pdf.dart';
import '../../../statistiques/domain/entities/statistiques_menages.dart';
import '../../domain/usecases/generate_statistiques_export.dart';

class StatistiquesPdfPreviewScreen extends StatelessWidget {
  final StatistiquesMenages stats;
  final String filtres;
  final String generatedBy;

  const StatistiquesPdfPreviewScreen({
    super.key,
    required this.stats,
    required this.filtres,
    required this.generatedBy,
  });

  @override
  Widget build(BuildContext context) {
    return LecteurPdf(
      titre: 'Chiffres clés des ménages',
      sousTitre: periodeStatistiques(stats),
      icone: Icons.insights_rounded,
      nomFichier: 'statistiques-menages.pdf',
      format: PdfPageFormat.a4,
      generer: () => const GenerateStatistiquesPdf()(
        stats: stats,
        filtres: filtres,
        generatedBy: generatedBy,
      ),
    );
  }
}
