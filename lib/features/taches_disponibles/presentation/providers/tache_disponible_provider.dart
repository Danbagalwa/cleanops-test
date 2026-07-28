import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/tache_disponible_datasource.dart';
import '../../data/repositories/tache_disponible_repository_impl.dart';
import '../../domain/entities/tache_disponible.dart';
import '../../domain/repositories/tache_disponible_repository.dart';

// ── Infrastructure ────────────────────────────────────────
final tacheDisponibleDatasourceProvider = Provider<TacheDisponibleDatasource>(
  (_) => TacheDisponibleDatasourceImpl(),
);

final tacheDisponibleRepositoryProvider =
    Provider<TacheDisponibleRepository>((ref) {
  return TacheDisponibleRepositoryImpl(
      ref.watch(tacheDisponibleDatasourceProvider));
});

// ── État ──────────────────────────────────────────────────
class TacheDisponibleState {
  final List<TacheDisponible> taches;
  final bool isLoading;
  final String? error;
  final Set<String> processingIds;

  const TacheDisponibleState({
    this.taches = const [],
    this.isLoading = false,
    this.error,
    this.processingIds = const {},
  });

  TacheDisponibleState copyWith({
    List<TacheDisponible>? taches,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Set<String>? processingIds,
  }) {
    return TacheDisponibleState(
      taches: taches ?? this.taches,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      processingIds: processingIds ?? this.processingIds,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────
class TacheDisponibleNotifier
    extends StateNotifier<TacheDisponibleState> {
  final TacheDisponibleRepository _repo;

  TacheDisponibleNotifier(this._repo)
      : super(const TacheDisponibleState());

  Future<void> charger({
    required String employeeId,
    required DateTime date,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result =
        await _repo.getTachesDisponibles(employeeId: employeeId, date: date);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (list) => state = state.copyWith(isLoading: false, taches: list),
    );
  }

  Future<bool> libererTache({
    required String tacheJourId,
    required String libereParId,
    required MotifDisponible motif,
    String? employeeVisibleId,
  }) async {
    state = state.copyWith(
        processingIds: {...state.processingIds, tacheJourId});
    final result = await _repo.libererTache(
      tacheJourId: tacheJourId,
      libereParId: libereParId,
      motif: motif,
      employeeVisibleId: employeeVisibleId,
    );

    final ids = Set<String>.from(state.processingIds)..remove(tacheJourId);
    return result.fold(
      (f) {
        state = state.copyWith(error: f.message, processingIds: ids);
        return false;
      },
      (td) {
        state = state.copyWith(
            taches: [...state.taches, td], processingIds: ids);
        return true;
      },
    );
  }

  Future<bool> prendreEnCharge({
    required String tacheDisponibleId,
    required String employeeId,
  }) async {
    state = state.copyWith(
        processingIds: {...state.processingIds, tacheDisponibleId});
    final result = await _repo.prendreEnCharge(
      tacheDisponibleId: tacheDisponibleId,
      employeeId: employeeId,
    );

    final ids = Set<String>.from(state.processingIds)
      ..remove(tacheDisponibleId);
    return result.fold(
      (f) {
        state = state.copyWith(error: f.message, processingIds: ids);
        return false;
      },
      (td) {
        // Retirer la tâche de la liste disponible
        final updated =
            state.taches.where((t) => t.id != tacheDisponibleId).toList();
        state = state.copyWith(taches: updated, processingIds: ids);
        return true;
      },
    );
  }
}

final tacheDisponibleNotifierProvider =
    StateNotifierProvider<TacheDisponibleNotifier, TacheDisponibleState>((ref) {
  return TacheDisponibleNotifier(ref.watch(tacheDisponibleRepositoryProvider));
});
