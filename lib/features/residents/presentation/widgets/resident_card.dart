import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/resident.dart';
import 'desactivation_dialog.dart';
import 'pin_attribution_dialog.dart';

class ResidentCard extends StatelessWidget {
  final Resident resident;
  final Future<bool> Function(String pin) onAttribuerPin;
  final Future<bool> Function() onDesactiver;
  final Future<bool> Function() onActiver;

  const ResidentCard({
    super.key,
    required this.resident,
    required this.onAttribuerPin,
    required this.onDesactiver,
    required this.onActiver,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSizes.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              // Avatar initiales
              _Avatar(initiales: resident.initiales, isActif: resident.isActif),
              const SizedBox(width: AppSizes.md),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resident.nomComplet,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: resident.isActif
                            ? AppColors.noir
                            : AppColors.grisDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (resident.numeroAppartement != null)
                          Text(
                            'Apt ${resident.numeroAppartement}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.grisText),
                          ),
                        if (resident.numeroAppartement != null)
                          const SizedBox(width: 6),
                        _StatutBadge(statut: resident.statut),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              if (resident.isActif) ...[
                _ActionBtn(
                  icon: Icons.key_rounded,
                  tooltip: resident.aPin ? 'Modifier PIN' : 'Attribuer PIN',
                  color: AppColors.aVerifier,
                  onTap: () => _ouvrirPin(context),
                ),
                const SizedBox(width: AppSizes.xs),
                _ActionBtn(
                  icon: Icons.block_rounded,
                  tooltip: 'Désactiver',
                  color: AppColors.rouge,
                  onTap: () => _ouvrirDesactivation(context),
                ),
              ] else
                _ActionBtn(
                  icon: Icons.check_circle_outline_rounded,
                  tooltip: 'Réactiver',
                  color: AppColors.fait,
                  onTap: onActiver,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ouvrirPin(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => PinAttributionDialog(
        nomComplet: resident.nomComplet,
        onConfirmer: onAttribuerPin,
      ),
    );
  }

  Future<void> _ouvrirDesactivation(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => DesactivationDialog(
        nomComplet: resident.nomComplet,
        onConfirmer: onDesactiver,
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String initiales;
  final bool isActif;

  const _Avatar({required this.initiales, required this.isActif});

  @override
  Widget build(BuildContext context) {
    final color = isActif ? AppColors.rouge : AppColors.grisMedium;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initiales,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ── Badge statut ──────────────────────────────────────────

class _StatutBadge extends StatelessWidget {
  final String statut;
  const _StatutBadge({required this.statut});

  Color get _color => switch (statut) {
        'Inscrit'  => AppColors.fait,
        'Sans app' => AppColors.aVerifier,
        _          => AppColors.grisDark,
      };

  IconData get _icon => switch (statut) {
        'Inscrit'  => Icons.phone_android_rounded,
        'Sans app' => Icons.description_rounded,
        _          => Icons.block_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icon, size: 11, color: _color),
        const SizedBox(width: 3),
        Text(
          statut,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _color,
          ),
        ),
      ],
    );
  }
}

// ── Bouton action compact ─────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}
