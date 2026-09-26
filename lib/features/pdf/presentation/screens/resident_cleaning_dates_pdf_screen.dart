import 'package:flutter/material.dart';

import '../../../../core/widgets/lecteur_pdf.dart';
import '../../../resident_espace/domain/entities/tache_resident.dart';
import '../../domain/usecases/generate_resident_cleaning_dates_pdf.dart';

/// Dates de ménage d'un appartement. Ouvert par le résident (ses propres
/// dates) comme par la Réception (calendrier à imprimer pour un résident).
class ResidentCleaningDatesPdfScreen extends StatelessWidget {
  final List<TacheResident> taches;
  final String residentName;
  final String apartmentNumber;

  const ResidentCleaningDatesPdfScreen({
    super.key,
    required this.taches,
    required this.residentName,
    required this.apartmentNumber,
  });

  @override
  Widget build(BuildContext context) {
    return LecteurPdf(
      titre: 'Dates de ménage',
      sousTitre: '$residentName — appartement $apartmentNumber',
      icone: Icons.event_available_rounded,
      nomFichier: 'mes-dates-de-menage.pdf',
      generer: () => const GenerateResidentCleaningDatesPdf()(
        taches: taches,
        residentName: residentName,
        apartmentNumber: apartmentNumber,
      ),
    );
  }
}
