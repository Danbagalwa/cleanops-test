import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/demande_resident.dart';
import '../providers/resident_espace_provider.dart';

const _kJours = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
];
const _kMois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];

String _fmtDate(DateTime d) =>
    '${_kJours[d.weekday - 1]} ${d.day} ${_kMois[d.month - 1]}';

// ─────────────────────────────────────────────────────────

class TabDemandes extends ConsumerWidget {
  final VoidCallback onNouvelleDemande;
  const TabDemandes({super.key, required this.onNouvelleDemande});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(residentEspaceNotifierProvider);
    final demandes = state.demandes;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = MediaQuery.of(context).size.width >= 900;
        final hPad = isDesktop ? (constraints.maxWidth - 680) / 2 : 0.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Bouton nouvelle demande ─────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.md, AppSizes.md, AppSizes.md, 0),
                child: FilledButton.icon(
                  onPressed: onNouvelleDemande,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nouvelle demande'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rouge,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                ),
              ),

              // ── Section PDF ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.md, AppSizes.md, AppSizes.md, 0),
                child: _PdfSection(),
              ),

              // ── Liste demandes ──────────────────────────
              Expanded(
                child: state.isLoadingDemandes && demandes.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : demandes.isEmpty
                        ? _EmptyDemandes(onNouvelleDemande: onNouvelleDemande)
                        : RefreshIndicator(
                            onRefresh: () => ref
                                .read(residentEspaceNotifierProvider.notifier)
                                .chargerDemandes(),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppSizes.md),
                              itemCount: demandes.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSizes.sm),
                              itemBuilder: (context, i) => _DemandeCard(
                                demande: demandes[i],
                                onAccepter: () => ref
                                    .read(residentEspaceNotifierProvider
                                        .notifier)
                                    .accepterProposition(demandes[i].id),
                                onRefuser: () =>
                                    _confirmerRefus(context, ref, demandes[i]),
                              ),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmerRefus(
      BuildContext context, WidgetRef ref, DemandeResident demande) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Refuser la proposition ?'),
        content: const Text(
            'L\'équipe sera informée que vous refusez cette proposition.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(residentEspaceNotifierProvider.notifier)
                  .refuserProposition(demande.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.rouge),
            child: const Text('Confirmer le refus'),
          ),
        ],
      ),
    );
  }
}

// ── Carte demande (vue résident) ──────────────────────────

class _DemandeCard extends StatelessWidget {
  final DemandeResident demande;
  final VoidCallback onAccepter;
  final VoidCallback onRefuser;

  const _DemandeCard({
    required this.demande,
    required this.onAccepter,
    required this.onRefuser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: demande.attendsReponseResident
              ? AppColors.aVerifier.withValues(alpha: 0.6)
              : AppColors.grisMedium,
          width: demande.attendsReponseResident ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête type + date + urgence
          Row(
            children: [
              _TypeIcon(type: demande.type),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeLabel(demande.type),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.noir),
                    ),
                    Row(
                      children: [
                        Text(
                          _fmtDate(demande.createdAt.toLocal()),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.grisDark),
                        ),
                        if (demande.estUrgente) ...[
                          const SizedBox(width: AppSizes.sm),
                          const _UrgenceBadge(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _StatutBadge(statut: demande.statut),
            ],
          ),

          // Motif
          const SizedBox(height: AppSizes.sm),
          Text(
            demande.motif,
            style: const TextStyle(fontSize: 13, color: AppColors.grisDark),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // ── Contenu selon statut ─────────────────────
          const SizedBox(height: AppSizes.sm),

          if (demande.enAttente) _EnAttenteSection(),

          if (demande.repondue) _ReponseeSection(demande: demande,
              onAccepter: onAccepter, onRefuser: onRefuser),

          if (demande.resolue) _ResolueSection(demande: demande),
        ],
      ),
    );
  }

  String _typeLabel(TypeDemande t) => switch (t) {
        TypeDemande.reprogrammer => 'Reprogrammer un ménage',
        TypeDemande.annuler => 'Annuler un ménage',
        TypeDemande.commentaire => 'Commentaire',
      };
}

// ── Section statut EnAttente ──────────────────────────────

