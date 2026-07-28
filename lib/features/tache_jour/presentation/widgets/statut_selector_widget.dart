import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/tache_jour.dart';
import '../providers/tache_jour_provider.dart';

class StatutSelectorWidget extends ConsumerStatefulWidget {
  final TacheJour tache;
  final String dateStr;

  const StatutSelectorWidget({
    super.key,
    required this.tache,
    required this.dateStr,
  });

  static Future<void> show(
    BuildContext context,
    TacheJour tache,
    String dateStr,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatutSelectorWidget(tache: tache, dateStr: dateStr),
    );
  }

  @override
  ConsumerState<StatutSelectorWidget> createState() =>
      _StatutSelectorWidgetState();
}

class _StatutSelectorWidgetState extends ConsumerState<StatutSelectorWidget> {
  late StatutTache _statut;
  late TextEditingController _motifCtrl;
  bool _saving = false;

  static const _options = [
    (StatutTache.fait, 'Fait', Icons.check_circle_outline_rounded,
        AppColors.fait),
    (StatutTache.absent, 'Absent', Icons.door_back_door_outlined,
        AppColors.absent),
    (StatutTache.refus, 'Refus', Icons.block_rounded, AppColors.refus),
    (StatutTache.annule, 'Annulé', Icons.cancel_outlined, AppColors.annule),
    (StatutTache.nonCommence, 'Non commencé',
        Icons.radio_button_unchecked_rounded, AppColors.nonCommence),
  ];

  @override
  void initState() {
    super.initState();
    _statut = widget.tache.statut;
    _motifCtrl =
        TextEditingController(text: widget.tache.motifAbsent ?? '');
  }

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  Color _statutColor(StatutTache s) {
    return switch (s) {
      StatutTache.fait => AppColors.fait,
      StatutTache.absent => AppColors.absent,
      StatutTache.refus => AppColors.refus,
      StatutTache.annule => AppColors.annule,
      StatutTache.nonCommence => AppColors.nonCommence,
    };
  }

  Future<void> _confirmer() async {
    if (_statut == StatutTache.absent &&
        _motifCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez indiquer un motif d\'absence.'),
          backgroundColor: AppColors.refus,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final ok = await ref
        .read(tacheJourNotifierProvider(widget.dateStr).notifier)
        .updateStatut(
          id: widget.tache.id,
          statut: _statut,
          motifAbsent:
              _statut == StatutTache.absent ? _motifCtrl.text.trim() : null,
        );

    if (mounted) {
      if (ok) {
        Navigator.of(context).pop();
      } else {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la mise à jour.'),
            backgroundColor: AppColors.rouge,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.tache.appartement;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSizes.md,
          right: AppSizes.md,
          top: 12,
          bottom: AppSizes.md + bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Handle ──────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grisMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Titre ───────────────────────────────────
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.rouge.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    appt != null ? 'Apt. ${appt.numero}' : 'Tâche',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.rouge,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.tache.jour} · ${widget.tache.periode.label}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.grisDark,
                  ),
                ),
                if (appt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    appt.taille,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.grisText,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSizes.md),

            // ── Options de statut ────────────────────────
            ..._options.map((opt) {
              final (statut, label, icon, color) = opt;
              final isSelected = _statut == statut;

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  onTap: () => setState(() => _statut = statut),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(
                        color: isSelected
                            ? color.withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: isSelected ? color : AppColors.grisMedium,
                        ),
                        const SizedBox(width: 12),
                        Icon(icon, size: 18, color: isSelected ? color : AppColors.grisDark),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? color : AppColors.noir,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            // ── Champ motif (si Absent) ──────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _statut == StatutTache.absent
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: TextField(
                        controller: _motifCtrl,
                        autofocus: true,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Motif d\'absence *',
                          hintText: 'Ex: Résident absent, accès refusé...',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusSm),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusSm),
                            borderSide:
                                const BorderSide(color: AppColors.absent, width: 2),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: AppSizes.md),

            // ── Bouton confirmer ─────────────────────────
            FilledButton(
              onPressed: _saving ? null : _confirmer,
              style: FilledButton.styleFrom(
                backgroundColor: _statutColor(_statut),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Confirmer',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
