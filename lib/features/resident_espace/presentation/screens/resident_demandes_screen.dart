import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/resident_espace_provider.dart';
import '../widgets/nouvelle_demande_sheet.dart';
import '../widgets/tab_demandes.dart';

class ResidentDemandesScreen extends ConsumerStatefulWidget {
  const ResidentDemandesScreen({super.key});

  @override
  ConsumerState<ResidentDemandesScreen> createState() =>
      _ResidentDemandesScreenState();
}

class _ResidentDemandesScreenState
    extends ConsumerState<ResidentDemandesScreen> {
  Future<void> _ouvrirNouvelleDemande() async {
    final taches = ref.read(residentEspaceNotifierProvider).tachesNonFaites;
    if (!mounted) return;

    await showNouvelleDemandeModal(
      context,
      tachesDisponibles: taches,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mes demandes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: TabDemandes(onNouvelleDemande: _ouvrirNouvelleDemande),
    );
  }
}
