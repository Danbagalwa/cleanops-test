import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/dialogue_app.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../../../tache_jour/presentation/providers/tache_jour_provider.dart';
import '../../domain/entities/tache_disponible.dart';
import '../providers/tache_disponible_provider.dart';

/// Briques partagées par la page « Tâches disponibles » et le tableau de
/// bord de la préposée : la carte d'une tâche et sa prise en charge.

// ── Notification résident lors de la prise en charge (Option B) ──
Future<void> _notifierResidentPrise({
  required String appartementId,
  required String? tacheJourId,
  required String prenomEmployee,
}) async {
  try {
    final residents = await SupabaseService.table(SupabaseService.residents)
        .select('id')
        .eq('appartement_id', appartementId)
        .eq('is_actif', true)
        .eq('a_application', true);

    if ((residents as List).isEmpty) return;

    final rows = residents
        .map((r) => {
              'resident_id': r['id'],
              if (tacheJourId != null) 'tache_jour_id': tacheJourId,
              'type': 'Transfert',
              'message':
                  'Votre ménage a été confirmé et sera effectué par $prenomEmployee.',
            })
        .toList();

    await SupabaseService.table(SupabaseService.notificationsResidents)
        .insert(rows);
  } catch (_) {}
}

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

/// « Aujourd'hui · jeudi 24 septembre », « Demain · … », puis
/// « Lundi 29 septembre ».
String libelleJourDisponible(DateTime? date) {
  if (date == null) return 'Date à préciser';
  final ecart = _jour(date).difference(_jour(DateTime.now())).inDays;
  final complet = DateFormat('EEEE d MMMM', 'fr_FR').format(date);
  if (ecart == 0) return 'Aujourd’hui · $complet';
  if (ecart == 1) return 'Demain · $complet';
  return '${complet[0].toUpperCase()}${complet.substring(1)}';
}

/// Recharge la liste des tâches disponibles de la préposée connectée.
Future<void> rechargerTachesDisponibles(WidgetRef ref) async {
  final employee = ref.read(employeeCourantProvider);
  if (employee == null) return;
  await ref
      .read(tacheDisponibleNotifierProvider.notifier)
      .charger(employeeId: employee.id, date: DateTime.now());
}

/// Prise en charge de [td] par la préposée connectée : confirmation,
/// enregistrement, avis au résident, puis mise à jour de sa journée. En cas
/// d'échec (souvent : une collègue l'a prise juste avant), la liste est
/// rechargée pour ne plus la proposer.
Future<void> prendreTacheDisponible(
  BuildContext context,
  WidgetRef ref,
  TacheDisponible td,
) async {
  final employee = ref.read(employeeCourantProvider);
  if (employee == null) return;

  final confirme = await showDialog<bool>(
    context: context,
    builder: (c) => _DialogueConfirmation(
      tacheDisponible: td,
      onConfirmer: () => Navigator.pop(c, true),
    ),
  );
  if (confirme != true || !context.mounted) return;

  final ok = await ref
      .read(tacheDisponibleNotifierProvider.notifier)
      .prendreEnCharge(tacheDisponibleId: td.id, employeeId: employee.id);

  final appart = td.tacheJour?.appartement;
  final date = td.tacheJour?.dateDuJour;
  if (ok) {
    if (appart != null) {
      await _notifierResidentPrise(
        appartementId: appart.id,
        tacheJourId: td.tacheJourId,
        prenomEmployee: employee.prenom,
      );
    }
    // La tâche entre dans la journée de ce jour-là.
    if (date != null) {
      await ref
          .read(tacheJourNotifierProvider(DateFormat('yyyy-MM-dd').format(date))
              .notifier)
          .charger(employeeId: employee.id);
    }
    ref.invalidate(idsTachesAuPoolProvider);
  }
  if (!context.mounted) return;

  if (ok) {
    NotificationApp.succes(
      context,
      appart == null
          ? 'Tâche ajoutée à votre journée.'
          : 'Apt. ${appart.numero} ajouté à votre journée.',
      libelleAction: date == null ? null : 'Voir',
      onAction: date == null
          ? null
          : () => context.go('${AppRoutes.tacheJour}'
              '?date=${DateFormat('yyyy-MM-dd').format(date)}'),
    );
  } else {
    NotificationApp.erreur(
      context,
      ref.read(tacheDisponibleNotifierProvider).error ??
          'Erreur lors de la prise en charge.',
    );
    await rechargerTachesDisponibles(ref);
  }
}

// ── Carte d'une tâche disponible ───────────────────────────

class CarteTacheDisponible extends StatelessWidget {
  final TacheDisponible tacheDisponible;
  final bool isProcessing;
  final VoidCallback onPrendre;

  /// Affiche le jour de la tâche (tableau de bord : liste non regroupée).
  final bool avecJour;

  const CarteTacheDisponible({
    super.key,
    required this.tacheDisponible,
    required this.isProcessing,
    required this.onPrendre,
    this.avecJour = false,
  });

