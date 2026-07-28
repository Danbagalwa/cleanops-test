import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/semaine.dart';

class MiniCalendrierWidget extends StatelessWidget {
  final List<JourSemaine> jours;
  final Function(JourSemaine)? onJourTap;

  const MiniCalendrierWidget({
    super.key,
    required this.jours,
    this.onJourTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: jours.asMap().entries.map((entry) {
          final index = entry.key;
          final jour = entry.value;
          return _JourItem(
            jour: jour,
            onTap: () => onJourTap?.call(jour),
          )
              .animate(delay: Duration(milliseconds: index * 80))
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.3, end: 0);
        }).toList(),
      ),
    );
  }
}

class _JourItem extends StatelessWidget {
  final JourSemaine jour;
  final VoidCallback onTap;

  const _JourItem({required this.jour, required this.onTap});

  Color get _couleurStatut {
    switch (jour.statut) {
      case StatutJour.complete:
        return AppColors.jourVert;
      case StatutJour.enCours:
        return AppColors.jourJaune;
      case StatutJour.nonCommence:
        return AppColors.jourBlanc;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = jour.estAujourdhui;
    final nomCourt = jour.nom.substring(0, 3).toUpperCase();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: AppSizes.sm,
        ),
        decoration: BoxDecoration(
          color:
              isToday ? AppColors.rouge.withValues(alpha:0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: isToday
              ? Border.all(color: AppColors.rouge.withValues(alpha:0.3), width: 1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nom du jour
            Text(
              nomCourt,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isToday ? AppColors.rouge : AppColors.grisDark,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: AppSizes.xs),

            // Numéro du jour
            Text(
              jour.date.day.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday ? AppColors.rouge : AppColors.noir,
              ),
            ),

            const SizedBox(height: AppSizes.xs),

            // Indicateur statut
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: jour.numeroTaches == 0
                    ? Colors.transparent
                    : _couleurStatut,
                border: jour.numeroTaches == 0
                    ? Border.all(color: AppColors.grisMedium, width: 1)
                    : null,
              ),
            ),

            const SizedBox(height: AppSizes.xs),

            // Nombre de tâches
            if (jour.numeroTaches > 0)
              Text(
                '${jour.numeroTaches}t',
                style: TextStyle(
                  fontSize: 10,
                  color: isToday ? AppColors.rouge : AppColors.grisDark,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
