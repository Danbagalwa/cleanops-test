import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/reception_models.dart';
import '../providers/reception_residents_provider.dart';
import '../reception_sections.dart';
import '../widgets/message_form_card.dart';
import '../widgets/reception_actions.dart';

/// Fiche d'un appartement pour la Réception : LECTURE SEULE.
///
/// Elle affiche l'appartement, ses résidents, le statut du jour, le calendrier
/// des prochaines dates (imprimable) et le formulaire de message à
/// l'administration. Elle ne permet de modifier aucune tâche ni aucun planning,
/// et ne montre jamais le motif d'un non-réalisé (le serveur ne le renvoie pas).
class ReceptionFicheScreen extends ConsumerWidget {
  final String appartementId;

  const ReceptionFicheScreen({super.key, required this.appartementId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fiche = ref.watch(receptionFicheProvider(appartementId));

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Retour à la recherche',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(receptionResidentsRoute),
        ),
        title: Text(
          fiche.valueOrNull == null
              ? 'Appartement'
              : 'Appartement ${fiche.valueOrNull!.numero}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: fiche.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.rouge),
        ),
        error: (erreur, _) => _Etat(
          texte: erreur.toString(),
          actionLabel: 'Réessayer',
          onAction: () => ref.invalidate(receptionFicheProvider(appartementId)),
        ),
        data: (f) => f == null
            ? const _Etat(texte: 'Cet appartement est introuvable.')
            : _Contenu(fiche: f),
      ),
    );
  }
}

class _Contenu extends StatelessWidget {
  final FicheAppartement fiche;

  const _Contenu({required this.fiche});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EnTeteCard(fiche: fiche),
              const SizedBox(height: AppSizes.md),
              _StatutCard(statut: fiche.statut),
              const SizedBox(height: AppSizes.md),
              _CalendrierCard(fiche: fiche),
              const SizedBox(height: AppSizes.md),
              MessageFormCard(fiche: fiche),
              const SizedBox(height: AppSizes.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  final String? titre;
  final Widget child;

  const _Carte({this.titre, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titre != null) ...[
              Text(
                titre!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSizes.sm),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _EnTeteCard extends StatelessWidget {
  final FicheAppartement fiche;

  const _EnTeteCard({required this.fiche});

  @override
  Widget build(BuildContext context) {
    final details = [
      if (fiche.etage != null) 'Étage ${fiche.etage}',
      if (fiche.taille != null && fiche.taille!.isNotEmpty) fiche.taille!,
    ].join(' · ');

    return _Carte(
      child: Row(
        children: [
          const Icon(Icons.apartment_rounded, size: 32, color: AppColors.rouge),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appartement ${fiche.numero}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                if (details.isNotEmpty)
                  Text(details,
                      style: const TextStyle(color: AppColors.grisDark)),
                const SizedBox(height: 2),
                Text(
                  fiche.residents.isEmpty
                      ? 'Aucun résident actif'
                      : fiche.residents.join(', '),
                  style: const TextStyle(color: AppColors.grisDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatutCard extends StatelessWidget {
  final StatutDuJour statut;

  const _StatutCard({required this.statut});

  (IconData, Color) get _visuel => switch (statut.etat) {
        EtatStatut.aucun => (Icons.event_busy_rounded, AppColors.grisDark),
        EtatStatut.prevu => (Icons.schedule_rounded, AppColors.rouge),
        EtatStatut.confirme => (Icons.how_to_reg_rounded, AppColors.rouge),
        EtatStatut.transfere => (Icons.swap_horiz_rounded, AppColors.aVerifier),
        EtatStatut.libere => (Icons.hourglass_top_rounded, AppColors.aVerifier),
        EtatStatut.realise => (Icons.task_alt_rounded, AppColors.fait),
        EtatStatut.nonRealise => (Icons.cancel_outlined, AppColors.refus),
      };

  @override
  Widget build(BuildContext context) {
    final (icone, couleur) = _visuel;

    return _Carte(
      titre: 'Statut du jour',
      child: Row(
        children: [
          Icon(icone, color: couleur, size: 28),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Text(
              statut.libelle,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendrierCard extends StatelessWidget {
  final FicheAppartement fiche;

  const _CalendrierCard({required this.fiche});

  @override
  Widget build(BuildContext context) {
    final dates = fiche.prochainesDates;

    return _Carte(
      titre: 'Prochaines dates de ménage',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dates.isEmpty)
            const Text(
              'Aucune date planifiée.',
              style: TextStyle(color: AppColors.grisDark),
            )
          else
            for (final d in dates)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded,
                        size: 18, color: AppColors.grisDark),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        '${d.jour} ${d.dateCourte} — ${d.periode}'
                        '${d.employePrenom == null ? '' : ' — ${d.employePrenom}'}',
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: AppSizes.sm),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: dates.isEmpty
                  ? null
                  : () => ouvrirImpressionCalendrier(context, fiche),
              icon: const Icon(Icons.print_rounded),
              label: const Text('Imprimer le calendrier'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Etat extends StatelessWidget {
  final String texte;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Etat({required this.texte, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texte,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grisDark)),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSizes.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
