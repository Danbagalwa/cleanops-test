import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/reset_aire_commune.dart';
import '../../domain/entities/tache_aire_commune.dart';
import '../providers/aire_commune_provider.dart';

class AireCommuneScreen extends ConsumerStatefulWidget {
  const AireCommuneScreen({super.key});

  @override
  ConsumerState<AireCommuneScreen> createState() => _AireCommuneScreenState();
}

class _AireCommuneScreenState extends ConsumerState<AireCommuneScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final n = ref.read(aireCommuneNotifierProvider.notifier);
      n.loadTaches();
      n.loadHistoriqueResets();
      n.loadConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aireCommuneNotifierProvider);
    final isResponsable = ref.watch(isResponsableProvider);
    final inDetail = state.categorieSelectee != null;

    return PopScope(
      canPop: !inDetail,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref
              .read(aireCommuneNotifierProvider.notifier)
              .deselectionnerCategorie();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.grisLight,
        appBar: AppBar(
          backgroundColor: AppColors.rouge,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: inDetail
                ? () => ref
                    .read(aireCommuneNotifierProvider.notifier)
                    .deselectionnerCategorie()
                : () => context.backOrHome(isResponsable
                    ? AppRoutes.employerDashboard
                    : AppRoutes.employeeDashboard),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                inDetail
                    ? _labelCategorie(state.categorieSelectee!)
                    : 'Aires communes',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (inDetail && state.categorieSelectee != null)
                Text(
                  '${state.getTotalFait(state.categorieSelectee!)} / '
                  '${state.getTotal(state.categorieSelectee!)} zones confirmées',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
          actions: [
            if (!inDetail) ...[
              // ── Bouton rafraîchir ─────────────────────────
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Rafraîchir',
                onPressed: () => ref
                    .read(aireCommuneNotifierProvider.notifier)
                    .loadTaches(),
              ),
              // ── Bouton configuration (responsable uniquement)
              if (isResponsable)
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  tooltip: 'Configuration',
                  onPressed: () => context.push('/aire-commune/config'),
                ),
            ],
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.rouge,
          onRefresh: () =>
              ref.read(aireCommuneNotifierProvider.notifier).loadTaches(),
          child: _buildBody(state, isResponsable),
        ),
      ),
    );
  }

  Widget _buildBody(AireCommuneState state, bool isResponsable) {
    if (state.isLoading && state.tachesParCategorie.isEmpty) {
      return const AppSkeletonList(itemCount: 4);
    }
    if (state.error != null && state.tachesParCategorie.isEmpty) {
      return _ErrorState(
        message: state.error!,
        onRetry: () =>
            ref.read(aireCommuneNotifierProvider.notifier).loadTaches(),
      );
    }
    if (state.tachesParCategorie.isEmpty) {
      return const _EmptyState();
    }
    if (state.categorieSelectee != null) {
      return _DetailCategorie(
        categorie: state.categorieSelectee!,
        taches: state.tachesSelectees,
      );
    }
    return _ListeCategories(
      tachesParCategorie: state.tachesParCategorie,
      historiqueResets: state.historiqueResets,
      isResponsable: isResponsable,
    );
  }

}

// ── Vue liste des catégories ──────────────────────────────
class _ListeCategories extends StatelessWidget {
  final Map<String, List<TacheAireCommune>> tachesParCategorie;
  final List<ResetAireCommune> historiqueResets;
  final bool isResponsable;

  const _ListeCategories({
    required this.tachesParCategorie,
    required this.historiqueResets,
    required this.isResponsable,
  });

  static const _ordre = [
    'Ascenseur',
    'Corridor',
    'Tapis',
    'Chute',
    'Salon',
    'WC'
  ];

