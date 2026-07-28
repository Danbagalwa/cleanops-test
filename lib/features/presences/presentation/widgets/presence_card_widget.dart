import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employes/presentation/providers/employes_provider.dart';
import '../../domain/entities/presence.dart';
import '../providers/presence_provider.dart';

class PresenceCardWidget extends ConsumerStatefulWidget {
  final DateTime date;

  const PresenceCardWidget({super.key, required this.date});

  @override
  ConsumerState<PresenceCardWidget> createState() => _PresenceCardWidgetState();
}

class _PresenceCardWidgetState extends ConsumerState<PresenceCardWidget> {
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final employee = ref.read(employeeCourantProvider);
      if (employee != null) {
        ref
            .read(maPresenceNotifierProvider(employee.id).notifier)
            .charger(widget.date);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(employeeCourantProvider);
    if (employee == null) return const SizedBox.shrink();

    final state = ref.watch(maPresenceNotifierProvider(employee.id));

    // Quitter le mode édition dès qu'une nouvelle présence est confirmée
    ref.listen(maPresenceNotifierProvider(employee.id), (prev, next) {
      if (_editing && !next.isLoading && next.maPresence != null && next.error == null) {
        if (mounted) setState(() => _editing = false);
      }
    });

    final showButtons = state.maPresence == null || _editing;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ───────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.absent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.how_to_reg_outlined,
                    color: AppColors.absent, size: 18),
              ),
              const SizedBox(width: AppSizes.sm),
              const Text(
                'Ma présence',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.noir,
                ),
              ),
              const Spacer(),
              if (state.maPresence != null && !_editing)
                _StatutBadge(statut: state.maPresence!.statut),
            ],
          ),
          const SizedBox(height: AppSizes.md),

          // ── Contenu ───────────────────────────────────
          if (state.isLoading)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.absent),
              ),
            )
          else if (showButtons)
            _ConfirmButtons(
              date: widget.date,
              employeeId: employee.id,
              isEditing: _editing,
              onCancel: _editing
                  ? () => setState(() => _editing = false)
                  : null,
            )
          else
            _PresenceConfirmee(
              presence: state.maPresence!,
              onModifier: () => setState(() => _editing = true),
            ),

          if (state.error != null) ...[
            const SizedBox(height: AppSizes.sm),
            Text(
              state.error!,
              style: const TextStyle(color: AppColors.rouge, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Boutons de confirmation / modification ─────────────────
class _ConfirmButtons extends ConsumerWidget {
  final DateTime date;
  final String employeeId;
  final bool isEditing;
  final VoidCallback? onCancel;

  const _ConfirmButtons({
    required this.date,
    required this.employeeId,
    required this.isEditing,
    this.onCancel,
  });

  Future<List<String>> _getResponsableIds(WidgetRef ref) async {
    return ref
        .read(employesNotifierProvider)
        .employes
        .where((e) => e.isResponsable)
        .map((e) => e.id)
        .toList();
  }

  Future<void> _confirmer(
    BuildContext context,
    WidgetRef ref,
    StatutPresence statut,
  ) async {
    final ids = await _getResponsableIds(ref);
    if (!context.mounted) return;
    await ref
        .read(maPresenceNotifierProvider(employeeId).notifier)
        .confirmer(
          date: date,
          statut: statut,
          responsableIds: ids,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEditing
              ? 'Modifier votre présence :'
              : 'Confirmez votre présence pour aujourd\'hui :',
          style: const TextStyle(fontSize: 13, color: AppColors.grisDark),
        ),
        const SizedBox(height: AppSizes.sm),
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            _Chip(
              label: 'Présente',
              icon: Icons.check_circle_outline,
              color: AppColors.fait,
              onTap: () => _confirmer(context, ref, StatutPresence.present),
            ),
            _Chip(
              label: 'Absente',
              icon: Icons.person_off_outlined,
              color: AppColors.rouge,
              onTap: () => _confirmer(context, ref, StatutPresence.absent),
            ),
            _Chip(
              label: 'Absente matin',
              icon: Icons.wb_sunny_outlined,
              color: AppColors.aVerifier,
              onTap: () =>
                  _confirmer(context, ref, StatutPresence.absentMatin),
            ),
            _Chip(
              label: 'Absente après-midi',
              icon: Icons.nights_stay_outlined,
              color: AppColors.aVerifier,
              onTap: () =>
                  _confirmer(context, ref, StatutPresence.absentApresMidi),
            ),
          ],
        ),
        if (isEditing && onCancel != null) ...[
          const SizedBox(height: AppSizes.sm),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.grisDark,
            ),
            child: const Text('Annuler', style: TextStyle(fontSize: 12)),
          ),
        ],
      ],
    );
  }
}

// ── Présence confirmée (avec bouton Modifier) ──────────────
class _PresenceConfirmee extends StatelessWidget {
  final Presence presence;
  final VoidCallback onModifier;

  const _PresenceConfirmee({
    required this.presence,
    required this.onModifier,
  });

  @override
  Widget build(BuildContext context) {
    final isPresent = presence.statut == StatutPresence.present;
    final color = isPresent ? AppColors.fait : AppColors.rouge;

    return Row(
      children: [
        Icon(
          isPresent
              ? Icons.check_circle_outline
              : Icons.warning_amber_outlined,
          color: color,
          size: 18,
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                presence.statut.libelle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (presence.confirmedLe != null)
                Text(
                  'Confirmé à ${_heure(presence.confirmedLe!)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.grisText),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: onModifier,
          style: TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Modifier', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  String _heure(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
}

// ── Badge statut ──────────────────────────────────────────
class _StatutBadge extends StatelessWidget {
  final StatutPresence statut;
  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final color =
        statut == StatutPresence.present ? AppColors.fait : AppColors.rouge;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statut == StatutPresence.present ? 'Présente' : 'Absente',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Chip action ────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ],
        ),
      ),
    );
  }
}
