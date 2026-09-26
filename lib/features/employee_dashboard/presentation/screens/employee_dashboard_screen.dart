import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/helpers/semaine_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/dashboard_welcome_header.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../../aire_commune/domain/entities/tache_aire_commune.dart';
import '../../../aire_commune/presentation/providers/aire_commune_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../presences/presentation/providers/presence_provider.dart';
import '../../../presences/presentation/widgets/presence_card_widget.dart';
import '../../../presences/presentation/widgets/presence_obligatoire_dialog.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../../../tache_jour/presentation/providers/tache_jour_provider.dart';
import '../../../tache_jour/presentation/widgets/tache_card_widget.dart';
import '../../../taches_disponibles/presentation/providers/tache_disponible_provider.dart';
import '../../../taches_disponibles/presentation/widgets/tache_disponible_widgets.dart';
import '../providers/employee_dashboard_provider.dart';
import '../widgets/message_semaine_widget.dart';
import 'package:cleanops/core/widgets/espace_barre_mobile.dart';

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Jour de travail voisin (week-end sauté) : +1 ou -1.
DateTime _jourDeTravailVoisin(DateTime d, int sens) {
  var j = d.add(Duration(days: sens));
  while (!SemaineHelper.estJourDeTravail(j)) {
    j = j.add(Duration(days: sens));
  }
  return j;
}

/// Tableau de bord de la préposée, dans l'ordre de sa journée :
/// accueil → jour affiché (précédent / suivant) → ses tâches de ce jour, à
/// valider directement → tâches disponibles → aire commune.
class EmployeeDashboardScreen extends ConsumerStatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  ConsumerState<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState
    extends ConsumerState<EmployeeDashboardScreen> {
  bool _presenceDialogShown = false;
  DateTime _date = _jour(DateTime.now());

  bool get _estAujourdhui => _date == _jour(DateTime.now());

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(dashboardNotifierProvider.notifier).charger();

      // Déclenche le check de présence immédiatement. Samedi et dimanche :
      // pas de travail, donc pas de présence à confirmer.
      final employee = ref.read(employeeCourantProvider);
      if (employee != null && SemaineHelper.estJourDeTravail(DateTime.now())) {
        ref
            .read(maPresenceNotifierProvider(employee.id).notifier)
            .charger(DateTime.now());
      }
      _chargerTaches();
      rechargerTachesDisponibles(ref);
      ref.read(aireCommuneNotifierProvider.notifier).loadTaches();
    });
  }

  Future<void> _chargerTaches() async {
    final employee = ref.read(employeeCourantProvider);
    if (employee == null) return;
    await ref
        .read(tacheJourNotifierProvider(_iso(_date)).notifier)
        .charger(employeeId: employee.id);
    if (mounted) ref.invalidate(idsTachesAuPoolProvider);
  }

  Future<void> _rafraichir() => Future.wait([
        ref.read(dashboardNotifierProvider.notifier).rafraichir(),
        _chargerTaches(),
        rechargerTachesDisponibles(ref),
        ref.read(aireCommuneNotifierProvider.notifier).loadTaches(),
      ]);

  void _allerA(DateTime date) {
    setState(() => _date = _jour(date));
    _chargerTaches();
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(employeeCourantProvider);
    final dashState = ref.watch(dashboardNotifierProvider);

    // Force la déclaration de présence au premier chargement
    if (employee != null) {
      ref.listen(maPresenceNotifierProvider(employee.id), (prev, next) {
        if (!_presenceDialogShown &&
            SemaineHelper.estJourDeTravail(DateTime.now()) &&
            prev?.isLoading == true &&
            !next.isLoading &&
            next.maPresence == null &&
            next.error == null) {
          _presenceDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    PresenceObligatoireDialog(employeeId: employee.id),
              );
            }
          });
        }
      });
    }

    final jourSection = [
      _BarreDate(
        date: _date,
        estAujourdhui: _estAujourdhui,
        onPrecedent: () => _allerA(_jourDeTravailVoisin(_date, -1)),
        onSuivant: () => _allerA(_jourDeTravailVoisin(_date, 1)),
        onAujourdhui: () => _allerA(DateTime.now()),
      ),
      // La présence se confirme pour aujourd'hui seulement.
      if (_estAujourdhui) ...[
        const SizedBox(height: AppSizes.md),
        PresenceCardWidget(date: DateTime.now()),
      ],
      if (dashState.messageSemaine != null) ...[
        const SizedBox(height: AppSizes.md),
        MessageSemaineWidget(message: dashState.messageSemaine!),
      ],
      const SizedBox(height: AppSizes.md),
      _SectionMesTaches(date: _date),
    ];
    const autresSections = [
      _SectionTachesDisponibles(),
      SizedBox(height: AppSizes.md),
      _SectionAireCommune(),
    ];

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      body: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _rafraichir,
        // Largeur réellement disponible (barre latérale déduite), pas celle
        // de la fenêtre.
        child: LayoutBuilder(builder: (context, constraints) {
          final large = constraints.maxWidth >= 1000;
          final marge = constraints.maxWidth < kLargeurCompacte
              ? AppSizes.md
              : AppSizes.lg;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(marge).plusBarre(context),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: large ? 1280 : 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DashboardWelcomeHeader(employee: employee),
                      const SizedBox(height: AppSizes.md),
                      if (large)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: jourSection,
                              ),
                            ),
                            const SizedBox(width: AppSizes.lg),
                            const Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: autresSections,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        ...jourSection,
                        const SizedBox(height: AppSizes.md),
                        ...autresSections,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ══ Jour affiché ══════════════════════════════════════════

