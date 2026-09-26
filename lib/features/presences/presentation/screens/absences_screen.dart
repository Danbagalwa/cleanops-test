import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/dialogue_app.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/export_menu_button.dart'
    show showExportSuccess;
import '../../../../core/widgets/mise_en_page.dart';
import '../../../pdf/domain/usecases/generate_absences_export.dart';
import '../../../pdf/presentation/screens/absences_pdf_preview_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employes/presentation/providers/employes_provider.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';
import '../../domain/entities/presence.dart';
import '../providers/presence_provider.dart';
import 'package:cleanops/core/widgets/espace_barre_mobile.dart';
import 'package:cleanops/core/widgets/notification_app.dart';

// ── Helpers ────────────────────────────────────────────────

const _joursNoms = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche'
];
String _nomJour(DateTime date) => _joursNoms[date.weekday - 1];

String _vendrediStr(DateTime date) {
  final daysToFriday = (DateTime.friday - date.weekday + 7) % 7;
  final friday = date.add(Duration(days: daysToFriday));
  return '${friday.year}-${friday.month.toString().padLeft(2, '0')}-${friday.day.toString().padLeft(2, '0')}';
}

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// Tâches du jour pour un employé (toutes périodes)
Future<List<Map<String, dynamic>>> _getTachesAbsent(
    String employeeId, DateTime date) async {
  try {
    final data = await SupabaseService.table(SupabaseService.tachesJour)
        .select('id, appartement_id, periode, statut, appartements(numero)')
        .eq('employee_id', employeeId)
        .eq('semaine_reelle', _dateStr(date))
        .eq('jour', _nomJour(date));
    return (data as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

// Filtre les tâches selon la période d'absence
List<Map<String, dynamic>> _filtrerParPeriode(
    List<Map<String, dynamic>> taches, StatutPresence statut) {
  return switch (statut) {
    StatutPresence.absentMatin =>
      taches.where((t) => (t['periode'] as String?) == 'AM').toList(),
    StatutPresence.absentApresMidi =>
      taches.where((t) => (t['periode'] as String?) == 'PM').toList(),
    _ => taches, // absent toute la journée → toutes les tâches
  };
}

Future<void> _notifierResidents({
  required String appartementId,
  required String? tacheJourId,
  required String type,
  required String message,
}) async {
  // Les résidents SANS application ne voient jamais ces notifications : un avis
  // est créé pour que la Réception (ou le responsable) les prévienne. Cet appel
  // ne doit jamais bloquer l'action d'origine.
  try {
    await SupabaseService.client.rpc(
      'app_creer_avis_residents_sans_app',
      params: {
        'p_appartement_id': appartementId,
        'p_tache_id': tacheJourId,
        'p_type': type,
        'p_message': message,
      },
    );
  } catch (_) {}

  try {
    final residents = await SupabaseService.table(SupabaseService.residents)
        .select('id')
        .eq('appartement_id', appartementId)
        .eq('is_actif', true)
        .eq('a_application', true);

    if ((residents as List).isEmpty) return;
    final rows = residents
        .map((r) => {
              'resident_id': r['id'],
              if (tacheJourId != null) 'tache_jour_id': tacheJourId,
              'type': type,
              'message': message,
            })
        .toList();
    await SupabaseService.table(SupabaseService.notificationsResidents)
        .insert(rows);
  } catch (_) {}
}

Future<void> _notifierEmployes({
  required List<String> employeeIds,
  required String type,
  required String message,
  required String entityId,
}) async {
  try {
    if (employeeIds.isEmpty) return;
    final rows = employeeIds
        .map((id) => {
              'destinataire_id': id,
              'type': type,
              'message': message,
              'entity_id': entityId,
              'entity_type': 'TacheJour',
            })
        .toList();
    await SupabaseService.table(SupabaseService.notifications).insert(rows);
  } catch (_) {}
}

Future<void> _insererHistorique({
  required String type,
  required String entityId,
  required String employeurId,
  required String note,
  required Map<String, dynamic> donneeAvant,
  required Map<String, dynamic> donneeApres,
  bool canUndo = false,
}) async {
  try {
    await SupabaseService.table(SupabaseService.historiqueActions).insert({
      'type': type,
      'entity_id': entityId,
      'entity_type': 'TacheJour',
      'employeur_id': employeurId,
      'note': note,
      'can_undo': canUndo,
      'donnees_avant': donneeAvant,
      'donnees_apres': donneeApres,
    });
  } catch (_) {}
}

// ── Écran principal ────────────────────────────────────────

enum _Periode { jour, semaine, mois, personnalisee }

enum _Type { toutes, journee, matin, apresMidi }

enum _Tri { date, preposee }

DateTime _jourSeul(DateTime d) => DateTime(d.year, d.month, d.day);

class AbsencesScreen extends ConsumerStatefulWidget {
  const AbsencesScreen({super.key});

  @override
  ConsumerState<AbsencesScreen> createState() => _AbsencesScreenState();
}

class _AbsencesScreenState extends ConsumerState<AbsencesScreen> {
  _Periode _periode = _Periode.jour;
  DateTime _debut = _jourSeul(DateTime.now());
  DateTime _fin = _jourSeul(DateTime.now());

  _Type _type = _Type.toutes;
  String _recherche = '';
  _Tri _tri = _Tri.date;
  bool _croissant = false;
  int _page = 0;
  int _parPage = 10;

  /// `null` : choisi selon la largeur (grille sur téléphone, tableau sinon).
  ModeAffichage? _mode;

  Future<void> _charger() =>
      ref.read(absencesNotifierProvider.notifier).charger(_debut, _fin);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _charger();
      ref.read(employesNotifierProvider.notifier).charger();
    });
  }

  // ── Période ────────────────────────────────────────────

  void _appliquer(_Periode periode, DateTime debut, DateTime fin) {
    setState(() {
      _periode = periode;
      _debut = _jourSeul(debut);
      _fin = _jourSeul(fin);
      _page = 0;
    });
    _charger();
  }

  /// Période type contenant [ref] (jour, semaine lundi→dimanche, mois).
  void _choisir(_Periode periode, [DateTime? reference]) {
    final r = _jourSeul(reference ?? DateTime.now());
    switch (periode) {
      case _Periode.jour:
        _appliquer(periode, r, r);
      case _Periode.semaine:
        final lundi = r.subtract(Duration(days: r.weekday - 1));
        _appliquer(periode, lundi, lundi.add(const Duration(days: 6)));
      case _Periode.mois:
        _appliquer(periode, DateTime(r.year, r.month),
            DateTime(r.year, r.month + 1, 0));
      case _Periode.personnalisee:
        _choisirPlage();
    }
  }

  Future<void> _choisirPlage() async {
    final maintenant = DateTime.now();
    final plage = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(maintenant.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: _debut, end: _fin),
      helpText: 'Choisir une période',
      saveText: 'Appliquer',
    );
    if (plage == null || !mounted) return;
    _appliquer(_Periode.personnalisee, plage.start, plage.end);
  }

  /// Période précédente (-1) ou suivante (+1), de même durée.
  void _decaler(int sens) {
    switch (_periode) {
      case _Periode.jour:
        _choisir(_periode, _debut.add(Duration(days: sens)));
      case _Periode.semaine:
        _choisir(_periode, _debut.add(Duration(days: 7 * sens)));
      case _Periode.mois:
        _choisir(_periode, DateTime(_debut.year, _debut.month + sens));
      case _Periode.personnalisee:
        final jours = _fin.difference(_debut).inDays + 1;
        _appliquer(
          _periode,
          _debut.add(Duration(days: jours * sens)),
          _fin.add(Duration(days: jours * sens)),
        );
    }
  }

  String get _libellePeriode {
    final aujourdHui = _jourSeul(DateTime.now());
    String date(DateTime d, String motif) =>
        DateFormat(motif, 'fr_FR').format(d);
    String majuscule(String s) =>
        s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    return switch (_periode) {
      _Periode.jour => _debut == aujourdHui
          ? 'Aujourd\'hui — ${date(_debut, 'd MMMM yyyy')}'
          : majuscule(date(_debut, 'EEEE d MMMM yyyy')),
      _Periode.semaine =>
        'Semaine du ${date(_debut, 'd MMM')} au ${date(_fin, 'd MMM yyyy')}',
      _Periode.mois => majuscule(date(_debut, 'MMMM yyyy')),
      _Periode.personnalisee => _debut == _fin
          ? majuscule(date(_debut, 'EEEE d MMMM yyyy'))
          : 'Du ${date(_debut, 'd MMM yyyy')} au ${date(_fin, 'd MMM yyyy')}',
    };
  }

  String get _nomFichier {
    String f(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    return _debut == _fin
        ? 'absences-${f(_debut)}'
        : 'absences-${f(_debut)}-au-${f(_fin)}';
  }

  // ── Filtres ────────────────────────────────────────────

  bool _duType(Presence p) => switch (_type) {
        _Type.toutes => true,
        _Type.journee => p.statut == StatutPresence.absent,
        _Type.matin => p.statut == StatutPresence.absentMatin,
        _Type.apresMidi => p.statut == StatutPresence.absentApresMidi,
      };

  bool _duNom(Presence p) {
    final q = _recherche.trim().toLowerCase();
    return q.isEmpty || nomPreposee(p).toLowerCase().contains(q);
  }

  List<Presence> _lignes(List<Presence> absences) {
    int parNom(Presence a, Presence b) =>
        nomPreposee(a).toLowerCase().compareTo(nomPreposee(b).toLowerCase());
    int sens(int c) => _croissant ? c : -c;
    return absences.where((p) => _duType(p) && _duNom(p)).toList()
      ..sort((a, b) {
        if (_tri == _Tri.preposee) {
          final c = parNom(a, b);
          return c != 0 ? sens(c) : b.date.compareTo(a.date);
        }
        final c = a.date.compareTo(b.date);
        return c != 0 ? sens(c) : parNom(a, b);
      });
  }

  String get _descriptionFiltres => [
        if (_type != _Type.toutes)
          switch (_type) {
            _Type.journee => 'journée complète',
            _Type.matin => 'matin',
            _Type.apresMidi => 'après-midi',
            _Type.toutes => '',
          },
        if (_recherche.trim().isNotEmpty) '« ${_recherche.trim()} »',
      ].join(' · ');

  void _trier(_Tri tri) => setState(() {
        _croissant = _tri == tri ? !_croissant : tri == _Tri.preposee;
        _tri = tri;
        _page = 0;
      });

  // ── Exports ────────────────────────────────────────────

  void _exporterPdf(List<Presence> absences, List<Presence> horaires) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AbsencesPdfPreviewScreen(
          absences: absences,
          horaires: horaires,
          periode: _libellePeriode,
          filtres: _descriptionFiltres,
          nomFichier: '$_nomFichier.pdf',
          generatedBy:
              ref.read(employeeCourantProvider)?.nomComplet ?? 'CleanOps',
        ),
      ),
    );
  }

  void _exporterExcel(List<Presence> absences, List<Presence> horaires) {
    try {
      const GenerateAbsencesExcel()(
        absences: absences,
        horaires: horaires,
        periode: _libellePeriode,
        nomFichier: '$_nomFichier.xlsx',
      );
      showExportSuccess(
          context, 'Le registre Excel des absences a été téléchargé.');
    } catch (error) {
      AppFeedback.showError(context, error);
    }
  }

  void _ouvrirTaches(Presence p) {
    showDialog<void>(
      context: context,
      builder: (ctx) => DialogueApp(
        titre: 'Tâches de ${nomPreposee(p)}',
        largeur: 620,
        libelleAction: 'Terminé',
        onAction: () => Navigator.of(ctx).pop(),
        contenu: _AbsenceCard(presence: p, date: p.date),
      ),
    );
  }

  // ── Construction ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(absencesNotifierProvider);
    final compact = estCompact(context);
    final mode =
        compact ? ModeAffichage.grille : (_mode ?? ModeAffichage.tableau);
    final marge = compact ? 12.0 : 24.0;

    final lignes = _lignes(state.absences);
    final horaires = state.presencesAvecHeures.where(_duNom).toList();
    final nbPages = lignes.isEmpty ? 1 : ((lignes.length - 1) ~/ _parPage) + 1;
    final page = _page.clamp(0, nbPages - 1);
    final visibles = lignes.skip(page * _parPage).take(_parPage).toList();
    final plusieursJours = _debut != _fin;
    final aujourdHui = _jourSeul(DateTime.now());

    FiltreSection filtre(_Type t, IconData icone, String info) => FiltreSection(
          icone: icone,
          infoBulle: info,
          actif: _type == t,
          onTap: () => setState(() {
            _type = t;
            _page = 0;
          }),
        );

    final recherche = ChampRecherche(
      indice: 'Rechercher une préposée',
      onChanged: (v) => setState(() {
        _recherche = v;
        _page = 0;
      }),
    );

    Widget corps;
    if (state.isLoading && state.absences.isEmpty) {
      corps = const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.rouge)),
      );
    } else if (state.error != null && state.absences.isEmpty) {
      corps = _EtatErreur(message: state.error!, onRetry: _charger);
    } else if (state.absences.isEmpty) {
      corps = _EtatVide(
        message: _periode == _Periode.jour && _debut == aujourdHui
            ? 'Toute l\'équipe est présente aujourd\'hui.'
            : 'Aucune absence signalée sur cette période.',
      );
    } else if (lignes.isEmpty) {
      corps = const CarteContenu(
        padding: EdgeInsets.all(AppSizes.xl),
        child: Text(
          'Aucune absence ne correspond aux filtres.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.grisDark),
        ),
      );
    } else {
      corps = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == ModeAffichage.tableau)
            _TableauAbsences(
              lignes: visibles,
              premierNumero: page * _parPage + 1,
              tri: _tri,
              croissant: _croissant,
              onTrier: _trier,
              onOuvrir: _ouvrirTaches,
            )
          else
            _GrilleAbsences(lignes: visibles, onOuvrir: _ouvrirTaches),
          const SizedBox(height: AppSizes.md),
          BarrePagination(
            page: page,
            parPage: _parPage,
            total: lignes.length,
            onPage: (p) => setState(() => _page = p),
            onParPage: (n) => setState(() {
              _parPage = n;
              _page = 0;
            }),
          ),
        ],
      );
    }

    return PageAvecEnTete(
      chargement: state.isLoading,
      enTete: EnTetePage(
        icone: Icons.person_off_rounded,
        titre: 'Absences',
        sousTitre: _libellePeriode,
      ),
      contenu: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _charger,
        child: ListView(
          padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
              .plusBarre(context),
          children: [
            BarreSection(
              titre: 'Absences (${lignes.length})',
              onRetour: () => context.backOrHome(AppRoutes.employerDashboard),
              filtres: [
                filtre(_Type.toutes, Icons.list_alt_rounded,
                    'Toutes les absences'),
                filtre(_Type.journee, Icons.person_off_outlined,
                    'Journée complète'),
                filtre(_Type.matin, Icons.wb_sunny_outlined, 'Matin (AM)'),
                filtre(_Type.apresMidi, Icons.nights_stay_outlined,
                    'Après-midi (PM)'),
              ],
              actions: [
                ActionSection(
                  icone: Icons.print_rounded,
                  infoBulle: 'Imprimer ou exporter en PDF',
                  onPressed: state.isLoading
                      ? null
                      : () => _exporterPdf(lignes, horaires),
                ),
                ActionSection(
                  icone: Icons.download_rounded,
                  infoBulle: 'Télécharger en Excel',
                  onPressed: state.isLoading
                      ? null
                      : () => _exporterExcel(lignes, horaires),
                ),
                ActionSection(
                  icone: Icons.refresh_rounded,
                  infoBulle: 'Actualiser',
                  onPressed: state.isLoading ? null : _charger,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            _SelecteurPeriode(
              periode: _periode,
              libelle: _libellePeriode,
              onPeriode: _choisir,
              onPrecedent: () => _decaler(-1),
              onSuivant: _fin.isBefore(aujourdHui) ? () => _decaler(1) : null,
              onAujourdhui: _periode == _Periode.jour && _debut == aujourdHui
                  ? null
                  : () => _choisir(_Periode.jour),
            ),
            if (state.absences.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              _Recapitulatif(absences: state.absences),
            ],
            const SizedBox(height: AppSizes.md),
            if (compact)
              recherche
            else
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: recherche,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  BasculeAffichage(
                    mode: mode,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                ],
              ),
            const SizedBox(height: AppSizes.md),
            corps,
            if (horaires.isNotEmpty) ...[
              const SizedBox(height: AppSizes.lg),
              _RegistreHeuresSection(
                presences: horaires,
                avecDate: plusieursJours,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sélecteur de période ───────────────────────────────────

class _SelecteurPeriode extends StatelessWidget {
  final _Periode periode;
  final String libelle;
  final ValueChanged<_Periode> onPeriode;
  final VoidCallback onPrecedent;
  final VoidCallback? onSuivant;
  final VoidCallback? onAujourdhui;

  const _SelecteurPeriode({
    required this.periode,
    required this.libelle,
    required this.onPeriode,
    required this.onPrecedent,
    required this.onSuivant,
    required this.onAujourdhui,
  });

  @override
  Widget build(BuildContext context) {
    final compact = estCompact(context);
    Widget choix(_Periode p, String texte, {IconData? icone}) {
      final actif = periode == p;
      return Material(
        color: actif ? AppColors.rouge : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          // « Période… » se rouvre même active, pour changer les dates.
          onTap:
              actif && p != _Periode.personnalisee ? null : () => onPeriode(p),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icone != null) ...[
                  Icon(icone,
                      size: 15,
                      color: actif ? Colors.white : AppColors.grisDark),
                  const SizedBox(width: 5),
                ],
                Text(
                  texte,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: actif ? Colors.white : AppColors.grisDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final choixPeriodes = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          choix(_Periode.jour, 'Jour'),
          choix(_Periode.semaine, 'Semaine'),
          choix(_Periode.mois, 'Mois'),
          choix(_Periode.personnalisee, 'Période',
              icone: Icons.date_range_rounded),
        ],
      ),
    );

    final navigation = Row(
      mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Période précédente',
          onPressed: onPrecedent,
          color: AppColors.rouge,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Flexible(
          fit: compact ? FlexFit.tight : FlexFit.loose,
          child: Text(
            libelle,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.noir,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Période suivante',
          onPressed: onSuivant,
          color: AppColors.rouge,
          disabledColor: AppColors.grisMedium,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        if (onAujourdhui != null)
          TextButton(
            onPressed: onAujourdhui,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.rouge,
              textStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            child: const Text('Aujourd\'hui'),
          ),
      ],
    );

    return CarteContenu(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: compact
          ? Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: choixPeriodes,
                ),
                const SizedBox(height: 4),
                navigation,
              ],
            )
          : Row(
              children: [
                choixPeriodes,
                const Spacer(),
                navigation,
              ],
            ),
    );
  }
}

// ── Récapitulatif ──────────────────────────────────────────

class _Recapitulatif extends StatelessWidget {
  final List<Presence> absences;
  const _Recapitulatif({required this.absences});

  @override
  Widget build(BuildContext context) {
    int nb(StatutPresence s) => absences.where((p) => p.statut == s).length;
    final preposees = absences.map((p) => p.employeeId).toSet().length;
    final jours = absences.map((p) => _jourSeul(p.date)).toSet().length;
    final chiffres = [
      ('Absences', absences.length, Icons.event_busy_rounded, AppColors.rouge),
      (
        'Journée complète',
        nb(StatutPresence.absent),
        Icons.person_off_outlined,
        AppColors.refus
      ),
      (
        'Matin',
        nb(StatutPresence.absentMatin),
        Icons.wb_sunny_outlined,
        AppColors.aVerifier
      ),
      (
        'Après-midi',
        nb(StatutPresence.absentApresMidi),
        Icons.nights_stay_outlined,
        AppColors.absent
      ),
      ('Préposées', preposees, Icons.people_alt_outlined, AppColors.grisDark),
      (
        'Jours touchés',
        jours,
        Icons.calendar_today_rounded,
        AppColors.grisDark
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      final colonnes = c.maxWidth >= 900
          ? 6
          : c.maxWidth >= 520
              ? 3
              : 2;
      final largeur = (c.maxWidth - ecart * (colonnes - 1)) / colonnes;
      return Wrap(
        spacing: ecart,
        runSpacing: ecart,
        children: [
          for (final (libelle, valeur, icone, couleur) in chiffres)
            SizedBox(
              width: largeur,
              child: CarteContenu(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: couleur.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icone, size: 17, color: couleur),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$valeur',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.noir,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            libelle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.grisText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

// ── Style commun d'une absence ─────────────────────────────

(Color, IconData) _styleAbsence(StatutPresence s) => switch (s) {
      StatutPresence.absent => (AppColors.refus, Icons.person_off_outlined),
      StatutPresence.absentMatin => (
          AppColors.aVerifier,
          Icons.wb_sunny_outlined
        ),
      StatutPresence.absentApresMidi => (
          AppColors.absent,
          Icons.nights_stay_outlined
        ),
      StatutPresence.present => (AppColors.fait, Icons.check_circle_outline),
    };

String _dateLigne(DateTime d) {
  final t = DateFormat('EEE d MMM yyyy', 'fr_FR').format(d);
  return t[0].toUpperCase() + t.substring(1);
}

String? _signaleeLe(Presence p) => p.confirmedLe == null
    ? null
    : DateFormat('dd/MM à HH:mm', 'fr_FR').format(p.confirmedLe!.toLocal());

class _BadgeAbsence extends StatelessWidget {
  final StatutPresence statut;
  const _BadgeAbsence(this.statut);

  @override
  Widget build(BuildContext context) {
    final (couleur, icone) = _styleAbsence(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: couleur),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              typeAbsence(statut),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: couleur),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarAbsence extends StatelessWidget {
  final Presence presence;
  final double rayon;
  const _AvatarAbsence(this.presence, {this.rayon = 15});

  @override
  Widget build(BuildContext context) {
    final (couleur, _) = _styleAbsence(presence.statut);
    final prenom = presence.employee?.prenom ?? '';
    return AvatarProfil(
      proprietaire:
          ProprietairePhoto(TypeProprietairePhoto.employe, presence.employeeId),
      initiales: prenom.isNotEmpty ? prenom[0].toUpperCase() : '?',
      rayon: rayon,
      couleurFond: couleur.withValues(alpha: 0.12),
      couleurTexte: couleur,
      tailleTexte: rayon * 0.8,
      poidsTexte: FontWeight.bold,
    );
  }
}

// ── Tableau ────────────────────────────────────────────────

const _styleEnTete = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.grisDark,
);

class _TableauAbsences extends StatelessWidget {
  final List<Presence> lignes;
  final int premierNumero;
  final _Tri tri;
  final bool croissant;
  final ValueChanged<_Tri> onTrier;
  final ValueChanged<Presence> onOuvrir;

  const _TableauAbsences({
    required this.lignes,
    required this.premierNumero,
    required this.tri,
    required this.croissant,
    required this.onTrier,
    required this.onOuvrir,
  });

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF7F8FA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                    width: 40, child: Text('N°', style: _styleEnTete)),
                Expanded(
                  flex: 2,
                  child: _EnTeteTri(
                    libelle: 'Date',
                    actif: tri == _Tri.date,
                    croissant: croissant,
                    onTap: () => onTrier(_Tri.date),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _EnTeteTri(
                    libelle: 'Préposée',
                    actif: tri == _Tri.preposee,
                    croissant: croissant,
                    onTap: () => onTrier(_Tri.preposee),
                  ),
                ),
                const Expanded(
                    flex: 2, child: Text('Absence', style: _styleEnTete)),
                const Expanded(
                    flex: 2, child: Text('Signalée le', style: _styleEnTete)),
                const SizedBox(width: 48),
              ],
            ),
          ),
          for (final (i, p) in lignes.indexed) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.grisMedium),
            _LigneAbsence(
              presence: p,
              numero: premierNumero + i,
              onOuvrir: () => onOuvrir(p),
            ),
          ],
        ],
      ),
    );
  }
}

class _EnTeteTri extends StatelessWidget {
  final String libelle;
  final bool actif;
  final bool croissant;
  final VoidCallback onTap;

  const _EnTeteTri({
    required this.libelle,
    required this.actif,
    required this.croissant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? AppColors.rouge : AppColors.grisDark;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(libelle, style: _styleEnTete.copyWith(color: couleur)),
              const SizedBox(width: 4),
              Icon(
                !actif
                    ? Icons.swap_vert_rounded
                    : croissant
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                size: 14,
                color: couleur,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LigneAbsence extends StatelessWidget {
  final Presence presence;
  final int numero;
  final VoidCallback onOuvrir;

  const _LigneAbsence({
    required this.presence,
    required this.numero,
    required this.onOuvrir,
  });

  @override
  Widget build(BuildContext context) {
    final p = presence;
    const style = TextStyle(fontSize: 13, color: AppColors.noir);
    final signalee = _signaleeLe(p);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onOuvrir,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 40, child: Text('$numero', style: style)),
              Expanded(flex: 2, child: Text(_dateLigne(p.date), style: style)),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    _AvatarAbsence(p),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nomPreposee(p),
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BadgeAbsence(p.statut),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  signalee ?? '—',
                  style: style.copyWith(
                      color: signalee == null
                          ? AppColors.grisText
                          : AppColors.grisDark),
                ),
              ),
              SizedBox(
                width: 48,
                child: IconButton(
                  tooltip: 'Gérer ses tâches',
                  onPressed: onOuvrir,
                  icon: const Icon(Icons.assignment_ind_outlined,
                      color: AppColors.rouge),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grille ─────────────────────────────────────────────────

class _GrilleAbsences extends StatelessWidget {
  final List<Presence> lignes;
  final ValueChanged<Presence> onOuvrir;

  const _GrilleAbsences({required this.lignes, required this.onOuvrir});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      final colonnes = math.max(1, (c.maxWidth + ecart) ~/ (320 + ecart));
      final largeur = (c.maxWidth - ecart * (colonnes - 1)) / colonnes;
      return Wrap(
        spacing: ecart,
        runSpacing: ecart,
        children: [
          for (final p in lignes)
            SizedBox(
              width: largeur,
              child: _CarteAbsence(presence: p, onOuvrir: () => onOuvrir(p)),
            ),
        ],
      );
    });
  }
}

class _CarteAbsence extends StatelessWidget {
  final Presence presence;
  final VoidCallback onOuvrir;

  const _CarteAbsence({required this.presence, required this.onOuvrir});

  @override
  Widget build(BuildContext context) {
    final p = presence;
    final signalee = _signaleeLe(p);
    return CarteContenu(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOuvrir,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _AvatarAbsence(p, rayon: 20),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nomPreposee(p),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.noir,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _dateLigne(p.date),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.grisText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                Row(
                  children: [
                    Flexible(child: _BadgeAbsence(p.statut)),
                    const Spacer(),
                    if (signalee != null)
                      Text(
                        'Signalée le $signalee',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.grisText),
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onOuvrir,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.rouge,
                      textStyle: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.assignment_ind_outlined, size: 17),
                    label: const Text('Gérer ses tâches'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Registre des horaires précisés (informatif) ────────────

class _RegistreHeuresSection extends StatelessWidget {
  final List<Presence> presences;
  final bool avecDate;
  const _RegistreHeuresSection({
    required this.presences,
    required this.avecDate,
  });

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: !avecDate,
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          childrenPadding:
              const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, 12),
          iconColor: AppColors.rouge,
          leading: const Icon(Icons.access_time_rounded,
              size: 20, color: AppColors.absent),
          title: Text(
            'Horaires précisés (${presences.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.noir,
            ),
          ),
          subtitle: const Text(
            'À titre informatif — n\'affecte pas les tâches.',
            style: TextStyle(fontSize: 11.5, color: AppColors.grisText),
          ),
          children: [
            for (int i = 0; i < presences.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              _HeureRegistreRow(presence: presences[i], avecDate: avecDate),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeureRegistreRow extends StatelessWidget {
  final Presence presence;
  final bool avecDate;
  const _HeureRegistreRow({required this.presence, required this.avecDate});

  @override
  Widget build(BuildContext context) {
    final prenom = presence.employee?.prenom ?? '';
    final initiale = prenom.isNotEmpty ? prenom[0].toUpperCase() : '?';

    return Row(
      children: [
        AvatarProfil(
          proprietaire: ProprietairePhoto(
              TypeProprietairePhoto.employe, presence.employeeId),
          initiales: initiale,
          rayon: 16,
          couleurFond: AppColors.absent.withValues(alpha: 0.12),
          couleurTexte: AppColors.absent,
          tailleTexte: 12,
          poidsTexte: FontWeight.bold,
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nomPreposee(presence),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.noir),
              ),
              if (avecDate)
                Text(
                  _dateLigne(presence.date),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.grisText),
                ),
            ],
          ),
        ),
        Text(
          '${presence.heureDebut} → ${presence.heureFin}',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.absent),
        ),
      ],
    );
  }
}

// ── Carte absence — affiche l'employée + ses tâches ────────

class _AbsenceCard extends ConsumerStatefulWidget {
  final Presence presence;
  final DateTime date;
  const _AbsenceCard({required this.presence, required this.date});

  @override
  ConsumerState<_AbsenceCard> createState() => _AbsenceCardState();
}

class _AbsenceCardState extends ConsumerState<_AbsenceCard> {
  List<Map<String, dynamic>> _taches = [];
  bool _loadingTaches = true;

  // État par tâche : tacheId → 'A' | 'B' | 'C' | 'D' | null
  final Map<String, String?> _tacheDone = {};
  // tacheId → prénom préposée cible (pour transfert)
  final Map<String, String?> _tacheTransfertPrenom = {};
  final Map<String, bool> _tacheLoading = {};

  Presence get p => widget.presence;
  DateTime get d => widget.date;

  (Color, String, IconData) get _statutStyle => switch (p.statut) {
        StatutPresence.absent => (
            AppColors.rouge,
            'Absente — toute la journée',
            Icons.person_off_outlined
          ),
        StatutPresence.absentMatin => (
            AppColors.aVerifier,
            'Absente — matin (AM)',
            Icons.wb_twilight_outlined
          ),
        StatutPresence.absentApresMidi => (
            AppColors.aVerifier,
            'Absente — après-midi (PM)',
            Icons.nights_stay_outlined
          ),
        StatutPresence.present => (
            AppColors.fait,
            'Présente',
            Icons.check_circle_outline
          ),
      };

  @override
  void initState() {
    super.initState();
    _chargerTaches();
  }

  Future<void> _chargerTaches() async {
    final toutes = await _getTachesAbsent(p.employeeId, d);
    final filtrees = _filtrerParPeriode(toutes, p.statut);
    if (mounted) {
      setState(() {
        _taches = filtrees;
        _loadingTaches = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, statusLabel, statusIcon) = _statutStyle;
    final prenom = p.employee?.prenom ?? '';
    final nom = p.employee?.nom ?? '';
    final initiale = prenom.isNotEmpty ? prenom[0].toUpperCase() : '?';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        side: BorderSide(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête employée ─────────────────────────
            Row(
              children: [
                AvatarProfil(
                  proprietaire: ProprietairePhoto(
                      TypeProprietairePhoto.employe, p.employeeId),
                  initiales: initiale,
                  rayon: 22,
                  couleurFond: color.withValues(alpha: 0.12),
                  couleurTexte: color,
                  tailleTexte: 16,
                  poidsTexte: FontWeight.bold,
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$prenom $nom'.trim().isEmpty
                            ? 'Préposée inconnue'
                            : '$prenom $nom',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.noir),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(statusIcon, size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(statusLabel,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: color,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (p.confirmedLe != null)
                  Text(
                    _heure(p.confirmedLe!),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.grisText),
                  ),
              ],
            ),

            // ── Liste des tâches concernées ───────────────
            const SizedBox(height: AppSizes.md),
            const Divider(height: 1),
            const SizedBox(height: AppSizes.sm),

            if (_loadingTaches)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.md),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.rouge, strokeWidth: 2)),
              )
            else if (_taches.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 15, color: AppColors.fait),
                    SizedBox(width: 6),
                    Text(
                      'Aucune tâche pour cette période.',
                      style: TextStyle(fontSize: 13, color: AppColors.grisDark),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_taches.length} tâche${_taches.length > 1 ? 's' : ''} concernée${_taches.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grisText,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  ...List.generate(_taches.length, (i) {
                    final tache = _taches[i];
                    final tacheId = tache['id'] as String;
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: i < _taches.length - 1 ? AppSizes.sm : 0),
                      child: _TacheItem(
                        tache: tache,
                        presence: p,
                        date: d,
                        done: _tacheDone[tacheId],
                        transfertPrenom: _tacheTransfertPrenom[tacheId],
                        isLoading: _tacheLoading[tacheId] ?? false,
                        onDone: (action, {String? prenom}) {
                          setState(() {
                            _tacheDone[tacheId] = action;
                            if (prenom != null) {
                              _tacheTransfertPrenom[tacheId] = prenom;
                            }
                          });
                        },
                        onLoading: (v) =>
                            setState(() => _tacheLoading[tacheId] = v),
                      ),
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _heure(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
}

// ── Carte d'une tâche individuelle ─────────────────────────

class _TacheItem extends ConsumerWidget {
  final Map<String, dynamic> tache;
  final Presence presence;
  final DateTime date;
  final String? done;
  final String? transfertPrenom;
  final bool isLoading;
  final void Function(String action, {String? prenom}) onDone;
  final void Function(bool) onLoading;

  const _TacheItem({
    required this.tache,
    required this.presence,
    required this.date,
    required this.done,
    required this.transfertPrenom,
    required this.isLoading,
    required this.onDone,
    required this.onLoading,
  });

  String get _numAppart =>
      (tache['appartements'] as Map?)?['numero'] as String? ??
      (tache['appartement_id'] as String? ?? '?');

  String get _periode => tache['periode'] as String? ?? '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne infos tâche
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.rouge.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.home_work_outlined,
                      size: 14, color: AppColors.rouge),
                ),
                const SizedBox(width: 8),
                Text(
                  'Apt $_numAppart',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.noir),
                ),
                const SizedBox(width: 8),
                _PeriodeBadge(periode: _periode),
                const Spacer(),
                _StatutTacheBadge(statut: tache['statut'] as String? ?? ''),
              ],
            ),

            const SizedBox(height: AppSizes.sm),

            // Actions ou état "fait"
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.rouge),
                  ),
                ),
              )
            else if (done != null)
              _DoneChip(action: done!, prenom: transfertPrenom)
            else
              _ActionRow(
                tache: tache,
                presence: presence,
                date: date,
                onDone: onDone,
                onLoading: onLoading,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Boutons d'action (inline) ──────────────────────────────

class _ActionRow extends ConsumerWidget {
  final Map<String, dynamic> tache;
  final Presence presence;
  final DateTime date;
  final void Function(String action, {String? prenom}) onDone;
  final void Function(bool) onLoading;

  const _ActionRow({
    required this.tache,
    required this.presence,
    required this.date,
    required this.onDone,
    required this.onLoading,
  });

  String get _tacheId => tache['id'] as String;
  String get _appartementId => tache['appartement_id'] as String;
  String get _numAppart =>
      (tache['appartements'] as Map?)?['numero'] as String? ?? _appartementId;
  String get _periode => tache['periode'] as String? ?? '';

  void _transferer(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _TransfertTacheDialog(
        tache: tache,
        presence: presence,
        date: date,
        onDone: ({String? prenom}) => onDone('A', prenom: prenom),
      ),
    );
  }

  Future<void> _liberer(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(employeeCourantProvider);
    if (currentUser == null) return;

    final confirme = await _confirmerDialog(
      context,
      titre: 'Libérer à l\'équipe',
      message:
          'La tâche Apt $_numAppart ($_periode) sera visible par toute l\'équipe.',
      couleur: AppColors.aVerifier,
    );
    if (!confirme || !context.mounted) return;

    onLoading(true);
    final toutesPreposees = ref
        .read(employesNotifierProvider)
        .employes
        .where((e) => e.isActif && e.isPreposee && e.id != presence.employeeId)
        .map((e) => e.id)
        .toList();

    try {
      await SupabaseService.table(SupabaseService.tachesDisponibles).insert({
        'tache_jour_id': _tacheId,
        'motif': 'Absence',
        'libere_par': currentUser.id,
        'date_liberation': DateTime.now().toIso8601String(),
        'statut': 'Disponible',
        'visibilite': 'TouteEquipe',
        'date_expiration': _vendrediStr(date),
      });

      await _insererHistorique(
        type: 'LiberationTaches',
        entityId: _tacheId,
        employeurId: currentUser.id,
        note:
            'Libération suite à absence de ${presence.employee?.prenom ?? 'la préposée'}',
        donneeAvant: {
          'employee_id': presence.employeeId,
          'statut': tache['statut']
        },
        donneeApres: {'statut': 'Disponible', 'visibilite': 'TouteEquipe'},
      );

      await _notifierEmployes(
        employeeIds: toutesPreposees,
        type: 'TacheDisponible',
        message:
            'Tâche disponible — Apt $_numAppart ${_nomJour(date)} $_periode',
        entityId: _tacheId,
      );

      onLoading(false);
      onDone('B');
    } catch (e) {
      onLoading(false);
      if (context.mounted) {
        NotificationApp.depuisErreur(context, e);
      }
    }
  }

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(employeeCourantProvider);
    if (currentUser == null) return;

    final note = await _noteDialog(
      context,
      titre: 'Annuler le ménage',
      message:
          'La tâche Apt $_numAppart ($_periode) sera annulée. Le résident sera notifié.',
      couleur: AppColors.rouge,
    );
    if (note == null || !context.mounted) return;

    onLoading(true);
    try {
      final maintenant = DateTime.now().toIso8601String();
      await SupabaseService.table(SupabaseService.tachesJour).update({
        'statut': 'Annulé',
        'confirme_par': currentUser.id,
        'confirme_le': maintenant,
      }).eq('id', _tacheId);

      await _insererHistorique(
        type: 'Annulation',
        entityId: _tacheId,
        employeurId: currentUser.id,
        note: note,
        donneeAvant: {
          'employee_id': presence.employeeId,
          'statut': tache['statut']
        },
        donneeApres: {'statut': 'Annulé', 'confirme_par': currentUser.id},
      );

      await _notifierResidents(
        appartementId: _appartementId,
        tacheJourId: _tacheId,
        type: 'MenageEnAttente',
        message: 'Votre ménage est momentanément en attente. '
            'Vous serez informé(e) dès qu\'une date est confirmée.',
      );

      await _notifierEmployes(
        employeeIds: [presence.employeeId],
        type: 'Annulation',
        message:
            'Le ménage Apt $_numAppart — ${_nomJour(date)} $_periode a été annulé.',
        entityId: _tacheId,
      );

      onLoading(false);
      onDone('C');
    } catch (e) {
      onLoading(false);
      if (context.mounted) {
        NotificationApp.depuisErreur(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.sm,
      children: [
        _ActionChip(
          icon: Icons.swap_horiz_rounded,
          label: 'Transférer',
          color: AppColors.absent,
          onTap: () => _transferer(context, ref),
        ),
        _ActionChip(
          icon: Icons.lock_open_rounded,
          label: 'Libérer',
          color: AppColors.aVerifier,
          onTap: () => _liberer(context, ref),
        ),
        _ActionChip(
          icon: Icons.cancel_outlined,
          label: 'Annuler',
          color: AppColors.rouge,
          onTap: () => _annuler(context, ref),
        ),
        _ActionChip(
          icon: Icons.hourglass_empty_rounded,
          label: 'Laisser',
          color: AppColors.grisText,
          onTap: () => onDone('D'),
        ),
      ],
    );
  }
}

// ── Dialog transfert d'une tâche ──────────────────────────

class _TransfertTacheDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> tache;
  final Presence presence;
  final DateTime date;
  final void Function({String? prenom}) onDone;

  const _TransfertTacheDialog({
    required this.tache,
    required this.presence,
    required this.date,
    required this.onDone,
  });

  @override
  ConsumerState<_TransfertTacheDialog> createState() =>
      _TransfertTacheDialogState();
}

