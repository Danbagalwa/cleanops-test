import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/widgets/lecteur_pdf.dart';
import '../../../residents/domain/entities/resident.dart';
import '../../domain/usecases/generate_residents_export.dart';

class ResidentsPdfPreviewScreen extends StatelessWidget {
  final List<Resident> residents;
  final String filterDescription;
  final String generatedBy;

  const ResidentsPdfPreviewScreen({
    super.key,
    required this.residents,
    required this.filterDescription,
    required this.generatedBy,
  });

  @override
  Widget build(BuildContext context) {
    return LecteurPdf(
      titre: 'Liste des résidents',
      sousTitre: filterDescription,
      icone: Icons.people_rounded,
      nomFichier: 'liste-residents.pdf',
      format: PdfPageFormat.a4.landscape,
      generer: () => const GenerateResidentsPdf()(
        residents: residents,
        filterDescription: filterDescription,
        generatedBy: generatedBy,
      ),
    );
  }
}
