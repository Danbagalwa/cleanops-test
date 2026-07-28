import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/appartement.dart';

class AppartementListItem extends StatelessWidget {
  final Appartement appartement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isAlternate;

  const AppartementListItem({
    super.key,
    required this.appartement,
    required this.onEdit,
    required this.onDelete,
    this.isAlternate = false,
  });

  Color get _tailleColor {
    switch (appartement.taille) {
      case '2 1/2':
        return AppColors.jourVert;
      case '3 1/2':
        return AppColors.absent;
      case '4 1/2':
        return AppColors.rouge;
      case '5 1/2':
        return AppColors.aVerifier;
      default:
        return AppColors.grisDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return isDesktop ? _buildRow(context) : _buildCard(context);
  }

  // ── Desktop : row fine type table ────────────────────────
  Widget _buildRow(BuildContext context) {
    return Material(
      color: isAlternate
          ? AppColors.grisLight.withValues(alpha: 0.4)
          : Colors.white,
      child: InkWell(
        onTap: onEdit,
        hoverColor: AppColors.rouge.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 8,
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.rouge.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  size: 16,
                  color: AppColors.rouge,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                flex: 2,
                child: Text(
                  'Apt. ${appartement.numero}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.noir,
                  ),
                ),
              ),
              Expanded(
                child: _TailleBadge(
                  taille: appartement.taille,
                  color: _tailleColor,
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: AppColors.grisText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${appartement.minutesBase} min',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.grisText,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 96,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _IconBtn(
                      icon: Icons.edit_outlined,
                      color: AppColors.absent,
                      tooltip: 'Modifier',
                      onTap: onEdit,
                    ),
                    _IconBtn(
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.rouge,
                      tooltip: 'Supprimer',
                      onTap: onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile : card compacte ───────────────────────────────
  Widget _buildCard(BuildContext context) {
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
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.rouge.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  size: 20,
                  color: AppColors.rouge,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Apt. ${appartement.numero}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.noir,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _TailleBadge(
                          taille: appartement.taille,
                          color: _tailleColor,
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: AppColors.grisText,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${appartement.minutesBase} min',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.grisText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.absent,
                onPressed: onEdit,
                tooltip: 'Modifier',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppColors.rouge,
                onPressed: onDelete,
                tooltip: 'Supprimer',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TailleBadge extends StatelessWidget {
  final String taille;
  final Color color;

  const _TailleBadge({required this.taille, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        taille,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
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
