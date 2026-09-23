import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';
import '../../domain/entities/demande_equipe.dart';
import '../providers/demande_equipe_provider.dart';
import '../widgets/piece_jointe_demande.dart';

class DemandesEquipeResponsableScreen extends ConsumerWidget {
  const DemandesEquipeResponsableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demandesEquipeResponsableProvider);

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.backOrHome(AppRoutes.employerDashboard),
        ),
        title: Row(
          children: [
            const Text(
              'Demandes équipe',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            if (state.badgeEnAttente > 0) ...[
              const SizedBox(width: AppSizes.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.badgeEnAttente}',
                  style: const TextStyle(
                    color: AppColors.rouge,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
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
                  ref.read(demandesEquipeResponsableProvider.notifier).charger(),
            ),
        ],
      ),
      body: state.isLoading && state.demandes.isEmpty
          ? const AppSkeletonList()
          : state.demandes.isEmpty
              ? const _Empty()
              : RefreshIndicator(
                  color: AppColors.rouge,
                  onRefresh: () => ref
                      .read(demandesEquipeResponsableProvider.notifier)
                      .charger(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final hPad = constraints.maxWidth >= 900
                          ? (constraints.maxWidth - 680) / 2
                          : AppSizes.md.toDouble();
                      return ListView(
                        padding: EdgeInsets.symmetric(
                            horizontal: hPad, vertical: AppSizes.md),
                        children: [
                          if (state.enAttente.isNotEmpty) ...[
                            _SectionHeader(
                                'En attente (${state.enAttente.length})'),
                            const SizedBox(height: AppSizes.sm),
                            ...state.enAttente.map((d) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSizes.sm),
                                  child: _DemandeCard(demande: d),
                                )),
                            const SizedBox(height: AppSizes.md),
                          ],
                          if (state.resolues.isNotEmpty) ...[
                            const _SectionHeader('Traitées'),
                            const SizedBox(height: AppSizes.sm),
                            ...state.resolues.map((d) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSizes.sm),
                                  child: _DemandeCard(demande: d),
                                )),
                          ],
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}

// ── Carte demande ──────────────────────────────────────────

class _DemandeCard extends ConsumerWidget {
  final DemandeEquipe demande;
  const _DemandeCard({required this.demande});

  static const _mois = [
    'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
    'juil', 'août', 'sep', 'oct', 'nov', 'déc',
  ];

  String _fmt(DateTime d) => '${d.day} ${_mois[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = demande.employee;
    final nomComplet = employee != null
        ? '${employee.prenom} ${employee.nom}'
        : 'Employé·e';
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
              AvatarProfil(
                proprietaire: ProprietairePhoto(
                    TypeProprietairePhoto.employe, demande.employeeId),
                initiales:
                    nomComplet.isNotEmpty ? nomComplet[0].toUpperCase() : '?',
                rayon: 16,
                couleurFond: AppColors.rouge.withValues(alpha: 0.12),
                couleurTexte: AppColors.rouge,
                tailleTexte: 12,
                poidsTexte: FontWeight.bold,
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nomComplet,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.noir)),
                    Text(demande.type.libelle,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.grisDark)),
                  ],
                ),
              ),
              _StatutBadge(demande: demande),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              const Icon(Icons.event_rounded,
                  size: 14, color: AppColors.grisText),
              const SizedBox(width: 4),
              Text(periode,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.grisDark)),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(demande.motif,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.grisDark)),
          if (demande.aDocument) ...[
            const SizedBox(height: AppSizes.sm),
            PieceJointeDemande(demande: demande),
          ],
          if (demande.resolue && demande.noteResponsable != null) ...[
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.grisLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(demande.noteResponsable!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.grisDark)),
            ),
          ],
          if (demande.enAttente) ...[
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _traiter(context, ref, approuve: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.refus,
                      side: const BorderSide(color: AppColors.refus),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSm)),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _traiter(context, ref, approuve: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.fait,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSm)),
                    ),
                    child: const Text('Approuver'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _traiter(BuildContext context, WidgetRef ref,
      {required bool approuve}) {
    showDialog(
      context: context,
      builder: (_) => _TraiterDialog(demandeId: demande.id, approuve: approuve),
    );
  }
}

// ── Dialog traitement ─────────────────────────────────────

class _TraiterDialog extends ConsumerStatefulWidget {
  final String demandeId;
  final bool approuve;
  const _TraiterDialog({required this.demandeId, required this.approuve});

  @override
  ConsumerState<_TraiterDialog> createState() => _TraiterDialogState();
}

class _TraiterDialogState extends ConsumerState<_TraiterDialog> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final ok = await ref
        .read(demandesEquipeResponsableProvider.notifier)
        .traiter(
          demandeId: widget.demandeId,
          approuve: widget.approuve,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSending = ref.watch(demandesEquipeResponsableProvider).isSending;
    final color = widget.approuve ? AppColors.fait : AppColors.refus;

    return AlertDialog(
      title: Text(widget.approuve ? 'Approuver la demande ?' : 'Refuser la demande ?'),
      content: TextField(
        controller: _noteCtrl,
        maxLines: 3,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.approuve ? 'Note (optionnelle)' : 'Motif du refus (optionnel)',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
          contentPadding: const EdgeInsets.all(AppSizes.sm),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: isSending ? null : _envoyer,
          style: FilledButton.styleFrom(backgroundColor: color),
          child: isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.approuve ? 'Approuver' : 'Refuser'),
        ),
      ],
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.grisDark,
          letterSpacing: 0.3,
        ),
      );
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
      _ => ('En attente', AppColors.aVerifier.withValues(alpha: 0.15), AppColors.aVerifier),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_rounded, size: 56, color: AppColors.grisText),
            SizedBox(height: AppSizes.md),
            Text('Aucune demande d\'équipe',
                style: TextStyle(fontSize: 16, color: AppColors.grisDark)),
          ],
        ),
      );
}
