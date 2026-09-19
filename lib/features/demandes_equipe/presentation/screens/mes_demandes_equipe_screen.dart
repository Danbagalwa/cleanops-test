import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/demande_equipe.dart';
import '../providers/demande_equipe_provider.dart';
import '../widgets/nouvelle_demande_equipe_sheet.dart';

enum _StatutFiltre { tous, enAttente, resolues }

class MesDemandesEquipeScreen extends ConsumerStatefulWidget {
  const MesDemandesEquipeScreen({super.key});

  @override
  ConsumerState<MesDemandesEquipeScreen> createState() =>
      _MesDemandesEquipeScreenState();
}

class _MesDemandesEquipeScreenState
    extends ConsumerState<MesDemandesEquipeScreen> {
  _StatutFiltre _filtre = _StatutFiltre.tous;

  List<DemandeEquipe> _filtrer(List<DemandeEquipe> demandes) {
    return demandes.where((d) {
      return switch (_filtre) {
        _StatutFiltre.tous => true,
        _StatutFiltre.enAttente => d.enAttente,
        _StatutFiltre.resolues => d.resolue,
      };
    }).toList();
  }

  Future<void> _ouvrirNouvelleDemande() async {
    await showNouvelleDemandeEquipeModal(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mesDemandesEquipeNotifierProvider);
    final employee = ref.watch(employeeCourantProvider);
    final filtrees = _filtrer(state.demandes);
    final fallback = employee?.isResponsable == true
        ? AppRoutes.employerDashboard
        : AppRoutes.employeeDashboard;

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.backOrHome(fallback),
        ),
        title: const Text(
          'Mes demandes d\'équipe',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Actualiser',
              onPressed: () =>
                  ref.read(mesDemandesEquipeNotifierProvider.notifier).charger(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvrirNouvelleDemande,
        backgroundColor: AppColors.rouge,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle demande'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              if (state.demandes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSizes.md, AppSizes.md, AppSizes.md, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        _Chip(
                          label: 'Toutes',
                          selected: _filtre == _StatutFiltre.tous,
                          onTap: () =>
                              setState(() => _filtre = _StatutFiltre.tous),
                        ),
                        _Chip(
                          label: 'En attente',
                          selected: _filtre == _StatutFiltre.enAttente,
                          onTap: () => setState(
                              () => _filtre = _StatutFiltre.enAttente),
                        ),
                        _Chip(
                          label: 'Résolues',
                          selected: _filtre == _StatutFiltre.resolues,
                          onTap: () =>
                              setState(() => _filtre = _StatutFiltre.resolues),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: state.isLoading && state.demandes.isEmpty
                    ? const AppSkeletonList()
                    : state.demandes.isEmpty
                        ? _EmptyState(onNouvelleDemande: _ouvrirNouvelleDemande)
                        : filtrees.isEmpty
                            ? const _EmptyFiltre()
                            : RefreshIndicator(
                                color: AppColors.rouge,
                                onRefresh: () => ref
                                    .read(mesDemandesEquipeNotifierProvider
                                        .notifier)
                                    .charger(),
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                      AppSizes.md,
                                      AppSizes.md,
                                      AppSizes.md,
                                      80),
                                  itemCount: filtrees.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: AppSizes.sm),
                                  itemBuilder: (_, i) =>
                                      _DemandeCard(demande: filtrees[i]),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Carte demande ──────────────────────────────────────────

class _DemandeCard extends StatelessWidget {
  final DemandeEquipe demande;
  const _DemandeCard({required this.demande});

  static const _mois = [
    'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
    'juil', 'août', 'sep', 'oct', 'nov', 'déc',
  ];

  String _fmt(DateTime d) => '${d.day} ${_mois[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final periode = demande.dateFin != null
        ? '${_fmt(demande.dateDebut)} → ${_fmt(demande.dateFin!)}'
        : _fmt(demande.dateDebut);

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: demande.enAttente
              ? AppColors.aVerifier.withValues(alpha: 0.5)
              : AppColors.grisMedium,
          width: demande.enAttente ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                demande.type == TypeDemandeEquipe.conge
                    ? Icons.beach_access_rounded
                    : Icons.event_busy_rounded,
                size: 18,
                color: AppColors.rouge,
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  demande.type.libelle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.noir),
                ),
              ),
              _StatutBadge(demande: demande),
            ],
          ),
          const SizedBox(height: 4),
          Text(periode,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.grisDark)),
          const SizedBox(height: AppSizes.sm),
          Text(demande.motif,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.grisDark)),
          if (demande.resolue && demande.noteResponsable != null) ...[
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.grisLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(
                demande.noteResponsable!,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.grisDark),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final DemandeEquipe demande;
  const _StatutBadge({required this.demande});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (demande.statut) {
      _ when demande.estApprouvee => (
          'Approuvée',
          AppColors.faitBg,
          AppColors.fait
        ),
      _ when demande.estRefusee => (
          'Refusée',
          AppColors.refusBg,
          AppColors.refus
        ),
      _ => ('En attente', AppColors.grisLight, AppColors.grisDark),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.rouge.withValues(alpha: 0.1)
                : AppColors.grisLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppColors.rouge : AppColors.grisMedium),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? AppColors.rouge : AppColors.grisDark,
              )),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onNouvelleDemande;
  const _EmptyState({required this.onNouvelleDemande});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_note_rounded,
                size: 56, color: AppColors.grisText),
            const SizedBox(height: AppSizes.md),
            const Text('Aucune demande pour le moment',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.noir)),
            const SizedBox(height: 4),
            const Text('Demandez un congé ou signalez une absence planifiée.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.grisDark)),
            const SizedBox(height: AppSizes.lg),
            FilledButton.icon(
              onPressed: onNouvelleDemande,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Faire une demande'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFiltre extends StatelessWidget {
  const _EmptyFiltre();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppColors.grisText),
          SizedBox(height: AppSizes.md),
          Text('Aucun résultat',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.noir)),
        ],
      ),
    );
  }
}
