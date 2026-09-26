import 'package:flutter/material.dart';

import '../../../../core/widgets/lecteur_pdf.dart';
import '../../../aire_commune/domain/entities/tache_aire_commune.dart';
import '../../domain/usecases/generate_aire_commune_export.dart';

class AireCommunePdfPreviewScreen extends StatelessWidget {
  final List<TacheAireCommune> zones;
  final String semaine;
  final String filtres;
  final String nomFichier;
  final String generatedBy;

  const AireCommunePdfPreviewScreen({
    super.key,
    required this.zones,
    required this.semaine,
    required this.filtres,
    required this.nomFichier,
    required this.generatedBy,
  });

  @override
  Widget build(BuildContext context) {
    return LecteurPdf(
      titre: 'Entretien des aires communes',
      sousTitre: semaine,
      icone: Icons.cleaning_services_rounded,
      nomFichier: nomFichier,
      generer: () => const GenerateAireCommunePdf()(
        zones: zones,
        semaine: semaine,
        filtres: filtres,
        generatedBy: generatedBy,
      ),
    );
  }
}
