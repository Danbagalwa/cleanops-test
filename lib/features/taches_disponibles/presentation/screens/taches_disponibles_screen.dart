import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../../domain/entities/tache_disponible.dart';
import '../providers/tache_disponible_provider.dart';

// ── Notification résident lors de la prise en charge (Option B) ──
Future<void> _notifierResidentPrise({
  required String appartementId,
  required String? tacheJourId,
  required String prenomEmployee,
}) async {
  try {
    final residents = await SupabaseService
        .table(SupabaseService.residents)
        .select('id')
        .eq('appartement_id', appartementId)
        .eq('is_actif', true)
        .eq('a_application', true);

    if ((residents as List).isEmpty) return;

    final rows = residents.map((r) => {
          'resident_id': r['id'],
          if (tacheJourId != null) 'tache_jour_id': tacheJourId,
          'type': 'Transfert',
          'message':
              'Votre ménage a été confirmé et sera effectué par $prenomEmployee.',
        }).toList();

    await SupabaseService
        .table(SupabaseService.notificationsResidents)
        .insert(rows);
  } catch (_) {}
}

class TachesDisponiblesScreen extends ConsumerStatefulWidget {
  const TachesDisponiblesScreen({super.key});

  @override
  ConsumerState<TachesDisponiblesScreen> createState() =>
      _TachesDisponiblesScreenState();
}

class _TachesDisponiblesScreenState
    extends ConsumerState<TachesDisponiblesScreen> {
  final DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final employee = ref.read(employeeCourantProvider);
      if (employee != null) {
        ref
            .read(tacheDisponibleNotifierProvider.notifier)
            .charger(employeeId: employee.id, date: _date);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tacheDisponibleNotifierProvider);
    final employee = ref.watch(employeeCourantProvider);

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tâches disponibles',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            if (state.taches.isNotEmpty)
              Text(
                '${state.taches.length} tâche${state.taches.length > 1 ? 's' : ''} à prendre',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              if (employee != null) {
                ref
                    .read(tacheDisponibleNotifierProvider.notifier)
                    .charger(employeeId: employee.id, date: _date);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: () async {
          if (employee != null) {
            await ref
                .read(tacheDisponibleNotifierProvider.notifier)
                .charger(employeeId: employee.id, date: _date);
          }
        },
        child: state.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.rouge))
            : state.taches.isEmpty
                ? const _EmptyState()
                : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.md, vertical: AppSizes.lg),
                        itemCount: state.taches.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSizes.sm),
                        itemBuilder: (context, i) {
                          final td = state.taches[i];
                          return _TacheDisponibleCard(
                            tacheDisponible: td,
                            employeeId: employee?.id ?? '',
                            isProcessing:
                                state.processingIds.contains(td.id),
                          );
                        },
                      ),
                    ),
                  ),
      ),
    );
  }
}

// ── Carte tâche disponible ─────────────────────────────────
class _TacheDisponibleCard extends ConsumerWidget {
  final TacheDisponible tacheDisponible;
  final String employeeId;
  final bool isProcessing;

  const _TacheDisponibleCard({
    required this.tacheDisponible,
    required this.employeeId,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tj = tacheDisponible.tacheJour;
    final appart = tj?.appartement;

    final periodeColor = tj?.periode == PeriodeType.am
        ? AppColors.absent
        : AppColors.aVerifier;
    final periodeLabel = tj?.periode == PeriodeType.am ? 'Matin' : 'Après-midi';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── En-tête ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Numéro / appartement
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: periodeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tj?.periode == PeriodeType.am
                            ? Icons.wb_sunny_outlined
                            : Icons.nights_stay_outlined,
                        color: periodeColor,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appart != null ? 'Apt ${appart.numero} (${appart.taille})' : 'Appartement ${tj?.appartementId ?? ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.noir,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _Chip(label: periodeLabel, color: periodeColor),
                          const SizedBox(width: 6),
                          if (appart != null)
                            _Chip(
                              label: '${appart.minutesBase} min',
                              color: AppColors.grisDark,
                            ),
                          if (tacheDisponible.motif ==
                              MotifDisponible.absence) ...[
                            const SizedBox(width: 6),
                            const _Chip(
                              label: 'Absence',
                              color: AppColors.rouge,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bouton prendre ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.md, 0, AppSizes.md, AppSizes.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isProcessing
                    ? null
                    : () => _prendreEnCharge(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.fait,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text(
                        'Je prends cette tâche',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _prendreEnCharge(BuildContext context, WidgetRef ref) async {
    final employee = ref.read(employeeCourantProvider);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await ref
        .read(tacheDisponibleNotifierProvider.notifier)
        .prendreEnCharge(
          tacheDisponibleId: tacheDisponible.id,
          employeeId: employeeId,
        );

    if (ok) {
      final appart = tacheDisponible.tacheJour?.appartement;
      if (appart != null && employee != null) {
        await _notifierResidentPrise(
          appartementId: appart.id,
          tacheJourId: tacheDisponible.tacheJourId,
          prenomEmployee: employee.prenom,
        );
      }
    }

    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Tâche ajoutée à votre journée !'
              : ref.read(tacheDisponibleNotifierProvider).error ??
                  'Erreur lors de la prise en charge.'),
          backgroundColor: ok ? AppColors.fait : AppColors.rouge,
        ),
      );
    }
  }
}

// ── Petit badge ────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── État vide ──────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: AppColors.grisMedium),
          SizedBox(height: AppSizes.md),
          Text(
            'Aucune tâche disponible',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.grisDark),
          ),
          SizedBox(height: AppSizes.xs),
          Text(
            'Revenez plus tard ou actualisez.',
            style: TextStyle(color: AppColors.grisText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
