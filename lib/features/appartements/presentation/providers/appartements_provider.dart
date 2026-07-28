import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/appartements_datasource.dart';
import '../../data/repositories/appartements_repository_impl.dart';
import '../../domain/entities/appartement.dart';
import '../../domain/repositories/appartements_repository.dart';
import '../../domain/usecases/add_appartement.dart';
import '../../domain/usecases/get_appartements.dart';
import '../../domain/usecases/update_appartement.dart';

// ── Providers infrastructure ──────────────────────────────
final appartementsDatasourceProvider = Provider<AppartementsDatasource>(
  (_) => AppartementsDatasourceImpl(),
);

final appartementsRepositoryProvider = Provider<AppartementsRepository>((ref) {
  return AppartementsRepositoryImpl(ref.watch(appartementsDatasourceProvider));
});

final _getAppartementsProvider = Provider(
  (ref) => GetAppartements(ref.watch(appartementsRepositoryProvider)),
);

final _addAppartementProvider = Provider(
  (ref) => AddAppartement(ref.watch(appartementsRepositoryProvider)),
);

final _updateAppartementProvider = Provider(
  (ref) => UpdateAppartement(ref.watch(appartementsRepositoryProvider)),
);

// ── État ──────────────────────────────────────────────────
class AppartementsState {
  final List<Appartement> appartements;
  final bool isLoading;
  final String? error;

  const AppartementsState({
    this.appartements = const [],
    this.isLoading = false,
    this.error,
  });

  int get total => appartements.length;

  AppartementsState copyWith({
    List<Appartement>? appartements,
    bool? isLoading,
    String? error,
  }) {
    return AppartementsState(
      appartements: appartements ?? this.appartements,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────
class AppartementsNotifier extends StateNotifier<AppartementsState> {
  final GetAppartements _get;
  final AddAppartement _add;
  final UpdateAppartement _update;
  final AppartementsRepository _repository;

  AppartementsNotifier({
    required GetAppartements get,
    required AddAppartement add,
    required UpdateAppartement update,
    required AppartementsRepository repository,
  })  : _get = get,
        _add = add,
        _update = update,
        _repository = repository,
        super(const AppartementsState());

  Future<void> charger() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _get();
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (list) => state = state.copyWith(isLoading: false, appartements: list),
    );
  }

  Future<bool> ajouter({
    required String numero,
    required String taille,
    required int minutesBase,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _add(AddAppartementParams(
      numero: numero,
      taille: taille,
      minutesBase: minutesBase,
    ));
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (appt) {
        final updated = [...state.appartements, appt]
          ..sort((a, b) => a.numero.compareTo(b.numero));
        state = state.copyWith(isLoading: false, appartements: updated);
        return true;
      },
    );
  }

  Future<bool> modifier({
    required String id,
    required String numero,
    required String taille,
    required int minutesBase,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _update(UpdateAppartementParams(
      id: id,
      numero: numero,
      taille: taille,
      minutesBase: minutesBase,
    ));
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (appt) {
        final updated = state.appartements
            .map((a) => a.id == id ? appt : a)
            .toList();
        state = state.copyWith(isLoading: false, appartements: updated);
        return true;
      },
    );
  }

  Future<bool> supprimer(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.deleteAppartement(id);
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        final updated =
            state.appartements.where((a) => a.id != id).toList();
        state = state.copyWith(isLoading: false, appartements: updated);
        return true;
      },
    );
  }

  void clearError() => state = state.copyWith(error: null);
}

// ── Provider principal ────────────────────────────────────
final appartementsNotifierProvider =
    StateNotifierProvider<AppartementsNotifier, AppartementsState>((ref) {
  return AppartementsNotifier(
    get: ref.watch(_getAppartementsProvider),
    add: ref.watch(_addAppartementProvider),
    update: ref.watch(_updateAppartementProvider),
    repository: ref.watch(appartementsRepositoryProvider),
  );
});
