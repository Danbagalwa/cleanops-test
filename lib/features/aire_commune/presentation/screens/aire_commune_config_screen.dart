import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../domain/entities/reset_aire_commune.dart';
import '../../domain/entities/tache_aire_commune.dart';
import '../providers/aire_commune_provider.dart';
import '../widgets/aire_commune_actions.dart';

class AireCommuneConfigScreen extends ConsumerStatefulWidget {
  const AireCommuneConfigScreen({super.key});

  @override
  ConsumerState<AireCommuneConfigScreen> createState() =>
      _AireCommuneConfigScreenState();
}

class _AireCommuneConfigScreenState
    extends ConsumerState<AireCommuneConfigScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final notifier = ref.read(aireCommuneNotifierProvider.notifier);
      notifier.loadConfig();
      notifier.loadHistoriqueResets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aireCommuneNotifierProvider);
    final marge = estCompact(context) ? 12.0 : 24.0;

    return PageAvecEnTete(
      chargement: state.isLoading || state.isResetting,
      enTete: const EnTetePage(
        icone: Icons.tune_rounded,
        titre: 'Réglages des aires communes',
        sousTitre: 'Remises à zéro et corrections des confirmations',
      ),
      contenu: ListView(
        padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
            .plusBarre(context),
        children: [
          BarreSection(
            titre: 'Réglages',
            onRetour: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.aireCommune),
          ),
          const SizedBox(height: AppSizes.lg),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Section 1 : Remise à zéro manuelle ────
                  const _SectionHeader(label: 'REMISE À ZÉRO MANUELLE'),
                  const SizedBox(height: AppSizes.xs),
                  _ResetCard(isResetting: state.isResetting),

                  const SizedBox(height: AppSizes.lg),

                  // ── Section 2 : Jour de remise à zéro auto ─
                  const _SectionHeader(label: 'REMISE À ZÉRO AUTOMATIQUE'),
                  const SizedBox(height: AppSizes.xs),
                  _JourResetCard(jourActuel: state.jourResetConfig),

                  const SizedBox(height: AppSizes.md),

                  // ── Section 3 : Activer/désactiver auto ────
                  _ResetAutoCard(actif: state.resetAutoActif),

                  const SizedBox(height: AppSizes.lg),

                  // ── Section 4 : Annuler une confirmation ───
                  const _SectionHeader(label: 'ANNULER UNE CONFIRMATION'),
                  const SizedBox(height: AppSizes.xs),
                  _ZonesConfirmeesCard(zones: state.toutesConfirmees),

                  // ── Section 5 : Historique ──────────────────
                  if (state.historiqueResets.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.lg),
                    const _SectionHeader(
                        label: 'HISTORIQUE DES REMISES À ZÉRO'),
                    const SizedBox(height: AppSizes.xs),
                    _HistoriqueCard(resets: state.historiqueResets),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.grisText,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── Card réutilisable ──────────────────────────────────────
Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
  return Container(
    padding: padding ?? const EdgeInsets.all(AppSizes.md),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      border: Border.all(color: const Color(0xFFE7E9F2)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

// ── Section 1 : Reset semaine complète ────────────────────
class _ResetCard extends ConsumerWidget {
  final bool isResetting;
  const _ResetCard({required this.isResetting});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.refus.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: const Icon(Icons.restart_alt_rounded,
                color: AppColors.refus, size: 22),
          ),
          const SizedBox(width: AppSizes.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remettre la semaine à zéro',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.noir)),
                SizedBox(height: 2),
                Text('Remet toutes les zones à "À confirmer"',
                    style: TextStyle(fontSize: 12, color: AppColors.grisText)),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          isResetting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.refus),
                )
              : FilledButton.icon(
                  onPressed: () => remettreAZeroAireCommune(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.refus,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('Remettre à zéro',
                      style: TextStyle(fontSize: 13)),
                ),
        ],
      ),
    );
  }
}

// ── Section 2 : Jour de reset automatique ─────────────────
class _JourResetCard extends ConsumerWidget {
  final String jourActuel;
  const _JourResetCard({required this.jourActuel});

  static const _jours = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_outlined,
                  size: 18, color: AppColors.absent),
              SizedBox(width: 8),
              Text('Jour de reset automatique',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.noir)),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          ..._jours.map((jour) => _JourRadio(
                jour: jour,
                selectionne: jour == jourActuel,
                onChanged: () => ref
                    .read(aireCommuneNotifierProvider.notifier)
                    .updateJourReset(jour),
              )),
        ],
      ),
    );
  }
}