class _BarreDate extends StatelessWidget {
  final DateTime date;
  final bool estAujourdhui;
  final VoidCallback onPrecedent;
  final VoidCallback onSuivant;
  final VoidCallback onAujourdhui;

  const _BarreDate({
    required this.date,
    required this.estAujourdhui,
    required this.onPrecedent,
    required this.onSuivant,
    required this.onAujourdhui,
  });

  @override
  Widget build(BuildContext context) {
    final jour = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date);
    Widget fleche(IconData icone, String info, VoidCallback onTap) =>
        IconButton(
          tooltip: info,
          onPressed: onTap,
          icon: Icon(icone, color: AppColors.rouge),
          style: IconButton.styleFrom(
            side: const BorderSide(color: AppColors.grisMedium),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );

    return CarteContenu(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          fleche(Icons.chevron_left_rounded, 'Jour précédent', onPrecedent),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${jour[0].toUpperCase()}${jour.substring(1)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.noir,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  SemaineHelper.libellePourDate(date),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.rouge,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (estAujourdhui)
                  const _Etiquette(texte: 'Aujourd’hui')
                else
                  InkWell(
                    onTap: onAujourdhui,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: Text(
                        'Revenir à aujourd’hui',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.rouge,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.rouge,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          fleche(Icons.chevron_right_rounded, 'Jour suivant', onSuivant),
        ],
      ),
    );
  }
}

class _Etiquette extends StatelessWidget {
  final String texte;
  const _Etiquette({required this.texte});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        texte,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.rouge,
        ),
      ),
    );
  }
}

// ══ Cadre commun des sections ═════════════════════════════

class _Section extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String? sousTitre;
  final String? libelleLien;
  final VoidCallback? onLien;
  final Widget child;

  const _Section({
    required this.icone,
    required this.titre,
    required this.child,
    this.sousTitre,
    this.libelleLien,
    this.onLien,
  });

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Icon(icone, color: AppColors.rouge, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: AppColors.noir,
                        ),
                      ),
                      if (sousTitre != null)
                        Text(
                          sousTitre!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.grisDark,
                          ),
                        ),
                    ],
                  ),
                ),
                if (libelleLien != null)
                  TextButton(
                    onPressed: onLien,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.rouge,
                      textStyle: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(libelleLien!),
                        const Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.grisMedium),
          child,
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icone;
  final String texte;
  final VoidCallback? onReessayer;
  const _Message({required this.icone, required this.texte, this.onReessayer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(
        children: [
          Icon(icone, size: 34, color: AppColors.grisMedium),
          const SizedBox(height: 8),
          Text(
            texte,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.grisDark),
          ),
          if (onReessayer != null)
            TextButton(
              onPressed: onReessayer,
              child: const Text('Réessayer'),
            ),
        ],
      ),
    );
  }
}

const _chargement = Padding(
  padding: EdgeInsets.symmetric(vertical: 28),
  child: Center(
    child: SizedBox.square(
      dimension: 24,
      child:
          CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.rouge),
    ),
  ),
);

// ══ Mes tâches du jour ════════════════════════════════════

