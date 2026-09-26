import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/helpers/semaine_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../presences/domain/entities/presence.dart';
import '../../../presences/presentation/providers/presence_provider.dart';
import '../providers/tache_jour_provider.dart';
import '../widgets/tache_card_widget.dart';
import '../../domain/entities/tache_jour.dart';
import 'package:cleanops/core/widgets/espace_barre_mobile.dart';

/// « Ma journée » de la préposée : ses tâches du matin et de l'après-midi.
/// Les jours de la semaine (L M M J V) se choisissent dans la barre ; le jour
/// affiché est aussi dans l'adresse (/journee?date=…), comme depuis le
/// mini-calendrier du tableau de bord.
class TacheJourScreen extends ConsumerStatefulWidget {
  final String? date;
  const TacheJourScreen({super.key, this.date});

  @override
  ConsumerState<TacheJourScreen> createState() => _TacheJourScreenState();
}

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

class _TacheJourScreenState extends ConsumerState<TacheJourScreen> {
  late DateTime _date;

  String get _dateStr => _iso(_date);

  bool get _estAujourdhui => _date == _jour(DateTime.now());

  DateTime _depuisWidget() {
    final demandee = DateTime.tryParse(widget.date ?? '');
    return _jour(demandee ?? DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    _date = _depuisWidget();
    Future.microtask(_rafraichir);
  }

  @override
  void didUpdateWidget(TacheJourScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Même écran, autre jour demandé (mini-calendrier, lien) : on suit.
    final demandee = _depuisWidget();
    if (oldWidget.date != widget.date && demandee != _date) {
      setState(() => _date = demandee);
      Future.microtask(_rafraichir);
    }
  }

  Future<void> _rafraichir() async {
    final emp = ref.read(employeeCourantProvider);
    if (emp == null) return;
    await Future.wait([
      ref
          .read(tacheJourNotifierProvider(_dateStr).notifier)
          .charger(employeeId: emp.id),
      // La présence n'est suivie que pour AUJOURD'HUI : elle est partagée avec
      // le tableau de bord, qui ne doit pas afficher celle d'un autre jour.
      if (_estAujourdhui)
        ref.read(maPresenceNotifierProvider(emp.id).notifier).charger(_date),
    ]);
    if (mounted) ref.invalidate(idsTachesAuPoolProvider);
  }

  void _allerA(DateTime date) {
    final jour = _jour(date);
    if (jour == _date) return;
    setState(() => _date = jour);
    _rafraichir();
    // L'adresse suit le jour affiché (retour, partage, rechargement).
    GoRouter.maybeOf(context)?.go('${AppRoutes.tacheJour}?date=${_iso(jour)}');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tacheJourNotifierProvider(_dateStr));
    final employee = ref.watch(employeeCourantProvider);
    final compact = estCompact(context);
    final marge = compact ? 12.0 : 24.0;

    // Présence connue (celle d'aujourd'hui en pratique) : bandeau d'absence
    // seulement si elle concerne le jour affiché.
    final presence = employee == null
        ? null
        : ref.watch(maPresenceNotifierProvider(employee.id)).maPresence;
    final presenceStatut = presence != null && _jour(presence.date) == _date
        ? presence.statut
        : null;

    // Une absence ne masque PAS les tâches : elles restent visibles chez la
    // préposée tant que le responsable ne les a pas
    //  - transférées à une autre préposée (employee_id change : la requête ne
    //    les renvoie plus), ou
    //  - libérées à l'équipe (elles sont alors dans le pool, statut =
    //    Disponible, et masquées ici).
    final pool = ref.watch(idsTachesAuPoolProvider).valueOrNull ?? const {};
    final am = state.amTaches.where((t) => !pool.contains(t.id)).toList();
    final pm = state.pmTaches.where((t) => !pool.contains(t.id)).toList();

    final nomJour = SemaineHelper.nomJour(_date);
    final aujourdhui = _jour(DateTime.now());
    final lundi = _date.subtract(Duration(days: _date.weekday - 1));

    return PageAvecEnTete(
      chargement: state.isLoading && state.taches.isNotEmpty,
      enTete: EnTetePage(
        icone: Icons.today_rounded,
        titre: 'Ma journée',
        sousTitre: SemaineHelper.libellePourDate(_date),
      ),
      contenu: Padding(
        padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BarreSection(
              titre: '${nomJour[0].toUpperCase()}${nomJour.substring(1)} '
                  '${DateFormat('d MMMM', 'fr_FR').format(_date)}',
              sousTitre: _estAujourdhui ? 'Aujourd’hui' : null,
              onRetour: () => GoRouter.maybeOf(context) == null
                  ? Navigator.of(context).maybePop()
                  : context.backOrHome(AppRoutes.employeeDashboard),
              filtres: [
                for (var i = 0; i < 5; i++)
                  () {
                    final jour = lundi.add(Duration(days: i));
                    return FiltreSection(
                      libelle: const ['L', 'M', 'M', 'J', 'V'][i],
                      infoBulle:
                          DateFormat('EEEE d MMMM', 'fr_FR').format(jour),
                      actif: jour == _date,
                      pastille: jour == aujourdhui,
                      onTap: () => _allerA(jour),
                    );
                  }(),
              ],
              actions: [
                if (!_estAujourdhui)
                  ActionSection(
                    icone: Icons.today_outlined,
                    infoBulle: 'Revenir à aujourd’hui',
                    onPressed: () => _allerA(aujourdhui),
                  ),
                ActionSection(
                  icone: Icons.refresh_rounded,
                  infoBulle: 'Actualiser',
                  onPressed: state.isLoading ? null : _rafraichir,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => _contenu(
                  state: state,
                  am: am,
                  pm: pm,
                  presence: presenceStatut,
                  large: constraints.maxWidth >= 860,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenu({
    required TacheJourState state,
    required List<TacheJour> am,
    required List<TacheJour> pm,
    required StatutPresence? presence,
    required bool large,
  }) {
    // États sans tâches : dans une liste, pour garder « tirer pour actualiser ».
    Widget simple(Widget enfant) => RefreshIndicator(
          color: AppColors.rouge,
          onRefresh: _rafraichir,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.only(bottom: AppSizes.lg).plusBarre(context),
            children: [enfant],
          ),
        );

    if (state.isLoading && state.taches.isEmpty) {
      return const AppSkeletonList(itemCount: 5);
    }
    if (state.error != null && state.taches.isEmpty) {
      return simple(Padding(
        padding: const EdgeInsets.only(top: AppSizes.xl),
        child: AppErrorNotice(error: state.error!, onRetry: _rafraichir),
      ));
    }
    if (am.isEmpty && pm.isEmpty) {
      return simple(
          _EtatVide(jourDeTravail: SemaineHelper.estJourDeTravail(_date)));
    }

    final entete = [
      if (presence != null && presence.estAbsent) ...[
        _AbsenceBanner(statut: presence),
        const SizedBox(height: AppSizes.sm),
      ],
      _Resume(taches: [...am, ...pm]),
      const SizedBox(height: AppSizes.md),
    ];
    final updating = state.updatingIds;

    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...entete,
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.only(bottom: AppSizes.lg).plusBarre(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, periode) in _Periode.values.indexed) ...[
                    if (i > 0) const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: _Panneau(
                        periode: periode,
                        taches: periode == _Periode.matin ? am : pm,
                        dateStr: _dateStr,
                        updatingIds: updating,
                        defilant: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.rouge,
      onRefresh: _rafraichir,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSizes.lg).plusBarre(context),
        children: [
          ...entete,
          _Panneau(
            periode: _Periode.matin,
            taches: am,
            dateStr: _dateStr,
            updatingIds: updating,
          ),
          const SizedBox(height: AppSizes.md),
          _Panneau(
            periode: _Periode.apresMidi,
            taches: pm,
            dateStr: _dateStr,
            updatingIds: updating,
          ),
        ],
      ),
    );
  }
}

// ══ Période (matin / après-midi) ══════════════════════════

enum _Periode {
  matin('Matin', Icons.wb_sunny_outlined, AppColors.absent),
  apresMidi('Après-midi', Icons.nights_stay_outlined, AppColors.aVerifier);

  final String libelle;
  final IconData icone;
  final Color couleur;
  const _Periode(this.libelle, this.icone, this.couleur);
}

/// Tâches d'une période. [defilant] : la liste défile dans le panneau
/// (grand écran, deux panneaux côte à côte) ; sinon hauteur naturelle.
class _Panneau extends StatelessWidget {
  final _Periode periode;
  final List<TacheJour> taches;
  final String dateStr;
  final Set<String> updatingIds;
  final bool defilant;

  const _Panneau({
    required this.periode,
    required this.taches,
    required this.dateStr,
    required this.updatingIds,
    this.defilant = false,
  });

  @override
  Widget build(BuildContext context) {
    final restantes =
        taches.where((t) => t.statut == StatutTache.nonCommence).length;
    Widget carte(int i) => TacheCardWidget(
          key: ValueKey(taches[i].id),
          tache: taches[i],
          dateStr: dateStr,
          isUpdating: updatingIds.contains(taches[i].id),
          inPanel: true,
        );
    const separateur = Divider(height: 1, color: AppColors.grisMedium);

    final liste = taches.isEmpty
        ? _PanneauVide(periode: periode)
        : defilant
            ? ListView.separated(
                itemCount: taches.length,
                separatorBuilder: (_, __) => separateur,
                itemBuilder: (_, i) => carte(i),
              )
            : Column(
                children: [
                  for (var i = 0; i < taches.length; i++) ...[
                    if (i > 0) separateur,
                    carte(i),
                  ],
                ],
              );

    return CarteContenu(
      child: Column(
        mainAxisSize: defilant ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: periode.couleur.withValues(alpha: 0.05),
              border: Border(
                bottom: BorderSide(
                    color: periode.couleur.withValues(alpha: 0.25), width: 1.5),
              ),
            ),
            child: Row(
              children: [
                Icon(periode.icone, color: periode.couleur, size: 20),
                const SizedBox(width: 10),
                Text(
                  periode.libelle.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: AppColors.noir,
                  ),
                ),
                const Spacer(),
                Text(
                  taches.isEmpty
                      ? '0 tâche'
                      : restantes == 0
                          ? 'Terminé ✓'
                          : '$restantes à faire sur ${taches.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: taches.isNotEmpty && restantes == 0
                        ? AppColors.fait
                        : periode.couleur,
                  ),
                ),
              ],
            ),
          ),
          if (defilant) Expanded(child: liste) else liste,
        ],
      ),
    );
  }
}

