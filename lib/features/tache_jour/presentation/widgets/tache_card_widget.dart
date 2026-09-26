import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../domain/entities/tache_jour.dart';
import '../providers/tache_jour_provider.dart';
import 'statut_selector_widget.dart';
import 'package:cleanops/core/widgets/notification_app.dart';

/// Une tâche de la journée : appartement, taille, durée, repères (animal,
/// notes) et statut. Un appui ouvre le choix du statut ; une tâche à faire
/// se valide aussi d'un geste avec le bouton « Fait ».
class TacheCardWidget extends ConsumerWidget {
  final TacheJour tache;
  final String dateStr;
  final bool isUpdating;
  // inPanel = true : pas de marge/bordure externe (le panneau les fournit)
  final bool inPanel;

  const TacheCardWidget({
    super.key,
    required this.tache,
    required this.dateStr,
    this.isUpdating = false,
    this.inPanel = false,
  });

  static Color couleurStatut(StatutTache s) => switch (s) {
        StatutTache.fait => AppColors.fait,
        StatutTache.absent => AppColors.absent,
        StatutTache.refus => AppColors.refus,
        StatutTache.annule => AppColors.annule,
        StatutTache.nonCommence => AppColors.nonCommence,
      };

  Color get _statutBg => switch (tache.statut) {
        StatutTache.fait => AppColors.faitBg,
        StatutTache.absent => AppColors.absentBg,
        StatutTache.refus => AppColors.refusBg,
        StatutTache.annule => AppColors.annuleBg,
        StatutTache.nonCommence => AppColors.grisLight,
      };

  IconData get _statutIcon => switch (tache.statut) {
        StatutTache.fait => Icons.check_circle_rounded,
        StatutTache.absent => Icons.door_back_door_outlined,
        StatutTache.refus => Icons.block_rounded,
        StatutTache.annule => Icons.cancel_rounded,
        StatutTache.nonCommence => Icons.radio_button_unchecked_rounded,
      };

  Future<void> _marquerFait(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(tacheJourNotifierProvider(dateStr).notifier)
        .updateStatut(id: tache.id, statut: StatutTache.fait);
    if (!context.mounted) return;
    final numero = tache.appartement?.numero;
    ok
        ? NotificationApp.succes(
            context,
            numero == null ? 'Tâche faite.' : 'Apt. $numero : fait.',
          )
        : NotificationApp.erreur(context, 'Erreur lors de la mise à jour.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = _buildContent(context, ref);
    void ouvrir() => StatutSelectorWidget.show(context, tache, dateStr);

    if (inPanel) {
      // Dans un panneau : InkWell simple, pas de bordure ni d'ombre
      return InkWell(onTap: isUpdating ? null : ouvrir, child: content);
    }

    // Mode standalone : carte avec bordure et ombre
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.xs),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: InkWell(
          onTap: isUpdating ? null : ouvrir,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: AppColors.grisMedium),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final appt = tache.appartement;
    final minutes = tache.minutesEstimees;
    final couleur = couleurStatut(tache.statut);
    final aFaire = tache.statut == StatutTache.nonCommence;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Barre de statut colorée ──────────────────────
          Container(width: 4, color: couleur),

          // ── Contenu ──────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.md, 12, 8, 12),
              child: Row(
                children: [
                  // Numéro de tâche
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.rouge.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${tache.numeroTache}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.rouge,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Infos appartement
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appt != null ? 'Apt. ${appt.numero}' : 'Appartement',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.noir,
                            decoration: tache.statut == StatutTache.annule
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (appt != null)
                              _Repere(Icons.straighten_rounded, appt.taille),
                            if (minutes > 0)
                              _Repere(Icons.schedule_rounded,
                                  DateHelper.minutesEnHeures(minutes)),
                            if (appt?.hasAnimal == true)
                              Tooltip(
                                message: (appt?.typeAnimal?.isNotEmpty ?? false)
                                    ? 'Animal : ${appt!.typeAnimal}'
                                    : 'Présence d\'un animal',
                                child: const _Repere(Icons.pets_rounded,
                                    'Animal', AppColors.aVerifier),
                              ),
                            if (appt?.notes?.isNotEmpty ?? false)
                              const _Repere(Icons.notes_rounded, 'Notes'),
                            if (tache.isAjoutee || tache.isTransfertTemp)
                              _Repere(
                                Icons.add_task_rounded,
                                tache.isTransfertTemp
                                    ? 'Transférée'
                                    : 'Ajoutée',
                                AppColors.rouge,
                              ),
                          ],
                        ),
                        if (tache.motifAbsent?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 4),
                          Text(
                            tache.motifAbsent!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.absent,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Statut, ou validation rapide
                  if (isUpdating)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.rouge,
                        ),
                      ),
                    )
                  else if (aFaire)
                    Tooltip(
                      message: 'Marquer comme fait',
                      child: OutlinedButton.icon(
                        onPressed: () => _marquerFait(context, ref),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Fait'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.fait,
                          side: const BorderSide(color: AppColors.fait),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statutBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statutIcon, size: 14, color: couleur),
                          const SizedBox(width: 4),
                          Text(
                            tache.statut.libelle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: couleur,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.grisText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Petit repère sous le numéro d'appartement (taille, durée, animal…).
class _Repere extends StatelessWidget {
  final IconData icone;
  final String texte;
  final Color couleur;
  const _Repere(this.icone, this.texte, [this.couleur = AppColors.grisDark]);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 13, color: couleur),
        const SizedBox(width: 3),
        Text(
          texte,
          style: TextStyle(
            fontSize: 12,
            color: couleur,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
