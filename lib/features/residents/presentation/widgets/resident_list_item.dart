import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/resident.dart';

class ResidentListItem extends StatelessWidget {
  final Resident resident;
  final bool isAlternate;
  final VoidCallback onPin;
  final VoidCallback onDesactiver;
  final VoidCallback onActiver;

  const ResidentListItem({
    super.key,
    required this.resident,
    required this.onPin,
    required this.onDesactiver,
    required this.onActiver,
    this.isAlternate = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return isDesktop ? _buildRow() : _buildCard();
  }

  // ── Desktop : ligne type table ───────────────────────────

  Widget _buildRow() {
    final dimmed = !resident.isActif;
    return Material(
      color: isAlternate
          ? AppColors.grisLight.withValues(alpha: 0.4)
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: 9,
        ),
        child: Row(
          children: [
            _AvatarCircle(
              initiales: resident.initiales,
              isActif: resident.isActif,
              size: 30,
              fontSize: 11,
            ),
            const SizedBox(width: AppSizes.sm),

            Expanded(
              flex: 2,
              child: Text(
                resident.nomComplet,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: dimmed ? AppColors.grisDark : AppColors.noir,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            Expanded(
              child: Text(
                resident.numeroAppartement != null
                    ? 'Apt ${resident.numeroAppartement}'
                    : '—',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.grisText,
                ),
              ),
            ),

            Expanded(
              child: _StatutBadge(statut: resident.statut),
            ),

            SizedBox(
              width: 56,
              child: Icon(
                resident.aPin ? Icons.key_rounded : Icons.key_off_rounded,
                size: 16,
                color: resident.aPin ? AppColors.fait : AppColors.grisMedium,
              ),
            ),

            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: resident.isActif
                    ? [
                        _IconBtn(
                          icon: Icons.key_rounded,
                          color: AppColors.aVerifier,
                          tooltip: resident.aPin ? 'Modifier PIN' : 'Attribuer PIN',
                          onTap: onPin,
                        ),
                        _IconBtn(
                          icon: Icons.block_rounded,
                          color: AppColors.rouge,
                          tooltip: 'Désactiver',
                          onTap: onDesactiver,
                        ),
                      ]
                    : [
                        _IconBtn(
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.fait,
                          tooltip: 'Réactiver',
                          onTap: onActiver,
                        ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mobile : card ─────────────────────────────────────────

  Widget _buildCard() {
    final dimmed = !resident.isActif;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: 10,
        ),
        child: Row(
          children: [
            _AvatarCircle(
              initiales: resident.initiales,
              isActif: resident.isActif,
              size: 42,
              fontSize: 14,
            ),
            const SizedBox(width: AppSizes.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    resident.nomComplet,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: dimmed ? AppColors.grisDark : AppColors.noir,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (resident.numeroAppartement != null) ...[
                        Text(
                          'Apt ${resident.numeroAppartement}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.grisText,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      _StatutBadge(statut: resident.statut),
                    ],
                  ),
                ],
              ),
            ),

            if (resident.isActif) ...[
              IconButton(
                icon: const Icon(Icons.key_rounded, size: 18),
                color: AppColors.aVerifier,
                onPressed: onPin,
                tooltip: resident.aPin ? 'Modifier PIN' : 'Attribuer PIN',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.block_rounded, size: 18),
                color: AppColors.rouge,
                onPressed: onDesactiver,
                tooltip: 'Désactiver',
                visualDensity: VisualDensity.compact,
              ),
            ] else
              IconButton(
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                color: AppColors.fait,
                onPressed: onActiver,
                tooltip: 'Réactiver',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Sous-widgets ──────────────────────────────────────────

class _AvatarCircle extends StatelessWidget {
  final String initiales;
  final bool isActif;
  final double size;
  final double fontSize;

  const _AvatarCircle({
    required this.initiales,
    required this.isActif,
    required this.size,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActif ? AppColors.rouge : AppColors.grisMedium;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initiales,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final String statut;
  const _StatutBadge({required this.statut});

  Color get _color => switch (statut) {
        'Inscrit' => AppColors.fait,
        'Sans app' => AppColors.aVerifier,
        _ => AppColors.grisDark,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Text(
        statut,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