class _TransfertTacheDialogState extends ConsumerState<_TransfertTacheDialog> {
  String? _selectedId;
  String? _selectedPrenom;
  bool _loading = false;

  String get _tacheId => widget.tache['id'] as String;
  String get _appartementId => widget.tache['appartement_id'] as String;
  String get _numAppart =>
      (widget.tache['appartements'] as Map?)?['numero'] as String? ??
      _appartementId;
  String get _periode => widget.tache['periode'] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    final employes = ref.watch(employesNotifierProvider);
    final currentUser = ref.read(employeeCourantProvider);

    final cibles = employes.employes
        .where((e) =>
            e.id != widget.presence.employeeId &&
            e.id != currentUser?.id &&
            e.isActif &&
            e.isPreposee)
        .toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
      title: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, color: AppColors.absent),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'Transférer — Apt $_numAppart ($_periode)',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Réassigner cette tâche à une préposée disponible. '
              'Le résident sera notifié.',
              style: TextStyle(fontSize: 13, color: AppColors.grisDark),
            ),
            const SizedBox(height: AppSizes.md),
            if (cibles.isEmpty)
              const Text('Aucune préposée disponible.',
                  style: TextStyle(color: AppColors.grisText))
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedId,
                decoration: const InputDecoration(
                  labelText: 'Préposée destinataire',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: cibles
                    .map((e) => DropdownMenuItem(
                          value: e.id,
                          child: Text('${e.prenom} ${e.nom}'),
                        ))
                    .toList(),
                onChanged: (v) {
                  final emp = cibles.where((e) => e.id == v).firstOrNull;
                  setState(() {
                    _selectedId = v;
                    _selectedPrenom = emp?.prenom;
                  });
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _selectedId == null || _loading
              ? null
              : () => _confirmer(context),
          style: FilledButton.styleFrom(backgroundColor: AppColors.absent),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Confirmer'),
        ),
      ],
    );
  }

  Future<void> _confirmer(BuildContext context) async {
    if (_selectedId == null) return;
    final currentUser = ref.read(employeeCourantProvider);
    if (currentUser == null) return;

    setState(() => _loading = true);

    try {
      // 1. Réassigner la tâche
      await SupabaseService.table(SupabaseService.tachesJour).update({
        'employee_id': _selectedId,
        'is_transfert_temp': true,
      }).eq('id', _tacheId);

      // 2. Enregistrer le transfert
      await SupabaseService.table(SupabaseService.transferts).insert({
        'tache_jour_id': _tacheId,
        'employee_source_id': widget.presence.employeeId,
        'employee_dest_id': _selectedId,
        'type': 'Temporaire',
        'date_debut': _dateStr(widget.date),
        'date_fin': _dateStr(widget.date),
        'effectué_par': currentUser.id,
        'note': 'Transfert suite à absence',
      });

      // 3. Historique
      await _insererHistorique(
        type: 'Transfert',
        entityId: _tacheId,
        employeurId: currentUser.id,
        note:
            'Transfert suite à absence de ${widget.presence.employee?.prenom ?? 'la préposée'}',
        donneeAvant: {
          'employee_id': widget.presence.employeeId,
          'statut': widget.tache['statut'],
        },
        donneeApres: {'employee_id': _selectedId, 'is_transfert_temp': true},
        canUndo: true,
      );

      // 4. Notifier la préposée cible
      await _notifierEmployes(
        employeeIds: [_selectedId!],
        type: 'Transfert',
        message:
            'Apt $_numAppart vous a été transféré — ${_nomJour(widget.date)} $_periode',
        entityId: _tacheId,
      );

      // 5. Notifier le résident
      await _notifierResidents(
        appartementId: _appartementId,
        tacheJourId: _tacheId,
        type: 'Remplacement',
        message:
            'Votre ménage est confirmé — Préposée : ${_selectedPrenom ?? 'une préposée'}',
      );

      if (!context.mounted) return;
      Navigator.pop(context);
      widget.onDone(prenom: _selectedPrenom);
    } catch (e) {
      setState(() => _loading = false);
      if (context.mounted) {
        NotificationApp.depuisErreur(context, e);
      }
    }
  }
}

