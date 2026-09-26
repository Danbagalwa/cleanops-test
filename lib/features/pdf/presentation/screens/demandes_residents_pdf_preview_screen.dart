import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/widgets/lecteur_pdf.dart';
import '../../../resident_espace/domain/entities/demande_resident.dart';
import '../../domain/usecases/generate_demandes_residents_export.dart';

class DemandesResidentsPdfPreviewScreen extends StatelessWidget {
  final List<DemandeResident> demandes;
  final String filtres;
  final String generatedBy;

  const DemandesResidentsPdfPreviewScreen({
    super.key,
    required this.demandes,
    required this.filtres,
    required this.generatedBy,
  });

  @override
  Widget build(BuildContext context) {
    return LecteurPdf(
      titre: 'Demandes des résidents',
      sousTitre: filtres,
      icone: Icons.forum_rounded,
      nomFichier: 'demandes-residents.pdf',
      format: PdfPageFormat.a4.landscape,
      generer: () => const GenerateDemandesResidentsPdf()(
        demandes: demandes,
        filtres: filtres,
        generatedBy: generatedBy,
      ),
    );
  }
}