class _SectionMesTaches extends ConsumerWidget {
  final DateTime date;
  const _SectionMesTaches({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iso = _iso(date);
    final state = ref.watch(tacheJourNotifierProvider(iso));
    final pool = ref.watch(idsTachesAuPoolProvider).valueOrNull ?? const {};
    final am = state.amTaches.where((t) => !pool.contains(t.id)).toList();
    final pm = state.pmTaches.where((t) => !pool.contains(t.id)).toList();
    final toutes = [...am, ...pm];
    final restantes =
        toutes.where((t) => t.statut == StatutTache.nonCommence).toList();
    final minutes = restantes.fold(0, (s, t) => s + t.minutesEstimees);

    Future<void> recharger() async {
      final emp = ref.read(employeeCourantProvider);
      if (emp == null) return;
      await ref
          .read(tacheJourNotifierProvider(iso).notifier)
          .charger(employeeId: emp.id);
    }

    final String? sousTitre;
    if (toutes.isEmpty) {
      sousTitre = null;
    } else if (restantes.isEmpty) {
      sousTitre = 'Toutes confirmées ✓';
    } else {
      sousTitre = '${restantes.length} à faire sur ${toutes.length}'
          '${minutes > 0 ? ' · ${DateHelper.minutesEnHeures(minutes)} restantes' : ''}';
    }

    final Widget contenu;
    if (state.isLoading && state.taches.isEmpty) {
      contenu = _chargement;
    } else if (state.error != null && state.taches.isEmpty) {
      contenu = _Message(
        icone: Icons.wifi_off_rounded,
        texte: 'Vos tâches n’ont pas pu être chargées.',
        onReessayer: recharger,
      );
    } else if (toutes.isEmpty) {
      contenu = _Message(
        icone: SemaineHelper.estJourDeTravail(date)
            ? Icons.event_available_rounded
            : Icons.weekend_outlined,
        texte: SemaineHelper.estJourDeTravail(date)
            ? 'Aucune tâche planifiée pour vous ce jour-là.'
            : 'Jour non travaillé.',
      );
    } else {
      Widget periode(String libelle, IconData icone, Color couleur,
              List<TacheJour> taches) =>
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: couleur.withValues(alpha: 0.05),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                child: Row(
                  children: [
                    Icon(icone, size: 16, color: couleur),
                    const SizedBox(width: 6),
                    Text(
                      libelle.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: couleur,
                      ),
                    ),
                  ],
                ),
              ),
              if (taches.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'Aucune tâche',
                    style: TextStyle(fontSize: 12.5, color: AppColors.grisText),
                  ),
                )
              else
                for (final (i, t) in taches.indexed) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.grisMedium),
                  TacheCardWidget(
                    key: ValueKey(t.id),
                    tache: t,
                    dateStr: iso,
                    isUpdating: state.updatingIds.contains(t.id),
                    inPanel: true,
                  ),
                ],
            ],
          );
      contenu = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          periode('Matin', Icons.wb_sunny_outlined, AppColors.absent, am),
          const Divider(height: 1, color: AppColors.grisMedium),
          periode('Après-midi', Icons.nights_stay_outlined, AppColors.aVerifier,
              pm),
        ],
      );
    }

    return _Section(
      icone: Icons.today_rounded,
      titre: 'Mes tâches',
      sousTitre: sousTitre,
      libelleLien: 'Ma journée',
      onLien: () => context.go('${AppRoutes.tacheJour}?date=$iso'),
      child: contenu,
    );
  }
}

// ══ Tâches disponibles ════════════════════════════════════

class _SectionTachesDisponibles extends ConsumerWidget {
  const _SectionTachesDisponibles();

  static const _apercu = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tacheDisponibleNotifierProvider);
    final n = state.taches.length;

    final Widget contenu;
    if (state.isLoading && state.taches.isEmpty) {
      contenu = _chargement;
    } else if (state.error != null && state.taches.isEmpty) {
      contenu = _Message(
        icone: Icons.wifi_off_rounded,
        texte: 'Les tâches disponibles n’ont pas pu être chargées.',
        onReessayer: () => rechargerTachesDisponibles(ref),
      );
    } else if (n == 0) {
      contenu = const _Message(
        icone: Icons.inbox_outlined,
        texte: 'Aucune tâche à prendre pour le moment.',
      );
    } else {
      contenu = Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, td) in state.taches.take(_apercu).indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              CarteTacheDisponible(
                key: ValueKey(td.id),
                tacheDisponible: td,
                avecJour: true,
                isProcessing: state.processingIds.contains(td.id),
                onPrendre: () => prendreTacheDisponible(context, ref, td),
              ),
            ],
          ],
        ),
      );
    }

    return _Section(
      icone: Icons.assignment_add,
      titre: 'Tâches disponibles',
      sousTitre: n == 0 ? null : '$n à prendre',
      libelleLien: n > _apercu ? 'Tout voir ($n)' : 'Voir',
      onLien: () => context.go(AppRoutes.tachesDisponibles),
      child: contenu,
    );
  }
}

