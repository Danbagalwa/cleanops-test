import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/statistiques_datasource.dart';
import '../../data/repositories/statistiques_repository_impl.dart';
import '../../domain/entities/statistiques_menages.dart';
import '../../domain/repositories/statistiques_repository.dart';

// ── Infrastructure ────────────────────────────────────────

final statistiquesDatasourceProvider = Provider<StatistiquesDatasource>(
  (_) => StatistiquesDatasourceImpl(),
);

final statistiquesRepositoryProvider = Provider<StatistiquesRepository>((ref) {
  return StatistiquesRepositoryImpl(ref.watch(statistiquesDatasourceProvider));
});

// ── Périodes rapides ──────────────────────────────────────

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

enum PeriodeRapide {
  aujourdhui,
  semaineCourante,
  semainePrecedente,
  moisCourant,
  moisPrecedent,
  trenteDerniersJours;

  String get libelle => switch (this) {
        PeriodeRapide.aujourdhui => 'Aujourd’hui',
        PeriodeRapide.semaineCourante => 'Cette semaine',
        PeriodeRapide.semainePrecedente => 'Semaine précédente',
        PeriodeRapide.moisCourant => 'Ce mois-ci',
        PeriodeRapide.moisPrecedent => 'Mois précédent',
        PeriodeRapide.trenteDerniersJours => '30 derniers jours',
      };

  ({DateTime debut, DateTime fin}) bornes([DateTime? maintenant]) {
    final auj = _jour(maintenant ?? DateTime.now());
    final lundi = auj.subtract(Duration(days: auj.weekday - 1));
    return switch (this) {
      PeriodeRapide.aujourdhui => (debut: auj, fin: auj),
      PeriodeRapide.semaineCourante => (
          debut: lundi,
          fin: lundi.add(const Duration(days: 6))
        ),
      PeriodeRapide.semainePrecedente => (
          debut: lundi.subtract(const Duration(days: 7)),
          fin: lundi.subtract(const Duration(days: 1))
        ),
      PeriodeRapide.moisCourant => (
          debut: DateTime(auj.year, auj.month, 1),
          fin: DateTime(auj.year, auj.month + 1, 0)
        ),
      PeriodeRapide.moisPrecedent => (
          debut: DateTime(auj.year, auj.month - 1, 1),
          fin: DateTime(auj.year, auj.month, 0)
        ),
      PeriodeRapide.trenteDerniersJours => (
          debut: auj.subtract(const Duration(days: 29)),
          fin: auj
        ),
    };
  }
}

// ── État ──────────────────────────────────────────────────

class StatistiquesState {
  /// Période appliquée (celle des chiffres affichés).
  final DateTime dateDebut;
  final DateTime dateFin;

  /// Préposée filtrée (`null` : toutes).
  final String? employeId;

  final StatistiquesMenages? donnees;
  final bool isLoading;
  final String? error;

  const StatistiquesState({
    required this.dateDebut,
    required this.dateFin,
    this.employeId,
    this.donnees,
    this.isLoading = false,
    this.error,
  });

  /// Du 1er du mois à aujourd'hui.
  factory StatistiquesState.initial() {
    final auj = _jour(DateTime.now());
    return StatistiquesState(
      dateDebut: DateTime(auj.year, auj.month, 1),
      dateFin: auj,
    );
  }

  /// Chiffres de la préposée choisie (ou de toutes).
  StatistiquesMenages? get vue => donnees?.pour(employeId);

  StatistiquesState copyWith({
    DateTime? dateDebut,
    DateTime? dateFin,
    String? employeId,
    bool toutesPreposees = false,
    StatistiquesMenages? donnees,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      StatistiquesState(
        dateDebut: dateDebut ?? this.dateDebut,
        dateFin: dateFin ?? this.dateFin,
        employeId: toutesPreposees ? null : employeId ?? this.employeId,
        donnees: donnees ?? this.donnees,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

// ── Notifier ──────────────────────────────────────────────

class StatistiquesNotifier extends StateNotifier<StatistiquesState> {
  final StatistiquesRepository _repo;

  StatistiquesNotifier(this._repo) : super(StatistiquesState.initial());

  /// Recharge la période appliquée.
  Future<void> charger() =>
      rechercher(dateDebut: state.dateDebut, dateFin: state.dateFin);

  /// Applique une période (et une préposée) puis charge ses chiffres.
  Future<void> rechercher({
    required DateTime dateDebut,
    required DateTime dateFin,
    String? employeId,
    bool garderPreposee = true,
  }) async {
    state = state.copyWith(
      dateDebut: _jour(dateDebut),
      dateFin: _jour(dateFin),
      employeId: employeId,
      toutesPreposees: !garderPreposee && employeId == null,
      isLoading: true,
      clearError: true,
    );
    final r = await _repo.getStatistiques(
      dateDebut: state.dateDebut,
      dateFin: state.dateFin,
    );
    if (!mounted) return;
    r.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (d) => state = state.copyWith(isLoading: false, donnees: d),
    );
  }
}

// ── Provider ──────────────────────────────────────────────

/// Ménages de la semaine en cours (lundi → dimanche), pour le graphique du
/// tableau de bord responsable.
final statistiquesSemaineProvider =
    FutureProvider.autoDispose<StatistiquesMenages>((ref) async {
  final b = PeriodeRapide.semaineCourante.bornes();
  final r = await ref
      .watch(statistiquesRepositoryProvider)
      .getStatistiques(dateDebut: b.debut, dateFin: b.fin);
  return r.fold((f) => throw Exception(f.message), (d) => d);
});

final statistiquesNotifierProvider =
    StateNotifierProvider.autoDispose<StatistiquesNotifier, StatistiquesState>(
        (ref) {
  return StatistiquesNotifier(ref.watch(statistiquesRepositoryProvider))
    ..charger();
});
