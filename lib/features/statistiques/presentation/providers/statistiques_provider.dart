import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/statistiques_datasource.dart';
import '../../data/repositories/statistiques_repository_impl.dart';
import '../../domain/entities/stat_semaine.dart';
import '../../domain/entities/stat_preposee.dart';
import '../../domain/entities/stat_appartement.dart';
import '../../domain/repositories/statistiques_repository.dart';

// ── Infrastructure ────────────────────────────────────────

final statistiquesDatasourceProvider = Provider<StatistiquesDatasource>(
  (_) => StatistiquesDatasourceImpl(),
);

final statistiquesRepositoryProvider = Provider<StatistiquesRepository>((ref) {
  return StatistiquesRepositoryImpl(ref.watch(statistiquesDatasourceProvider));
});

// ── Type de période ───────────────────────────────────────

enum PeriodeType {
  semaineCourante,
  semainePrecedente,
  moisCourant,
  personnalisee,
}

extension PeriodeTypeLabel on PeriodeType {
  String get label => switch (this) {
        PeriodeType.semaineCourante => 'Cette semaine',
        PeriodeType.semainePrecedente => 'Semaine précédente',
        PeriodeType.moisCourant => 'Ce mois',
        PeriodeType.personnalisee => 'Période personnalisée…',
      };
}

// ── Helpers de date ───────────────────────────────────────

DateTime _lundiCourant() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
}

DateTime _vendrediCourant() => _lundiCourant().add(const Duration(days: 4));

// ── État ──────────────────────────────────────────────────

class StatistiquesState {
  final List<StatSemaine> statSemaine;
  final List<StatPreposee> statPreposees;
  final List<StatAppartement> topAppartements;
  final bool isLoading;
  final String? error;
  final int selectedTab;
  final PeriodeType periodeSelectionnee;
  final DateTime dateDebut;
  final DateTime dateFin;

  StatistiquesState({
    this.statSemaine = const [],
    this.statPreposees = const [],
    this.topAppartements = const [],
    this.isLoading = false,
    this.error,
    this.selectedTab = 0,
    this.periodeSelectionnee = PeriodeType.semaineCourante,
    DateTime? dateDebut,
    DateTime? dateFin,
  })  : dateDebut = dateDebut ?? _lundiCourant(),
        dateFin = dateFin ?? _vendrediCourant();

  StatistiquesState copyWith({
    List<StatSemaine>? statSemaine,
    List<StatPreposee>? statPreposees,
    List<StatAppartement>? topAppartements,
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? selectedTab,
    PeriodeType? periodeSelectionnee,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) {
    return StatistiquesState(
      statSemaine: statSemaine ?? this.statSemaine,
      statPreposees: statPreposees ?? this.statPreposees,
      topAppartements: topAppartements ?? this.topAppartements,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      selectedTab: selectedTab ?? this.selectedTab,
      periodeSelectionnee: periodeSelectionnee ?? this.periodeSelectionnee,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────

class StatistiquesNotifier extends StateNotifier<StatistiquesState> {
  final StatistiquesRepository _repo;

  StatistiquesNotifier(this._repo) : super(StatistiquesState());

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future.wait([
      _chargerSemaine(),
      _chargerPreposees(),
      _chargerAppartements(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadStatSemaine() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _chargerSemaine();
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadStatPreposees() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _chargerPreposees();
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadTopAppartements() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _chargerAppartements();
    state = state.copyWith(isLoading: false);
  }

  void selectTab(int index) => state = state.copyWith(selectedTab: index);

  // ── Filtre par période ────────────────────────────────────

  void selectionnerPeriode(PeriodeType type) {
    final now = DateTime.now();
    final lundi = _lundiCourant();

    final DateTime debut;
    final DateTime fin;

    switch (type) {
      case PeriodeType.semaineCourante:
        debut = lundi;
        fin = _vendrediCourant();
      case PeriodeType.semainePrecedente:
        debut = lundi.subtract(const Duration(days: 7));
        fin = debut.add(const Duration(days: 4));
      case PeriodeType.moisCourant:
        debut = DateTime(now.year, now.month, 1);
        fin = DateTime(now.year, now.month + 1, 0);
      case PeriodeType.personnalisee:
        // Le widget gère les date pickers — on ne change rien ici
        state = state.copyWith(periodeSelectionnee: type);
        return;
    }

    state = state.copyWith(
      periodeSelectionnee: type,
      dateDebut: debut,
      dateFin: fin,
    );
    loadStatPreposees();
  }

  void selectionnerPeriodePersonnalisee(DateTime debut, DateTime fin) {
    state = state.copyWith(
      periodeSelectionnee: PeriodeType.personnalisee,
      dateDebut: debut,
      dateFin: fin,
    );
    loadStatPreposees();
  }

  // ── Interne ───────────────────────────────────────────────

  Future<void> _chargerSemaine() async {
    final r = await _repo.getStatSemaine();
    r.fold(
      (f) => state = state.copyWith(error: f.message),
      (data) => state = state.copyWith(statSemaine: data),
    );
  }

  Future<void> _chargerPreposees() async {
    final r = await _repo.getStatParPreposee(
      dateDebut: state.dateDebut,
      dateFin: state.dateFin,
    );
    r.fold(
      (f) => state = state.copyWith(error: f.message),
      (data) => state = state.copyWith(statPreposees: data),
    );
  }

  Future<void> _chargerAppartements() async {
    final r = await _repo.getTopAppartementsProblematiques();
    r.fold(
      (f) => state = state.copyWith(error: f.message),
      (data) => state = state.copyWith(topAppartements: data),
    );
  }
}

// ── Provider ──────────────────────────────────────────────

final statistiquesNotifierProvider =
    StateNotifierProvider<StatistiquesNotifier, StatistiquesState>((ref) {
  return StatistiquesNotifier(ref.watch(statistiquesRepositoryProvider));
});
