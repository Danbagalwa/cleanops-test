import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/demande_equipe.dart';
import '../screens/document_demande_screen.dart';

/// Petite puce cliquable montrant le document joint à une demande, s'il y en
/// a un. Vide (aucune taille prise) sinon.
class PieceJointeDemande extends StatelessWidget {
  final DemandeEquipe demande;
  const PieceJointeDemande({super.key, required this.demande});

  @override
  Widget build(BuildContext context) {
    if (!demande.aDocument) return const SizedBox.shrink();

    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DocumentDemandeScreen(
          demandeId: demande.id,
          nom: demande.documentNom!,
        ),
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.grisLight,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(color: AppColors.grisMedium),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file_rounded,
                size: 14, color: AppColors.grisDark),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                demande.documentNom!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.grisDark,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
