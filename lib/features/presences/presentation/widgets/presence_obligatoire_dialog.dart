import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employes/presentation/providers/employes_provider.dart';
import '../../domain/entities/presence.dart';
import '../providers/presence_provider.dart';

/// Dialog bloquant — s'affiche au login si la préposée n'a pas encore
/// confirmé sa présence du jour. Ne peut pas être fermé sans sélection.
class PresenceObligatoireDialog extends ConsumerWidget {
  final String employeeId;
  const PresenceObligatoireDialog({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(maPresenceNotifierProvider(employeeId));
    final employee = ref.watch(employeeCourantProvider);

    // Ferme automatiquement dès que la présence est confirmée
    ref.listen(maPresenceNotifierProvider(employeeId), (prev, next) {
      if (!next.isLoading && next.maPresence != null && next.error == null) {
        if (context.mounted) Navigator.of(context).pop();
      }
    });

    final maxDialogHeight = MediaQuery.of(context).size.height * 0.88;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: maxDialogHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icône ─────────────────────────────────────
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.absent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.how_to_reg_rounded,
                    color: AppColors.absent, size: 30),
              ),
              const SizedBox(height: AppSizes.md),

              // ── Titre ─────────────────────────────────────
              Text(
                'Bonjour ${employee?.prenom ?? ''} !',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.noir,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Confirmez votre présence\npour aujourd\'hui',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.grisDark),
              ),
              const SizedBox(height: AppSizes.lg),

              // ── Options ───────────────────────────────────
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
                  child: CircularProgressIndicator(color: AppColors.absent),
                )
              else
                _OptionsPresence(employeeId: employeeId),

              // ── Erreur ────────────────────────────────────
              if (state.error != null) ...[
                const SizedBox(height: AppSizes.sm),
                Text(
                  state.error!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.rouge),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Options de présence ────────────────────────────────────

class _OptionsPresence extends ConsumerStatefulWidget {
  final String employeeId;
  const _OptionsPresence({required this.employeeId});

  @override
  ConsumerState<_OptionsPresence> createState() => _OptionsPresenceState();
}

class _OptionsPresenceState extends ConsumerState<_OptionsPresence> {
  bool _preciserHeures = false;
  TimeOfDay _heureDebut = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _heureFin = const TimeOfDay(hour: 13, minute: 0);

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')} h ${t.minute.toString().padLeft(2, '0')}';

  String _fmtDb(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _choisirHeure(bool debut) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: debut ? _heureDebut : _heureFin,
    );
    if (picked == null) return;
    setState(() {
      if (debut) {
        _heureDebut = picked;
      } else {
        _heureFin = picked;
      }
    });
  }

  Future<void> _confirmer(StatutPresence statut) async {
    final responsableIds = ref
        .read(employesNotifierProvider)
        .employes
        .where((e) => e.isResponsable)
        .map((e) => e.id)
        .toList();

    final avecHeures = statut == StatutPresence.present && _preciserHeures;

    await ref
        .read(maPresenceNotifierProvider(widget.employeeId).notifier)
        .confirmer(
          date: DateTime.now(),
          statut: statut,
          responsableIds: responsableIds,
          heureDebut: avecHeures ? _fmtDb(_heureDebut) : null,
          heureFin: avecHeures ? _fmtDb(_heureFin) : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OptionTile(
          icon: Icons.check_circle_outline_rounded,
          label: 'Présente',
          sublabel: 'Toute la journée',
          color: AppColors.fait,
          onTap: () => _confirmer(StatutPresence.present),
        ),
        const SizedBox(height: AppSizes.sm),
        _PreciserHeuresCard(
          active: _preciserHeures,
          heureDebutLabel: _fmt(_heureDebut),
          heureFinLabel: _fmt(_heureFin),
          onToggle: (v) => setState(() => _preciserHeures = v),
          onChoisirDebut: () => _choisirHeure(true),
          onChoisirFin: () => _choisirHeure(false),
          onConfirmer: () => _confirmer(StatutPresence.present),
        ),
        const SizedBox(height: AppSizes.sm),
        _OptionTile(
          icon: Icons.wb_sunny_outlined,
          label: 'Absente ce matin',
          sublabel: 'AM seulement',
          color: AppColors.aVerifier,
          onTap: () => _confirmer(StatutPresence.absentMatin),
        ),
        const SizedBox(height: AppSizes.sm),
        _OptionTile(
          icon: Icons.nights_stay_outlined,
          label: 'Absente cet après-midi',
          sublabel: 'PM seulement',
          color: AppColors.aVerifier,
          onTap: () => _confirmer(StatutPresence.absentApresMidi),
        ),
        const SizedBox(height: AppSizes.sm),
        _OptionTile(
          icon: Icons.person_off_outlined,
          label: 'Absente aujourd\'hui',
          sublabel: 'Toute la journée',
          color: AppColors.refus,
          onTap: () => _confirmer(StatutPresence.absent),
        ),
      ],
    );
  }
}

// ── Précision d'horaire (informatif — registre responsable) ─

class _PreciserHeuresCard extends StatelessWidget {
  final bool active;
  final String heureDebutLabel;
  final String heureFinLabel;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChoisirDebut;
  final VoidCallback onChoisirFin;
  final VoidCallback onConfirmer;

  const _PreciserHeuresCard({
    required this.active,
    required this.heureDebutLabel,
    required this.heureFinLabel,
    required this.onToggle,
    required this.onChoisirDebut,
    required this.onChoisirFin,
    required this.onConfirmer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: active
              ? AppColors.rouge.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: active,
            onChanged: onToggle,
            title: const Text(
              'Préciser mes heures',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Je travaille une partie de la journée seulement',
              style: TextStyle(fontSize: 11.5),
            ),
            secondary: const Icon(Icons.access_time_rounded,
                size: 20, color: AppColors.rouge),
            activeThumbColor: AppColors.rouge,
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: AppSizes.sm),
          ),
          if (active) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.sm, 0, AppSizes.sm, AppSizes.sm),
              child: Row(
                children: [
                  Expanded(
                    child: _HeureButton(
                      label: 'De',
                      heure: heureDebutLabel,
                      onTap: onChoisirDebut,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: AppColors.grisText),
                  ),
                  Expanded(
                    child: _HeureButton(
                      label: 'À',
                      heure: heureFinLabel,
                      onTap: onChoisirFin,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSizes.sm, 0, AppSizes.sm, AppSizes.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 12, color: AppColors.grisText),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Information transmise au responsable à titre de '
                      'registre — n\'affecte pas vos tâches du jour.',
                      style:
                          TextStyle(fontSize: 10.5, color: AppColors.grisText),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.sm, 0, AppSizes.sm, AppSizes.sm),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onConfirmer,
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: const Text('Confirmer ma présence'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.fait,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeureButton extends StatelessWidget {
  final String label;
  final String heure;
  final VoidCallback onTap;

  const _HeureButton({
    required this.label,
    required this.heure,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(color: AppColors.grisMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 10, color: AppColors.grisText)),
            Text(heure,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.noir)),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      sublabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: color.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