// ── Helpers dialogs ────────────────────────────────────────

Future<bool> _confirmerDialog(
  BuildContext context, {
  required String titre,
  required String message,
  required Color couleur,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
      title: Text(titre),
      content: Text(message,
          style: const TextStyle(fontSize: 13, color: AppColors.grisDark)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: couleur),
          child: const Text('Confirmer'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> _noteDialog(
  BuildContext context, {
  required String titre,
  required String message,
  required Color couleur,
}) async {
  final controller = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
          title: Text(titre),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.grisDark)),
                const SizedBox(height: AppSizes.md),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Note *',
                    border: OutlineInputBorder(),
                    hintText: 'Raison de l\'annulation...',
                  ),
                  onChanged: (_) => setS(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: couleur),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}

// ── Sub-widgets ────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _PeriodeBadge extends StatelessWidget {
  final String periode;
  const _PeriodeBadge({required this.periode});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (periode) {
      'AM' => (AppColors.aVerifier, 'Matin'),
      'PM' => (AppColors.absent, 'Après-midi'),
      _ => (AppColors.grisDark, periode),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _StatutTacheBadge extends StatelessWidget {
  final String statut;
  const _StatutTacheBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final color = switch (statut) {
      'Fait' => AppColors.fait,
      'Annulé' => AppColors.grisDark,
      _ => AppColors.nonCommence,
    };
    return Text(statut,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500));
  }
}

