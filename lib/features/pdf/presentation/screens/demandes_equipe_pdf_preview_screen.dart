import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/widgets/lecteur_pdf.dart';
import '../../../demandes_equipe/domain/entities/demande_equipe.dart';
import '../../domain/usecases/generate_demandes_equipe_export.dart';

class DemandesEquipePdfPreviewScreen extends StatelessWidget {
  final List<DemandeEquipe> demandes;
  final String filtres;
  final String generatedBy;

  const DemandesEquipePdfPreviewScreen({
    super.key,
    required this.demandes,
    required this.filtres,
    required this.generatedBy,
  });

  @override
  Widget build(BuildContext context) {
    return LecteurPdf(
      titre: 'Demandes de l’équipe',
      sousTitre: filtres,
      icone: Icons.event_note_rounded,
      nomFichier: 'demandes-equipe.pdf',
      format: PdfPageFormat.a4.landscape,
      generer: () => const GenerateDemandesEquipePdf()(
        demandes: demandes,
        filtres: filtres,
        generatedBy: generatedBy,
      ),
    );
  }
}
