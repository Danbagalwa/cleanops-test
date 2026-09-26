import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../pdf/presentation/screens/resident_cleaning_dates_pdf_screen.dart';
import '../../../resident_espace/domain/entities/tache_resident.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../../domain/reception_models.dart';
import '../providers/reception_residents_provider.dart';
import 'message_form_card.dart';
import 'package:cleanops/core/widgets/notification_app.dart';

/// Ouvre l'aperçu d'impression du calendrier des prochaines dates.
///
/// Utilisable sans accord préalable de l'Admin. Le calendrier ne porte que des
/// dates, des périodes et le prénom de la préposée.
void ouvrirImpressionCalendrier(BuildContext context, FicheAppartement fiche) {
  final taches = [
    for (final d in fiche.prochainesDates)
      TacheResident(
        id: '${fiche.id}-${d.date.toIso8601String()}-${d.periode}',
        appartementId: fiche.id,
        semaineReelle: d.date,
        jour: d.jour,
        periode: d.periode == 'AM' ? PeriodeType.am : PeriodeType.pm,
        statut: StatutTache.nonCommence,
        prenomPreposee: d.employePrenom,
      ),
  ];

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ResidentCleaningDatesPdfScreen(
        taches: taches,
        residentName: fiche.residents.isEmpty
            ? 'Résident(e)'
            : fiche.residents.join(' et '),
        apartmentNumber: fiche.numero,
      ),
    ),
  );
}

/// Impression du calendrier depuis une ligne du tableau : charge la fiche de
/// l'appartement, puis ouvre l'aperçu. Une erreur s'affiche dans une bulle.
Future<void> imprimerCalendrierDeLigne(
  BuildContext context,
  WidgetRef ref,
  ResidentLigne ligne,
) async {
  try {
    final fiche =
        await ref.read(receptionFicheProvider(ligne.appartementId).future);
    if (!context.mounted) return;
    if (fiche == null) {
      NotificationApp.avertissement(
          context, 'Cet appartement est introuvable.');
      return;
    }
    if (fiche.prochainesDates.isEmpty) {
      NotificationApp.info(
        context,
        'Aucune date de ménage planifiée pour l\'appartement ${fiche.numero}.',
      );
      return;
    }
    ouvrirImpressionCalendrier(context, fiche);
  } catch (erreur) {
    if (context.mounted) NotificationApp.depuisErreur(context, erreur);
  }
}

/// Fenêtre d'envoi d'un message à l'administration pour un appartement.
Future<void> ouvrirMessage(BuildContext context, ResidentLigne ligne) {
  return showDialog<void>(
    context: context,
    builder: (_) => _MessageDialog(ligne: ligne),
  );
}

class _MessageDialog extends ConsumerWidget {
  final ResidentLigne ligne;

  const _MessageDialog({required this.ligne});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fiche = ref.watch(receptionFicheProvider(ligne.appartementId));

    return Dialog(
      backgroundColor: AppColors.grisLight,
      insetPadding: const EdgeInsets.all(AppSizes.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${ligne.nomComplet} · Apt ${ligne.numero}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                fiche.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSizes.lg),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.rouge),
                    ),
                  ),
                  error: (erreur, _) => Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Text(erreur.toString(),
                        style: const TextStyle(color: AppColors.refus)),
                  ),
                  data: (f) => f == null
                      ? const Padding(
                          padding: EdgeInsets.all(AppSizes.md),
                          child: Text('Cet appartement est introuvable.'),
                        )
                      : MessageFormCard(
                          fiche: f,
                          onEnvoye: () => Navigator.of(context).pop(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