  @override
  Widget build(BuildContext context) {
    final td = tacheDisponible;
    final tj = td.tacheJour;
    final appart = tj?.appartement;
    final matin = tj?.periode == PeriodeType.am;
    final couleur = matin ? AppColors.absent : AppColors.aVerifier;
    final minutes = tj?.minutesEstimees ?? 0;

    return CarteContenu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    matin
                        ? Icons.wb_sunny_outlined
                        : Icons.nights_stay_outlined,
                    color: couleur,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appart != null
                            ? 'Apt. ${appart.numero}'
                            : 'Appartement à préciser',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.noir,
                        ),
                      ),
                      if (avecJour) ...[
                        const SizedBox(height: 2),
                        Text(
                          libelleJourDisponible(tj?.dateDuJour),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.rouge,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          PastilleInfo(
                            icone: matin
                                ? Icons.wb_sunny_outlined
                                : Icons.nights_stay_outlined,
                            texte: matin ? 'Matin' : 'Après-midi',
                            couleur: couleur,
                          ),
                          if (appart != null)
                            PastilleInfo(
                              icone: Icons.straighten_rounded,
                              texte: appart.taille,
                              couleur: AppColors.grisDark,
                            ),
                          if (minutes > 0)
                            PastilleInfo(
                              icone: Icons.schedule_rounded,
                              texte: DateHelper.minutesEnHeures(minutes),
                              couleur: AppColors.grisDark,
                            ),
                          if (appart?.hasAnimal == true)
                            const PastilleInfo(
                              icone: Icons.pets_rounded,
                              texte: 'Animal',
                              couleur: AppColors.aVerifier,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        switch (td.motif) {
                          MotifDisponible.absence =>
                            'Libérée suite à l’absence d’une collègue',
                          MotifDisponible.transfert => 'Libérée par transfert',
                          MotifDisponible.surplus => 'Tâche en surplus',
                        },
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.grisDark,
                        ),
                      ),
                    ],
                  ),
                ),
                if (td.visibilite == VisibiliteType.employeSpecifique)
                  const Tooltip(
                    message: 'Le responsable vous propose cette tâche',
                    child: PastilleInfo(
                      icone: Icons.star_rounded,
                      texte: 'Pour vous',
                      couleur: AppColors.rouge,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.grisMedium),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: isProcessing ? null : onPrendre,
              icon: isProcessing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_task_rounded, size: 18),
              label: Text(isProcessing ? 'Prise en charge…' : 'Je la prends'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.fait,
                disabledBackgroundColor: AppColors.fait.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Petite pastille icône + texte (période, taille, durée…).
class PastilleInfo extends StatelessWidget {
  final IconData icone;
  final String texte;
  final Color couleur;
  const PastilleInfo({
    super.key,
    required this.icone,
    required this.texte,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: couleur),
          const SizedBox(width: 4),
          Text(
            texte,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: couleur),
          ),
        ],
      ),
    );
  }
}

// ── Confirmation ───────────────────────────────────────────

class _DialogueConfirmation extends StatelessWidget {
  final TacheDisponible tacheDisponible;
  final VoidCallback onConfirmer;

  const _DialogueConfirmation({
    required this.tacheDisponible,
    required this.onConfirmer,
  });

  @override
  Widget build(BuildContext context) {
    final tj = tacheDisponible.tacheJour;
    final appart = tj?.appartement;
    final date = tj?.dateDuJour;
    final minutes = tj?.minutesEstimees ?? 0;
    final jour = date == null
        ? 'votre journée'
        : 'votre journée du ${DateFormat('EEEE d MMMM', 'fr_FR').format(date)}';

    Widget ligne(IconData icone, String libelle, String valeur) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Icon(icone, size: 18, color: AppColors.grisDark),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                child: Text(libelle,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.grisDark)),
              ),
              Expanded(
                child: Text(
                  valeur,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );

    return DialogueApp(
      titre: 'Prendre cette tâche ?',
      libelleSecondaire: 'Annuler',
      libelleAction: 'Je la prends',
      onAction: onConfirmer,
      contenu: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ligne(
              Icons.apartment_rounded,
              'Appartement',
              appart == null
                  ? '—'
                  : 'Apt. ${appart.numero} (${appart.taille})'),
          ligne(Icons.event_rounded, 'Jour', libelleJourDisponible(date)),
          ligne(
            tj?.periode == PeriodeType.am
                ? Icons.wb_sunny_outlined
                : Icons.nights_stay_outlined,
            'Période',
            tj?.periode == PeriodeType.am ? 'Matin' : 'Après-midi',
          ),
          if (minutes > 0)
            ligne(Icons.schedule_rounded, 'Durée',
                DateHelper.minutesEnHeures(minutes)),
          const SizedBox(height: 12),
          Text(
            'Elle sera ajoutée à $jour et vous en serez responsable.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.grisDark),
          ),
        ],
      ),
    );
  }
}
