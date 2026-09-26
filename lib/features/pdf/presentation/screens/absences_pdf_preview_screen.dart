import 'package:flutter/material.dart';

import '../../../../core/widgets/lecteur_pdf.dart';
import '../../../presences/domain/entities/presence.dart';
import '../../domain/usecases/generate_absences_export.dart';

class AbsencesPdfPreviewScreen extends StatelessWidget {
  final List<Presence> absences;
  final List<Presence> horaires;
  final String periode;
  final String filtres;
  final String nomFichier;
  final String generatedBy;

  const AbsencesPdfPreviewScreen({
    super.key,
    required this.absences,
    required this.horaires,
    required this.periode,
    required this.filtres,
    required this.nomFichier,
    required this.generatedBy,
  });

  @override
  Widget build(BuildContext context) {
    return LecteurPdf(
      titre: 'Registre des absences',
      sousTitre: periode,
      icone: Icons.person_off_rounded,
      nomFichier: nomFichier,
      generer: () => const GenerateAbsencesPdf()(
        absences: absences,
        horaires: horaires,
        periode: periode,
        filtres: filtres,
        generatedBy: generatedBy,
      ),
    );
  }
}