class _JourRadio extends StatelessWidget {
  final String jour;
  final bool selectionne;
  final VoidCallback onChanged;
  const _JourRadio(
      {required this.jour, required this.selectionne, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selectionne
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selectionne ? AppColors.rouge : AppColors.grisText,
            ),
            const SizedBox(width: 10),
            Text(
              jour,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selectionne ? FontWeight.w600 : FontWeight.w400,
                color: selectionne ? AppColors.rouge : AppColors.noir,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section 3 : Reset automatique actif ───────────────────
class _ResetAutoCard extends ConsumerWidget {
  final bool actif;
  const _ResetAutoCard({required this.actif});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.absent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: const Icon(Icons.autorenew_rounded,
                color: AppColors.absent, size: 22),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reset automatique',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.noir)),
                const SizedBox(height: 2),
                Text(
                  actif
                      ? 'Actif — reset chaque semaine'
                      : 'Désactivé — reset manuel seulement',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.grisText),
                ),
              ],
            ),
          ),
          Switch(
            value: actif,
            activeThumbColor: AppColors.rouge,
            onChanged: (val) => ref
                .read(aireCommuneNotifierProvider.notifier)
                .updateResetAuto(val),
          ),
        ],
      ),
    );
  }
}

// ── Section 4 : Zones confirmées (annuler) ─────────────────
class _ZonesConfirmeesCard extends ConsumerWidget {
  final List<TacheAireCommune> zones;
  const _ZonesConfirmeesCard({required this.zones});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (zones.isEmpty) {
      return _card(
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 20, color: AppColors.grisMedium),
            SizedBox(width: 8),
            Text('Aucune zone confirmée cette semaine',
                style: TextStyle(fontSize: 13, color: AppColors.grisText)),
          ],
        ),
      );
    }

    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < zones.length; i++) ...[
            if (i > 0)
              const Divider(
                  height: 1, indent: AppSizes.md, endIndent: AppSizes.md),
            _ZoneConfirmeeRow(zone: zones[i]),
          ],
        ],
      ),
    );
  }
}

class _ZoneConfirmeeRow extends ConsumerWidget {
  final TacheAireCommune zone;
  const _ZoneConfirmeeRow({required this.zone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nomZone = formatZoneAire(zone.zone);
    final heure =
        zone.confirmeLE != null ? DateHelper.formatHeure(zone.confirmeLE!) : '';

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: AppColors.fait),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nomZone,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.noir)),
                if (zone.confirmeParPrenom != null || heure.isNotEmpty)
                  Text(
                    [
                      if (zone.confirmeParPrenom != null)
                        zone.confirmeParPrenom!,
                      if (heure.isNotEmpty) heure,
                    ].join(' — '),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.grisText),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => annulerConfirmationAire(context, ref, zone),
            icon: const Icon(Icons.undo_rounded, size: 15),
            label: const Text('Annuler', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.refus,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section 5 : Historique ─────────────────────────────────
class _HistoriqueCard extends StatelessWidget {
  final List<ResetAireCommune> resets;
  const _HistoriqueCard({required this.resets});

  @override
  Widget build(BuildContext context) {
    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < resets.length; i++) ...[
            if (i > 0)
              const Divider(
                  height: 1, indent: AppSizes.md, endIndent: AppSizes.md),
            _HistoriqueRow(reset: resets[i]),
          ],
        ],
      ),
    );
  }
}

class _HistoriqueRow extends StatelessWidget {
  final ResetAireCommune reset;
  const _HistoriqueRow({required this.reset});

  @override
  Widget build(BuildContext context) {
    final isAuto = reset.automatique;
    final label = isAuto
        ? 'Reset automatique'
        : 'Reset manuel${reset.prenomEffectuePar != null ? " — ${reset.prenomEffectuePar}" : ""}';
    final date =
        '${DateHelper.formatDate(reset.dateReset)}  ${DateHelper.formatHeure(reset.dateReset)}';

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.absent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isAuto ? Icons.autorenew_rounded : Icons.restart_alt_rounded,
              size: 16,
              color: AppColors.absent,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.noir)),
          ),
          Text(date,
              style: const TextStyle(fontSize: 11, color: AppColors.grisText)),
        ],
      ),
    );
  }
}
