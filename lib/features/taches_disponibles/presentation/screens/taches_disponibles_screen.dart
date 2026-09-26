import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../../domain/entities/tache_disponible.dart';
import '../providers/tache_disponible_provider.dart';
import '../widgets/tache_disponible_widgets.dart';
import 'package:cleanops/core/widgets/espace_barre_mobile.dart';

enum _FiltrePeriode { toutes, matin, apresMidi }

/// Tâches libérées par l'équipe (absence, transfert, surplus) que la
/// préposée peut ajouter à sa journée : du jour même et des jours à venir,
/// regroupées par jour. La prise en charge se confirme avant l'envoi.
class TachesDisponiblesScreen extends ConsumerStatefulWidget {
  const TachesDisponiblesScreen({super.key});

  @override
  ConsumerState<TachesDisponiblesScreen> createState() =>
      _TachesDisponiblesScreenState();
}

class _TachesDisponiblesScreenState
    extends ConsumerState<TachesDisponiblesScreen> {
  _FiltrePeriode _filtre = _FiltrePeriode.toutes;

  @override
  void initState() {
    super.initState();
    Future.microtask(_charger);
  }

  Future<void> _charger() => rechargerTachesDisponibles(ref);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tacheDisponibleNotifierProvider);
    final compact = estCompact(context);
    final marge = compact ? 12.0 : 24.0;

    final visibles = [
      for (final td in state.taches)
        if (switch (_filtre) {
          _FiltrePeriode.toutes => true,
          _FiltrePeriode.matin => td.tacheJour?.periode == PeriodeType.am,
          _FiltrePeriode.apresMidi => td.tacheJour?.periode == PeriodeType.pm,
        })
          td,
    ];
    final n = state.taches.length;

    return PageAvecEnTete(
      chargement: state.isLoading && state.taches.isNotEmpty,
      enTete: EnTetePage(
        icone: Icons.assignment_add,
        titre: 'Tâches disponibles',
        sousTitre: n == 0
            ? 'Tâches libérées par l’équipe, à prendre en charge'
            : '$n tâche${n > 1 ? 's' : ''} à prendre',
      ),
      contenu: Padding(
        padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BarreSection(
              titre: '${switch (_filtre) {
                _FiltrePeriode.toutes => 'À prendre',
                _FiltrePeriode.matin => 'Le matin',
                _FiltrePeriode.apresMidi => 'L’après-midi',
              }} (${visibles.length})',
              onRetour: () => context.backOrHome(AppRoutes.employeeDashboard),
              filtres: [
                FiltreSection(
                  icone: Icons.inbox_outlined,
                  infoBulle: 'Toutes les tâches',
                  actif: _filtre == _FiltrePeriode.toutes,
                  onTap: () => setState(() => _filtre = _FiltrePeriode.toutes),
                ),
                FiltreSection(
                  icone: Icons.wb_sunny_outlined,
                  infoBulle: 'Le matin',
                  actif: _filtre == _FiltrePeriode.matin,
                  onTap: () => setState(() => _filtre = _FiltrePeriode.matin),
                ),
                FiltreSection(
                  icone: Icons.nights_stay_outlined,
                  infoBulle: 'L’après-midi',
                  actif: _filtre == _FiltrePeriode.apresMidi,
                  onTap: () =>
                      setState(() => _filtre = _FiltrePeriode.apresMidi),
                ),
              ],
              actions: [
                ActionSection(
                  icone: Icons.refresh_rounded,
                  infoBulle: 'Actualiser',
                  onPressed: state.isLoading ? null : _charger,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.rouge,
                onRefresh: _charger,
                child: _liste(state, visibles),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liste(TacheDisponibleState state, List<TacheDisponible> visibles) {
    final padding =
        const EdgeInsets.only(bottom: AppSizes.lg).plusBarre(context);
    ListView simple(Widget enfant) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          children: [enfant],
        );

    if (state.isLoading && state.taches.isEmpty) {
      return simple(const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.rouge)),
      ));
    }
    if (state.error != null && state.taches.isEmpty) {
      return simple(Padding(
        padding: const EdgeInsets.only(top: AppSizes.xl),
        child: AppErrorNotice(error: state.error!, onRetry: _charger),
      ));
    }
    if (visibles.isEmpty) {
      return simple(
          _EtatVide(filtre: _filtre, autres: state.taches.isNotEmpty));
    }

    // Regroupement par jour (la liste arrive triée par date puis période).
    final groupes = <(DateTime?, List<TacheDisponible>)>[];
    for (final td in visibles) {
      final date = td.tacheJour?.dateDuJour;
      if (groupes.isNotEmpty && groupes.last.$1 == date) {
        groupes.last.$2.add(td);
      } else {
        groupes.add((date, [td]));
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        for (final (i, (date, taches)) in groupes.indexed) ...[
          if (i > 0) const SizedBox(height: AppSizes.lg),
          _TitreJour(titre: libelleJourDisponible(date), nombre: taches.length),
          const SizedBox(height: AppSizes.sm),
          LayoutBuilder(builder: (context, c) {
            final deux = c.maxWidth >= 680;
            final largeur = deux ? (c.maxWidth - AppSizes.md) / 2 : c.maxWidth;
            return Wrap(
              spacing: AppSizes.md,
              runSpacing: AppSizes.md,
              children: [
                for (final td in taches)
                  SizedBox(
                    width: largeur,
                    child: CarteTacheDisponible(
                      key: ValueKey(td.id),
                      tacheDisponible: td,
                      isProcessing: state.processingIds.contains(td.id),
                      onPrendre: () => prendreTacheDisponible(context, ref, td),
                    ),
                  ),
              ],
            );
          }),
        ],
      ],
    );
  }
}

// ── Titre d'un jour ────────────────────────────────────────

class _TitreJour extends StatelessWidget {
  final String titre;
  final int nombre;
  const _TitreJour({required this.titre, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '${titre.toUpperCase()} · $nombre',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.grisDark,
        ),
      ),
    );
  }
}

// ── État vide ──────────────────────────────────────────────

class _EtatVide extends StatelessWidget {
  final _FiltrePeriode filtre;

  /// Des tâches existent, mais pas pour la période filtrée.
  final bool autres;

  const _EtatVide({required this.filtre, required this.autres});

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined,
              size: 52, color: AppColors.grisMedium),
          const SizedBox(height: 14),
          Text(
            autres
                ? filtre == _FiltrePeriode.matin
                    ? 'Aucune tâche disponible le matin'
                    : 'Aucune tâche disponible l’après-midi'
                : 'Aucune tâche disponible',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            autres
                ? 'D’autres tâches sont disponibles : affichez toutes les '
                    'périodes.'
                : 'Vous serez prévenue dès qu’une tâche est libérée. Tirez '
                    'vers le bas pour actualiser.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.grisDark),
          ),
        ],
      ),
    );
  }
}
