import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/tache_jour_datasource.dart';
import '../../data/repositories/tache_jour_repository_impl.dart';
import '../../domain/entities/tache_jour.dart';
import '../../domain/repositories/tache_jour_repository.dart';
import '../../domain/usecases/get_taches_du_jour.dart';
import '../../domain/usecases/update_statut_tache.dart';

// ── Infrastructure ────────────────────────────────────────
final tacheJourDatasourceProvider = Provider<TacheJourDatasource>(
  (_) => TacheJourDatasourceImpl(),
);

final tacheJourRepositoryProvider = Provider<TacheJourRepository>((ref) {
  return TacheJourRepositoryImpl(ref.watch(tacheJourDatasourceProvider));
});

final _getTachesProvider = Provider(
  (ref) => GetTachesDuJour(ref.watch(tacheJourRepositoryProvider)),
);

final _updateStatutProvider = Provider(
  (ref) => UpdateStatutTache(ref.watch(tacheJourRepositoryProvider)),
);

// ── État ──────────────────────────────────────────────────
class TacheJourState {
  final List<TacheJour> taches;
  final bool isLoading;
  final String? error;
  final Set<String> updatingIds;

  const TacheJourState({
    this.taches = const [],
    this.isLoading = false,
    this.error,
    this.updatingIds = const {},
  });

  List<TacheJour> get amTaches =>
      taches.where((t) => t.periode == PeriodeType.am).toList()
        ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));

  List<TacheJour> get pmTaches =>
      taches.where((t) => t.periode == PeriodeType.pm).toList()
        ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));

  int get totalMinutes =>
      taches.fold(0, (s, t) => s + t.minutesEstimees);

  int get tachesConfirmees =>
      taches.where((t) => t.estConfirmee).length;

  TacheJourState copyWith({
    List<TacheJour>? taches,
    bool? isLoading,
    String? error,
    Set<String>? updatingIds,
  }) {
    return TacheJourState(
      taches: taches ?? this.taches,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      updatingIds: updatingIds ?? this.updatingIds,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────
class TacheJourNotifier extends StateNotifier<TacheJourState> {
  final GetTachesDuJour _getTaches;
  final UpdateStatutTache _updateStatut;
  final String _dateStr;

  TacheJourNotifier({
    required GetTachesDuJour getTaches,
    required UpdateStatutTache updateStatut,
    required String dateStr,
  })  : _getTaches = getTaches,
        _updateStatut = updateStatut,
        _dateStr = dateStr,
        super(const TacheJourState());

  Future<void> charger({required String employeeId}) async {
    state = state.copyWith(isLoading: true, error: null);
    final result =
        await _getTaches(employeeId: employeeId, dateStr: _dateStr);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (list) => state = state.copyWith(isLoading: false, taches: list),
    );
  }

  Future<bool> updateStatut({
    required String id,
    required StatutTache statut,
    String? motifAbsent,
  }) async {
    state = state.copyWith(
        updatingIds: {...state.updatingIds, id}, error: null);
    final result = await _updateStatut(
        id: id, statut: statut, motifAbsent: motifAbsent);
    return result.fold(
      (f) {
        state = state.copyWith(
          updatingIds: state.updatingIds.difference({id}),
          error: f.message,
        );
        return false;
      },
      (updated) {
        state = state.copyWith(
          taches: state.taches.map((t) => t.id == id ? updated : t).toList(),
          updatingIds: state.updatingIds.difference({id}),
        );
        return true;
      },
    );
  }
}

// ── Provider (family par date ISO) ───────────────────────
final tacheJourNotifierProvider = StateNotifierProvider.family<
    TacheJourNotifier, TacheJourState, String>(
  (ref, dateStr) => TacheJourNotifier(
    getTaches: ref.watch(_getTachesProvider),
    updateStatut: ref.watch(_updateStatutProvider),
    dateStr: dateStr,
  ),
);