  @override
  Widget build(BuildContext context) {
    final categories =
        _ordre.where((c) => tachesParCategorie.containsKey(c)).toList();

    final totalTaches =
        tachesParCategorie.values.fold(0, (s, l) => s + l.length);
    final totalFait = tachesParCategorie.values
        .fold(0, (s, l) => s + l.where((t) => t.estFait).length);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md, vertical: AppSizes.lg),
          children: [
            _BandeauGlobal(totalFait: totalFait, totalTaches: totalTaches),
            // Section historique (responsable uniquement, si données disponibles)
            if (isResponsable && historiqueResets.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              _HistoriqueResets(resets: historiqueResets),
            ],
            const SizedBox(height: AppSizes.md),
            ...categories.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: _CategorieCard(
                  categorie: c,
                  taches: tachesParCategorie[c]!,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bandeau global ─────────────────────────────────────────
class _BandeauGlobal extends StatelessWidget {
  final int totalFait;
  final int totalTaches;
  const _BandeauGlobal({required this.totalFait, required this.totalTaches});

  @override
  Widget build(BuildContext context) {
    final pct = totalTaches > 0 ? totalFait / totalTaches : 0.0;
    final barColor = pct >= 1.0
        ? AppColors.fait
        : pct >= 0.5
            ? AppColors.aVerifier
            : AppColors.rouge;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Avancement global',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.noir),
              ),
              const Spacer(),
              Text(
                '$totalFait / $totalTaches zones',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: barColor),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.grisMedium,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Historique des resets (responsable uniquement) ─────────
class _HistoriqueResets extends StatelessWidget {
  final List<ResetAireCommune> resets;
  const _HistoriqueResets({required this.resets});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 14, color: AppColors.grisText),
              SizedBox(width: 4),
              Text(
                'HISTORIQUE DES RESETS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grisText,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...resets.take(3).map((r) => _ResetRow(reset: r)),
        ],
      ),
    );
  }
}

class _ResetRow extends StatelessWidget {
  final ResetAireCommune reset;
  const _ResetRow({required this.reset});

  @override
  Widget build(BuildContext context) {
    final isAuto = reset.automatique;
    final label = isAuto
        ? 'Reset automatique'
        : 'Reset manuel — ${reset.prenomEffectuePar ?? "inconnu"}';
    final date =
        '${DateHelper.formatDate(reset.dateReset)}  ${DateHelper.formatHeure(reset.dateReset)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isAuto ? Icons.autorenew_rounded : Icons.restart_alt_rounded,
            size: 14,
            color: AppColors.absent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.noir,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            date,
            style:
                const TextStyle(fontSize: 11, color: AppColors.grisText),
          ),
        ],
      ),
    );
  }
}

// ── Carte catégorie ────────────────────────────────────────
class _CategorieCard extends ConsumerWidget {
  final String categorie;
  final List<TacheAireCommune> taches;
  const _CategorieCard({required this.categorie, required this.taches});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = taches.length;
    final fait = taches.where((t) => t.estFait).length;
    final pct = total > 0 ? fait / total : 0.0;
    final isComplete = fait == total && total > 0;

    final barColor = isComplete
        ? AppColors.fait
        : fait > 0
            ? AppColors.aVerifier
            : AppColors.grisText;
    final (icon, color) = _iconData(categorie);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: InkWell(
        onTap: () => ref
            .read(aireCommuneNotifierProvider.notifier)
            .selectCategorie(categorie),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _labelCategorie(categorie),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.noir,
                          ),
                        ),
                        Text(
                          '$fait / $total zones',
                          style: TextStyle(
                            fontSize: 12,
                            color: barColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  isComplete
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.fait, size: 24)
                      : const Icon(Icons.chevron_right_rounded,
                          color: AppColors.grisText),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: AppColors.grisMedium,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vue détail d'une catégorie ─────────────────────────────
class _DetailCategorie extends StatelessWidget {
  final String categorie;
  final List<TacheAireCommune> taches;
  const _DetailCategorie({required this.categorie, required this.taches});

  @override
  Widget build(BuildContext context) {
    if (taches.isEmpty) return const _EmptyState();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md, vertical: AppSizes.lg),
          itemCount: taches.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
          itemBuilder: (context, i) => _ZoneCard(tache: taches[i]),
        ),
      ),
    );
  }
}