class _PanneauVide extends StatelessWidget {
  final _Periode periode;
  const _PanneauVide({required this.periode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_rounded,
              size: 34, color: periode.couleur.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text(
            periode == _Periode.matin
                ? 'Aucune tâche le matin'
                : 'Aucune tâche l’après-midi',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.grisText),
          ),
        ],
      ),
    );
  }
}

// ══ Résumé ════════════════════════════════════════════════

class _Resume extends StatelessWidget {
  final List<TacheJour> taches;
  const _Resume({required this.taches});

  @override
  Widget build(BuildContext context) {
    final total = taches.length;
    final confirmees = taches.where((t) => t.estConfirmee).length;
    final restantes = total - confirmees;
    final minutesRestantes = taches
        .where((t) => !t.estConfirmee)
        .fold(0, (s, t) => s + t.minutesEstimees);
    final progression = total > 0 ? confirmees / total : 0.0;
    final complete = total > 0 && restantes == 0;

    return CarteContenu(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.task_alt_rounded,
                  value: '$confirmees / $total',
                  label: 'Confirmées',
                  color: AppColors.fait,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: _Stat(
                  icon: Icons.pending_actions_rounded,
                  value: '$restantes',
                  label: 'À faire',
                  color: restantes == 0 ? AppColors.fait : AppColors.rouge,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: _Stat(
                  icon: Icons.schedule_rounded,
                  value: minutesRestantes > 0
                      ? DateHelper.minutesEnHeures(minutesRestantes)
                      : '—',
                  label: 'Temps restant',
                  color: AppColors.aVerifier,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progression,
              backgroundColor: AppColors.grisMedium,
              color: complete ? AppColors.fait : AppColors.rouge,
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            complete
                ? 'Journée terminée ✓ Bravo !'
                : '${(progression * 100).round()} % de la journée confirmée',
            style: TextStyle(
              fontSize: 12,
              color: complete ? AppColors.fait : AppColors.grisDark,
              fontWeight: complete ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.grisDark),
          ),
        ],
      ),
    );
  }
}

