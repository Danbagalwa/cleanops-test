import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../reception_sections.dart';

/// Page provisoire d'une section de la vue Réception.
///
/// Chaque section est construite dans un chantier séparé ; en attendant, cette
/// page annonce ce qu'elle permettra de faire. Elle ne lit et n'affiche AUCUNE
/// donnée de l'application.
class ReceptionSectionScreen extends StatelessWidget {
  final ReceptionSection section;

  const ReceptionSectionScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          section.titre,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(section.iconActive, size: 56, color: AppColors.rouge),
                const SizedBox(height: AppSizes.md),
                const Text(
                  'Section en construction',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSizes.sm),
                Text(
                  section.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      height: 1.45, color: AppColors.grisDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