class _DoneChip extends StatelessWidget {
  final String action;
  final String? prenom;
  const _DoneChip({required this.action, this.prenom});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String label) = switch (action) {
      'A' => (
          AppColors.absent,
          Icons.swap_horiz_rounded,
          prenom != null ? 'Transférée à $prenom' : 'Transférée',
        ),
      'B' => (
          AppColors.aVerifier,
          Icons.lock_open_rounded,
          'Libérée à l\'équipe'
        ),
      'C' => (AppColors.rouge, Icons.cancel_outlined, 'Ménage annulé'),
      _ => (
          AppColors.grisText,
          Icons.hourglass_empty_rounded,
          'Laissée en attente'
        ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_rounded, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

// ── États vides / erreur ───────────────────────────────────

class _EtatVide extends StatelessWidget {
  final String message;
  const _EtatVide({required this.message});

  @override
  Widget build(BuildContext context) => CarteContenu(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.lg),
              decoration: BoxDecoration(
                  color: AppColors.fait.withValues(alpha: 0.08),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline,
                  size: 44, color: AppColors.fait),
            ),
            const SizedBox(height: AppSizes.md),
            const Text('Aucune absence signalée',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.noir)),
            const SizedBox(height: AppSizes.xs),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.grisText, fontSize: 13.5)),
          ],
        ),
      );
}

class _EtatErreur extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _EtatErreur({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => CarteContenu(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 44, color: AppColors.rouge),
            const SizedBox(height: AppSizes.md),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.grisDark, fontSize: 14)),
            const SizedBox(height: AppSizes.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
            ),
          ],
        ),
      );
}
