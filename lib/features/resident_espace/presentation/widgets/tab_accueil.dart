import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/entities/tache_resident.dart';
import '../providers/resident_espace_provider.dart';

// Formatage dates en français
const _kJours = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche'
];
const _kMois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre'
];

String _fmtDate(DateTime d) =>
    '${_kJours[d.weekday - 1]} ${d.day} ${_kMois[d.month - 1]}';

String _fmtDateCourt(DateTime d) => '${d.day} ${_kMois[d.month - 1]}';

// ─────────────────────────────────────────────────────────

class TabAccueil extends ConsumerWidget {
  final VoidCallback onFaireDemande;
  const TabAccueil({super.key, required this.onFaireDemande});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(residentEspaceNotifierProvider);

    if (state.isLoadingTaches && state.taches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorTaches != null && state.taches.isEmpty) {
      return _ErrorState(
        message: state.errorTaches!,
        onRetry: () =>
            ref.read(residentEspaceNotifierProvider.notifier).chargerTaches(),
      );
    }

    final menageAujourdhui = state.menageAujourdhui;
    final prochaines = state.prochaines;
    final dernierMenage = state.dernierMenage;
    // Prochain ≠ aujourd'hui (pour le header Scénario B)
    final prochainHorsAujourdhui =
        prochaines.where((t) => !t.estAujourdhui).firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = MediaQuery.of(context).size.width >= 900;
        final hPad = isDesktop
            ? (constraints.maxWidth - 680) / 2
            : AppSizes.md.toDouble();

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(residentEspaceNotifierProvider.notifier).chargerTaches(),
          child: ListView(
            padding:
                EdgeInsets.symmetric(horizontal: hPad, vertical: AppSizes.md),
            children: [
              // ── Bandeau notifications non lues ────────────
              if (state.nombreNotificationsNonLues > 0) ...[
                _NotifBanner(
                  count: state.nombreNotificationsNonLues,
                  lastMessage: state.notificationsNonLues.first.message,
                  onTap: () async {
                    await ref
                        .read(residentEspaceNotifierProvider.notifier)
                        .toutMarquerLu();
                    if (context.mounted) {
                      context.go(AppRoutes.residentDemandes);
                    }
                  },
                ),
                const SizedBox(height: AppSizes.md),
              ],

              // ── Header scénario A ou B ─────────────────────
              if (menageAujourdhui != null)
                _CarteAujourdhui(tache: menageAujourdhui)
              else if (prochainHorsAujourdhui != null)
                _CarteProchain(tache: prochainHorsAujourdhui)
              else
                _CarteAucunMenage(),

              const SizedBox(height: AppSizes.md),

              // ── Dernier ménage effectué ────────────────────
              if (dernierMenage != null) ...[
                _DernierMenageCard(tache: dernierMenage),
                const SizedBox(height: AppSizes.md),
              ],

              // ── Bouton faire une demande ───────────────────
              OutlinedButton.icon(
                onPressed: onFaireDemande,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Faire une demande'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rouge,
                  side: const BorderSide(color: AppColors.rouge),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                ),
              ),

              // ── Prochains ménages ──────────────────────────
              if (prochaines.isNotEmpty) ...[
                const SizedBox(height: AppSizes.lg),
                const _SectionHeader('Prochains ménages'),
                const SizedBox(height: AppSizes.sm),
                ...prochaines.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.sm),
                      child: _MenageRow(tache: t),
                    )),
              ] else if (!state.isLoadingTaches) ...[
                const SizedBox(height: AppSizes.lg),
                const _EmptyProchains(),
              ],

              const SizedBox(height: AppSizes.lg),
            ],
          ),
        );
      },
    );
  }
}

// ── Carte Scénario A — ménage aujourd'hui ─────────────────

class _CarteAujourdhui extends StatelessWidget {
  final TacheResident tache;
  const _CarteAujourdhui({required this.tache});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.faitBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.fait.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.fait,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Votre ménage est confirmé pour aujourd\'hui',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.fait,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tache.periodeDisplayLabel}'
                  '${tache.prenomPreposee != null ? ' · ${tache.prenomPreposee}' : ''}',
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.grisDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte Scénario B — prochain ménage ────────────────────

class _CarteProchain extends StatelessWidget {
  final TacheResident tache;
  const _CarteProchain({required this.tache});