class _EnAttenteSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: const Row(
        children: [
          Icon(Icons.schedule_rounded, size: 16, color: AppColors.grisDark),
          SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'Demande envoyée — en attente de réponse',
              style: TextStyle(fontSize: 13, color: AppColors.grisDark),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section statut Repondue ───────────────────────────────

class _ReponseeSection extends StatelessWidget {
  final DemandeResident demande;
  final VoidCallback onAccepter;
  final VoidCallback onRefuser;

  const _ReponseeSection({
    required this.demande,
    required this.onAccepter,
    required this.onRefuser,
  });

  @override
  Widget build(BuildContext context) {
    // Le résident a déjà refusé → en attente d'une nouvelle proposition
    if (demande.residentAccepte == false) {
      return Container(
        padding: const EdgeInsets.all(AppSizes.sm),
        decoration: BoxDecoration(
          color: AppColors.grisLight,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: const Row(
          children: [
            Icon(Icons.loop_rounded, size: 16, color: AppColors.grisDark),
            SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                'Refusée — nouvelle proposition en attente',
                style: TextStyle(fontSize: 13, color: AppColors.grisDark),
              ),
            ),
          ],
        ),
      );
    }

    // En attente de la réponse résident (residentAccepte == null)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Message du responsable
        if (demande.reponse != null && demande.reponse!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: AppColors.grisLight,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Réponse de l\'équipe',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grisDark),
                ),
                const SizedBox(height: 4),
                Text(
                  demande.reponse!,
                  style: const TextStyle(fontSize: 13, color: AppColors.noir),
                ),
              ],
            ),
          ),

        // Proposition date
        if (demande.propositionDate != null) ...[
          const SizedBox(height: AppSizes.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.rouge.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              border: Border.all(
                  color: AppColors.rouge.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_rounded,
                    size: 18, color: AppColors.rouge),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    'Nouveau ménage proposé : '
                    '${_fmtDate(demande.propositionDate!)} — '
                    '${demande.propositionPeriode == 'AM' ? 'Matin' : 'Après-midi'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.rouge,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Boutons Accepter / Refuser
        const SizedBox(height: AppSizes.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onRefuser,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.grisDark,
                  side: const BorderSide(color: AppColors.grisMedium),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusSm),
                  ),
                ),
                child: const Text('Refuser'),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: FilledButton(
                onPressed: onAccepter,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.fait,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusSm),
                  ),
                ),
                child: const Text('Accepter'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Section statut Résolue ────────────────────────────────

class _ResolueSection extends StatelessWidget {
  final DemandeResident demande;
  const _ResolueSection({required this.demande});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.faitBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.fait.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 16, color: AppColors.fait),
              SizedBox(width: AppSizes.sm),
              Text(
                'Demande résolue ✅',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.fait),
              ),
            ],
          ),
          if (demande.propositionDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Date confirmée : ${_fmtDate(demande.propositionDate!)} — '
              '${demande.propositionPeriode == 'AM' ? 'Matin' : 'Après-midi'}',
              style: const TextStyle(fontSize: 12, color: AppColors.fait),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section PDF ───────────────────────────────────────────

class _PdfSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mes dates de ménage',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.grisDark),
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Expanded(
                child: _PdfButton(
                  icon: Icons.calendar_today_rounded,
                  label: 'Toute l\'année',
                  onTap: () => _aVenir(context),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: _PdfButton(
                  icon: Icons.date_range_rounded,
                  label: 'Période choisie',
                  onTap: () => _aVenir(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 13, color: AppColors.aVerifier),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Ces dates peuvent être sujettes à modifications',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.grisDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _aVenir(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cette fonctionnalité sera bientôt disponible'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _PdfButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PdfButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.grisLight,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: AppColors.rouge),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.noir),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets partagés ──────────────────────────────────

class _TypeIcon extends StatelessWidget {
  final TypeDemande type;
  const _TypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      TypeDemande.reprogrammer => (Icons.calendar_month_rounded, AppColors.rouge),
      TypeDemande.annuler => (Icons.cancel_rounded, AppColors.refus),
      TypeDemande.commentaire => (Icons.chat_bubble_rounded, AppColors.absent),
    };
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final StatutDemande statut;
  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (statut) {
      StatutDemande.enAttente =>
        ('En attente', AppColors.grisLight, AppColors.grisDark),
      StatutDemande.repondue =>
        ('Répondue', AppColors.aVerifier.withValues(alpha: 0.15), AppColors.aVerifier),
      StatutDemande.resolue =>
        ('Résolue', AppColors.faitBg, AppColors.fait),
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

class _UrgenceBadge extends StatelessWidget {
  const _UrgenceBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.aVerifier.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('Urgent',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.aVerifier)),
      );
}

class _EmptyDemandes extends StatelessWidget {
  final VoidCallback onNouvelleDemande;
  const _EmptyDemandes({required this.onNouvelleDemande});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_rounded,
                  size: 56, color: AppColors.grisText),
              const SizedBox(height: AppSizes.md),
              const Text(
                'Aucune demande pour le moment',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.noir),
              ),
              const SizedBox(height: 4),
              const Text(
                'Reprogrammez, annulez un ménage ou laissez un commentaire.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.grisDark),
              ),
              const SizedBox(height: AppSizes.lg),
              FilledButton.icon(
                onPressed: onNouvelleDemande,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Faire une demande'),
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.rouge),
              ),
            ],
          ),
        ),
      );
}
