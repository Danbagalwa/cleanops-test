import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../data/datasources/employes_datasource.dart';
import '../../data/repositories/employes_repository_impl.dart';
import '../../domain/repositories/employes_repository.dart';
import '../../domain/usecases/add_employe.dart';
import '../../domain/usecases/get_employes.dart';
import '../../domain/usecases/update_employe.dart';

// ── Infrastructure ────────────────────────────────────────
final employesDatasourceProvider = Provider<EmployesDatasource>(
  (_) => EmployesDatasourceImpl(),
);

final employesRepositoryProvider = Provider<EmployesRepository>((ref) {
  return EmployesRepositoryImpl(ref.watch(employesDatasourceProvider));
});

final _getEmployesProvider = Provider(
  (ref) => GetEmployes(ref.watch(employesRepositoryProvider)),
);

final _addEmployeProvider = Provider(
  (ref) => AddEmploye(ref.watch(employesRepositoryProvider)),
);

final _updateEmployeProvider = Provider(
  (ref) => UpdateEmploye(ref.watch(employesRepositoryProvider)),
);

// ── État ──────────────────────────────────────────────────
class EmployesState {
  final List<Employee> employes;
  final bool isLoading;
  final String? error;

  const EmployesState({
    this.employes = const [],
    this.isLoading = false,
    this.error,
  });

  int get total => employes.length;

  EmployesState copyWith({
    List<Employee>? employes,
    bool? isLoading,
    String? error,
  }) {
    return EmployesState(
      employes: employes ?? this.employes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────
class EmployesNotifier extends StateNotifier<EmployesState> {
  final GetEmployes _get;
  final AddEmploye _add;
  final UpdateEmploye _update;
  final EmployesRepository _repository;

  EmployesNotifier({
    required GetEmployes get,
    required AddEmploye add,
    required UpdateEmploye update,
    required EmployesRepository repository,
  })  : _get = get,
        _add = add,
        _update = update,
        _repository = repository,
        super(const EmployesState());

  Future<void> charger() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _get();
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (list) => state = state.copyWith(isLoading: false, employes: list),
    );
  }

  Future<bool> ajouter(AddEmployeParams params) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _add(params);
    return result.fold(
      (f) {
        state = state.copyWith(isLoading: false, error: f.message);
        return false;
      },
      (emp) {
        final updated = [...state.employes, emp]
          ..sort((a, b) => a.nom.compareTo(b.nom));
        state = state.copyWith(isLoading: false, employes: updated);
        return true;
      },
    );
  }

  Future<bool> modifier(UpdateEmployeParams params) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _update(params);
    return result.fold(
      (f) {
        state = state.copyWith(isLoading: false, error: f.message);
        return false;
      },
      (emp) {
        final updated = state.employes
            .map((e) => e.id == params.id ? emp : e)
            .toList();
        state = state.copyWith(isLoading: false, employes: updated);
        return true;
      },
    );
  }

  Future<bool> toggleActif(String id, {required bool isActif}) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.toggleActif(id, isActif: isActif);
    return result.fold(
      (f) {
        state = state.copyWith(isLoading: false, error: f.message);
        return false;
      },
      (_) {
        final updated = state.employes.map((e) {
          if (e.id != id) return e;
          // Reconstruct with updated isActif using EmployeeModel fields
          return Employee(
            id: e.id,
            nom: e.nom,
            prenom: e.prenom,
            slug: e.slug,
            role: e.role,
            isActif: isActif,
            numeroPointeuse: e.numeroPointeuse,
            nomResidence: e.nomResidence,
            dateCreation: e.dateCreation,
            dateMiseAJour: e.dateMiseAJour,
          );
        }).toList();
        state = state.copyWith(isLoading: false, employes: updated);
        return true;
      },
    );
  }

  void clearError() => state = state.copyWith(error: null);
}

// ── Provider principal ────────────────────────────────────
final employesNotifierProvider =
    StateNotifierProvider<EmployesNotifier, EmployesState>((ref) {
  return EmployesNotifier(
    get: ref.watch(_getEmployesProvider),
    add: ref.watch(_addEmployeProvider),
    update: ref.watch(_updateEmployeProvider),
    repository: ref.watch(employesRepositoryProvider),
  );
});