  @override
  Widget build(BuildContext context) {
    final date = tache.dateReelle;
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.rouge, AppColors.rougeFonce],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.rouge.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prochain ménage',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            _fmtDate(date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined,
                  color: Colors.white70, size: 15),
              const SizedBox(width: 4),
              Text(
                tache.periodeDisplayLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (tache.prenomPreposee != null) ...[
                const Text('  ·  ',
                    style: TextStyle(color: Colors.white38, fontSize: 14)),
                const Icon(Icons.person_outline_rounded,
                    color: Colors.white70, size: 15),
                const SizedBox(width: 4),
                Text(
                  tache.prenomPreposee!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Aucun ménage à venir ───────────────────────────────────

class _CarteAucunMenage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: const Column(
        children: [
          Icon(Icons.home_work_rounded, size: 40, color: AppColors.grisDark),
          SizedBox(height: AppSizes.sm),
          Text(
            'Votre prochain ménage est momentanément en attente.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.noir),
          ),
          SizedBox(height: 4),
          Text(
            'Vous serez informé dès qu\'une date est confirmée.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.grisDark),
          ),
        ],
      ),
    );
  }
}

// ── Dernier ménage effectué ───────────────────────────────

class _DernierMenageCard extends StatelessWidget {
  final TacheResident tache;
  const _DernierMenageCard({required this.tache});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.faitBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.history_rounded,
                size: 18, color: AppColors.fait),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dernier ménage effectué',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.grisText,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  _fmtDate(tache.dateReelle),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.noir),
                ),
              ],
            ),
          ),
          if (tache.prenomPreposee != null)
            Text(
              tache.prenomPreposee!,
              style: const TextStyle(fontSize: 13, color: AppColors.grisDark),
            ),
        ],
      ),
    );
  }
}

// ── Ligne de ménage dans la liste des prochains ───────────

class _MenageRow extends StatelessWidget {
  final TacheResident tache;
  const _MenageRow({required this.tache});

  @override
  Widget build(BuildContext context) {
    final estAujourdhui = tache.estAujourdhui;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: estAujourdhui
              ? AppColors.fait.withValues(alpha: 0.4)
              : AppColors.grisMedium,
        ),
      ),
      child: Row(
        children: [
          // Icône date
          Column(
            children: [
              Text(
                '${tache.dateReelle.day}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: estAujourdhui ? AppColors.fait : AppColors.rouge,
                ),
              ),
              Text(
                _kMois[tache.dateReelle.month - 1].substring(0, 3),
                style: const TextStyle(fontSize: 11, color: AppColors.grisDark),
              ),
            ],
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtDateCourt(tache.dateReelle),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.noir),
                ),
                Text(
                  tache.periodeDisplayLabel,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.grisDark),
                ),
              ],
            ),
          ),
          // Badge statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: estAujourdhui ? AppColors.faitBg : AppColors.grisLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  estAujourdhui
                      ? Icons.check_circle_outline_rounded
                      : Icons.schedule_rounded,
                  size: 12,
                  color: estAujourdhui ? AppColors.fait : AppColors.grisDark,
                ),
                const SizedBox(width: 4),
                Text(
                  estAujourdhui ? 'Confirmé' : 'Prévu',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: estAujourdhui ? AppColors.fait : AppColors.grisDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Composants partagés ───────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.noir,
        ),
      );
}

class _EmptyProchains extends StatelessWidget {
  const _EmptyProchains();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 40, color: AppColors.grisText),
            SizedBox(height: AppSizes.sm),
            Text(
              'Aucun ménage planifié à venir',
              style: TextStyle(fontSize: 14, color: AppColors.grisText),
            ),
          ],
        ),
      );
}

// ── Bandeau notification non lue ─────────────────────────

class _NotifBanner extends StatelessWidget {
  final int count;
  final String lastMessage;
  final VoidCallback onTap;

  const _NotifBanner({
    required this.count,
    required this.lastMessage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.rouge.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.rouge.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_rounded,
                      size: 22, color: AppColors.rouge),
                  if (count > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: AppColors.rouge,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$count',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Text(
                  lastMessage,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.rouge,
                      fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.rouge),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 48, color: AppColors.grisText),
              const SizedBox(height: AppSizes.md),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.grisDark)),
              const SizedBox(height: AppSizes.md),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
}
