import 'package:flutter/material.dart';

import '../../../../core/widgets/lecteur_pdf.dart';
import '../../../appartements/domain/entities/appartement.dart';
import '../../domain/usecases/generate_appartements_export.dart';

class AppartementsPdfPreviewScreen extends StatelessWidget {
  final List<Appartement> appartements;
  final String filterDescription;
  final String generatedBy;

  const AppartementsPdfPreviewScreen({
    super.key,
    required this.appartements,
    required this.filterDescription,
    required this.generatedBy,
  });

  @override
  Widget build(BuildContext context) {
    return LecteurPdf(
      titre: 'Liste des appartements',
      sousTitre: filterDescription,
      icone: Icons.apartment_rounded,
      nomFichier: 'liste-appartements.pdf',
      generer: () => const GenerateAppartementsPdf()(
        appartements: appartements,
        filterDescription: filterDescription,
        generatedBy: generatedBy,
      ),
    );
  }
}