// ══ Aire commune ══════════════════════════════════════════

class _SectionAireCommune extends ConsumerWidget {
  const _SectionAireCommune();

  static const _apercu = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aireCommuneNotifierProvider);
    final zones = state.tachesParCategorie.values.expand((l) => l).toList();
    final faites = zones.where((z) => z.estFait).length;
    final aFaire = zones.where((z) => !z.estFait).toList()
      ..sort((a, b) => comparerZones(a.zone, b.zone));

    final Widget contenu;
    if (state.isLoading && zones.isEmpty) {
      contenu = _chargement;
    } else if (state.error != null && zones.isEmpty) {
      contenu = _Message(
        icone: Icons.wifi_off_rounded,
        texte: 'L’aire commune n’a pas pu être chargée.',
        onReessayer: () =>
            ref.read(aireCommuneNotifierProvider.notifier).loadTaches(),
      );
    } else if (zones.isEmpty) {
      contenu = const _Message(
        icone: Icons.meeting_room_outlined,
        texte: 'Aucune zone planifiée cette semaine.',
      );
    } else {
      contenu = Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: faites / zones.length,
                minHeight: 7,
                color: aFaire.isEmpty ? AppColors.fait : AppColors.rouge,
                backgroundColor: AppColors.grisMedium,
              ),
            ),
            const SizedBox(height: 10),
            // Avancement par catégorie (Corridors 3/10…).
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in AireCategorie.values)
                  if (zones.any((z) => z.categorie == c))
                    () {
                      final total = zones.where((z) => z.categorie == c).length;
                      final ok = zones
                          .where((z) => z.categorie == c && z.estFait)
                          .length;
                      return PastilleInfo(
                        icone: ok == total
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        texte: '${c.libelle} $ok/$total',
                        couleur:
                            ok == total ? AppColors.fait : AppColors.grisDark,
                      );
                    }(),
              ],
            ),
            if (aFaire.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final z in aFaire.take(_apercu)) _LigneZone(zone: z),
              if (aFaire.length > _apercu)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    '+ ${aFaire.length - _apercu} autre'
                    '${aFaire.length - _apercu > 1 ? 's' : ''} zone'
                    '${aFaire.length - _apercu > 1 ? 's' : ''} à faire',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.grisDark),
                  ),
                ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Toutes les zones de la semaine sont faites ✓',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.fait,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return _Section(
      icone: Icons.meeting_room_outlined,
      titre: 'Aire commune',
      sousTitre: zones.isEmpty
          ? 'Cette semaine'
          : 'Cette semaine · $faites/${zones.length} zones faites',
      libelleLien: 'Voir',
      onLien: () => context.go(AppRoutes.aireCommune),
      child: contenu,
    );
  }
}

class _LigneZone extends ConsumerStatefulWidget {
  final TacheAireCommune zone;
  const _LigneZone({required this.zone});

  @override
  ConsumerState<_LigneZone> createState() => _LigneZoneState();
}

class _LigneZoneState extends ConsumerState<_LigneZone> {
  bool _enCours = false;

  Future<void> _confirmer() async {
    setState(() => _enCours = true);
    final notifier = ref.read(aireCommuneNotifierProvider.notifier);
    await notifier.confirmerZone(widget.zone.id);
    if (!mounted) return;
    setState(() => _enCours = false);
    final erreur = ref.read(aireCommuneNotifierProvider).error;
    final nom = formatZoneAire(widget.zone.zone);
    erreur == null
        ? NotificationApp.succes(context, '$nom : fait.')
        : NotificationApp.erreur(context, erreur);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.radio_button_unchecked_rounded,
              size: 16, color: AppColors.grisText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              formatZoneAire(widget.zone.zone),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.noir,
              ),
            ),
          ),
          if (_enCours)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.rouge),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _confirmer,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Fait'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.fait,
                side: const BorderSide(color: AppColors.fait),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                textStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
