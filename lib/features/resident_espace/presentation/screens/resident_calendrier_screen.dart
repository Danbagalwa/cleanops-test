import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../domain/entities/jour_menage.dart';
import '../providers/resident_espace_provider.dart';
import '../widgets/statut_menage_visuel.dart';

/// « Mon calendrier » du résident : un mois, chaque date de ménage colorée
/// selon son statut ; un appui ouvre le détail de la date.
class ResidentCalendrierScreen extends ConsumerStatefulWidget {
  /// Mois ouvert (n'importe quel jour) ; le mois en cours par défaut.
  final DateTime? mois;
  const ResidentCalendrierScreen({super.key, this.mois});

  @override
  ConsumerState<ResidentCalendrierScreen> createState() =>
      _ResidentCalendrierScreenState();
}

class _ResidentCalendrierScreenState
    extends ConsumerState<ResidentCalendrierScreen> {
  late DateTime _mois;

  @override
  void initState() {
    super.initState();
    final m = widget.mois ?? DateTime.now();
    _mois = DateTime(m.year, m.month);
  }

  void _decaler(int n) =>
      setState(() => _mois = DateTime(_mois.year, _mois.month + n));

  @override
  Widget build(BuildContext context) {
    final calendrier = ref.watch(calendrierResidentProvider(_mois));
    final marge = estCompact(context) ? 12.0 : 24.0;
    final titreMois = DateFormat('MMMM yyyy', 'fr_FR').format(_mois);

    return PageAvecEnTete(
      chargement: calendrier.isLoading && calendrier.hasValue,
      enTete: const EnTetePage(
        icone: Icons.calendar_month_rounded,
        titre: 'Mon calendrier',
        sousTitre: 'Mes dates de ménage',
      ),
      contenu: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: () => ref.refresh(calendrierResidentProvider(_mois).future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
              .plusBarre(context),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BarreSection(
                      titre: 'Mes dates de ménage',
                      onRetour: () =>
                          context.backOrHome(AppRoutes.residentDashboard),
                    ),
                    const SizedBox(height: AppSizes.md),
                    CarteContenu(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Mois précédent',
                                onPressed: () => _decaler(-1),
                                icon: const Icon(Icons.chevron_left_rounded,
                                    color: AppColors.noir, size: 28),
                              ),
                              Expanded(
                                child: Text(
                                  '${titreMois[0].toUpperCase()}'
                                  '${titreMois.substring(1)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.noir,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Mois suivant',
                                onPressed: () => _decaler(1),
                                icon: const Icon(Icons.chevron_right_rounded,
                                    color: AppColors.noir, size: 28),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          calendrier.when(
                            skipLoadingOnRefresh: true,
                            skipLoadingOnReload: true,
                            loading: () =>
                                const _GrilleMois(mois: null, calendrier: null),
                            error: (_, __) => _Erreur(
                              onReessayer: () => ref.invalidate(
                                  calendrierResidentProvider(_mois)),
                            ),
                            data: (c) =>
                                _GrilleMois(mois: _mois, calendrier: c),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    const CarteContenu(
                      padding: EdgeInsets.all(AppSizes.md),
                      child: LegendeCalendrier(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grille du mois (lundi → dimanche). [mois] null : chargement.
class _GrilleMois extends StatelessWidget {
  final DateTime? mois;
  final CalendrierMenages? calendrier;
  const _GrilleMois({required this.mois, required this.calendrier});

  @override
  Widget build(BuildContext context) {
    const jours = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];
    final m = mois;
    final auj = DateTime.now();

    return LayoutBuilder(builder: (context, c) {
      final cellule = c.maxWidth / 7;
      final pastille = math.min(40.0, cellule - 6);

      Widget ligneJours() => Row(
            children: [
              for (final j in jours)
                SizedBox(
                  width: cellule,
                  child: Text(
                    j,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grisDark,
                    ),
                  ),
                ),
            ],
          );

      if (m == null) {
        return Column(
          children: [
            ligneJours(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: CircularProgressIndicator(color: AppColors.rouge),
            ),
          ],
        );
      }

      final decalage = DateTime(m.year, m.month, 1).weekday - 1;
      final nbJours = DateTime(m.year, m.month + 1, 0).day;
      final cases = decalage + nbJours;
      final lignes = (cases / 7).ceil();

      return Column(
        children: [
          ligneJours(),
          const SizedBox(height: 10),
          for (var l = 0; l < lignes; l++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  for (var k = 0; k < 7; k++)
                    SizedBox(
                      width: cellule,
                      height: pastille + 4,
                      child: () {
                        final numero = l * 7 + k - decalage + 1;
                        if (numero < 1 || numero > nbJours) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime(m.year, m.month, numero);
                        final menages = calendrier?.du(date) ?? const [];
                        final estAuj = date.year == auj.year &&
                            date.month == auj.month &&
                            date.day == auj.day;
                        final pastilleJour = PastilleJour(
                          jour: numero,
                          statut: menages.firstOrNull?.statut,
                          aujourdhui: estAuj,
                          taille: pastille,
                        );
                        if (menages.isEmpty) return Center(child: pastilleJour);
                        return Center(
                          child: Tooltip(
                            message:
                                '${dateLongue(date)} · ${menages.first.statut.legende}',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () =>
                                  context.push(AppRoutes.residentMenage(date)),
                              child: pastilleJour,
                            ),
                          ),
                        );
                      }(),
                    ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _Erreur extends StatelessWidget {
  final VoidCallback onReessayer;
  const _Erreur({required this.onReessayer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 40, color: AppColors.grisText),
          const SizedBox(height: 10),
          const Text(
            'Le calendrier n’a pas pu être chargé.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisDark),
          ),
          TextButton(onPressed: onReessayer, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
