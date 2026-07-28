import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../providers/resident_espace_provider.dart';
import '../widgets/nouvelle_demande_sheet.dart';
import '../widgets/tab_accueil.dart';

class ResidentAccueilScreen extends ConsumerStatefulWidget {
  const ResidentAccueilScreen({super.key});

  @override
  ConsumerState<ResidentAccueilScreen> createState() =>
      _ResidentAccueilScreenState();
}

class _ResidentAccueilScreenState
    extends ConsumerState<ResidentAccueilScreen> {
  Future<void> _ouvrirNouvelleDemande() async {
    final taches = ref.read(residentEspaceNotifierProvider).tachesNonFaites;
    if (!mounted) return;

    final result = await showNouvelleDemandeModal(
      context,
      tachesDisponibles: taches,
    );

    if (result == true && mounted) {
      context.go(AppRoutes.residentDemandes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mon espace',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: TabAccueil(onFaireDemande: _ouvrirNouvelleDemande),
    );
  }
}