// ── Carte zone ─────────────────────────────────────────────
class _ZoneCard extends ConsumerStatefulWidget {
  final TacheAireCommune tache;
  const _ZoneCard({required this.tache});

  @override
  ConsumerState<_ZoneCard> createState() => _ZoneCardState();
}

class _ZoneCardState extends ConsumerState<_ZoneCard> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tache;
    final estFait = t.estFait;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: estFait ? AppColors.faitBg : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: estFait
              ? AppColors.fait.withValues(alpha: 0.3)
              : AppColors.grisMedium,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Icône statut ──────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: estFait
                  ? AppColors.fait.withValues(alpha: 0.12)
                  : AppColors.grisMedium.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Icon(
              estFait
                  ? Icons.check_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: estFait ? AppColors.fait : AppColors.grisText,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSizes.md),

          // ── Nom + détail ──────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatZone(t.zone),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: estFait ? AppColors.fait : AppColors.noir,
                  ),
                ),
                const SizedBox(height: 2),
                if (estFait && t.confirmeParPrenom != null)
                  Text(
                    '${t.confirmeParPrenom}'
                    '${t.confirmeLE != null ? ' — ${DateHelper.formatHeure(t.confirmeLE!)}' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.grisText),
                  )
                else
                  const Text(
                    'À confirmer',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.grisText),
                  ),
              ],
            ),
          ),

          // ── Bouton confirmer ──────────────────────────
          if (!estFait)
            SizedBox(
              height: 36,
              child: FilledButton(
                onPressed: _confirming ? null : _confirmer,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.fait,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSizes.sm),
                ),
                child: _confirming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirmer',
                        style: TextStyle(fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmer() async {
    setState(() => _confirming = true);
    await ref
        .read(aireCommuneNotifierProvider.notifier)
        .confirmerZone(widget.tache.id);
    if (!mounted) return;
    setState(() => _confirming = false);

    final error = ref.read(aireCommuneNotifierProvider).error;
    if (error != null) {
      AppFeedback.showError(context, error);
    }
  }
}

// ── Helpers ────────────────────────────────────────────────
String _labelCategorie(String c) => switch (c) {
      'Ascenseur' => 'Ascenseurs',
      'Corridor' => 'Corridors',
      'Tapis' => 'Tapis',
      'Chute' => 'Chutes',
      'Salon' => 'Salon',
      'WC' => 'WC',
      _ => c,
    };

(IconData, Color) _iconData(String c) => switch (c) {
      'Ascenseur' => (Icons.elevator_rounded, AppColors.absent),
      'Corridor' => (Icons.door_sliding_outlined, AppColors.refus),
      'Tapis' => (Icons.layers_outlined, const Color(0xFF00897B)),
      'Chute' => (Icons.delete_outline_rounded, AppColors.grisText),
      'Salon' => (Icons.weekend_outlined, const Color(0xFF7B1FA2)),
      'WC' => (Icons.wc_rounded, AppColors.rouge),
      _ => (Icons.category_outlined, AppColors.grisText),
    };

String _formatZone(String zone) => zone
    .replaceAll('_Etage_', ' – Étage ')
    .replaceAll('_', ' ');

// ── État vide ──────────────────────────────────────────────
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jour = ref.watch(aireCommuneNotifierProvider).jourResetConfig;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.apartment_outlined,
              size: 64, color: AppColors.grisMedium),
          const SizedBox(height: AppSizes.md),
          const Text(
            'Aucune tâche cette semaine',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.grisDark),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Les zones seront générées $jour matin.',
            style: const TextStyle(color: AppColors.grisText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── État erreur ────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: AppErrorNotice(error: message, onRetry: onRetry),
      ),
    );
  }
}