// ══ Bandeaux et états ═════════════════════════════════════

class _AbsenceBanner extends StatelessWidget {
  final StatutPresence statut;
  const _AbsenceBanner({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String message) = switch (statut) {
      StatutPresence.absent => (
          Icons.person_off_outlined,
          AppColors.rouge,
          'Vous êtes absente aujourd\'hui. Vos tâches restent visibles tant que le responsable ne les a pas transférées à une autre préposée ou libérées à l\'équipe.',
        ),
      StatutPresence.absentMatin => (
          Icons.wb_sunny_outlined,
          AppColors.aVerifier,
          'Vous êtes absente ce matin. Vos tâches du matin restent visibles tant que le responsable ne les a pas transférées à une autre préposée ou libérées à l\'équipe.',
        ),
      StatutPresence.absentApresMidi => (
          Icons.nights_stay_outlined,
          AppColors.aVerifier,
          'Vous êtes absente cet après-midi. Vos tâches de l\'après-midi restent visibles tant que le responsable ne les a pas transférées à une autre préposée ou libérées à l\'équipe.',
        ),
      _ => (Icons.info_outline_rounded, AppColors.grisDark, ''),
    };

    if (message.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _EtatVide extends StatelessWidget {
  final bool jourDeTravail;
  const _EtatVide({required this.jourDeTravail});

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          Icon(
            jourDeTravail
                ? Icons.event_available_rounded
                : Icons.weekend_outlined,
            size: 52,
            color: AppColors.grisMedium,
          ),
          const SizedBox(height: 14),
          Text(
            jourDeTravail
                ? 'Aucune tâche pour cette journée'
                : 'Jour non travaillé',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            jourDeTravail
                ? 'Rien n’est planifié pour vous ce jour-là.'
                : 'Choisissez un jour de la semaine (L à V) pour voir vos '
                    'tâches.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.grisDark),
          ),
        ],
      ),
    );
  }
}
