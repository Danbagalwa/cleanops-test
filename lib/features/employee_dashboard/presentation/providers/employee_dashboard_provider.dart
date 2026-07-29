import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/employee_dashboard_datasource.dart';
import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/semaine.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import '../../domain/usecases/get_semaine_courante.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ── Datasource ────────────────────────────────────────────
final employeeDashboardDatasourceProvider =
    Provider<EmployeeDashboardDatasource>((ref) {
  return const EmployeeDashboardDatasourceImpl();
});

// ── Repository ────────────────────────────────────────────
final employeeDashboardRepositoryProvider =
    Provider<EmployeeDashboardRepository>((ref) {
  return EmployeeDashboardRepositoryImpl(
    ref.watch(employeeDashboardDatasourceProvider),
  );
});

// ── Usecase ───────────────────────────────────────────────
final getSemaineCouranteProvider = Provider((ref) {
  return GetSemaineCourante(
    ref.watch(employeeDashboardRepositoryProvider),
  );
});

// ── State ─────────────────────────────────────────────────
class DashboardState {
  final Semaine? semaine;
  final String? messageSemaine;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;

  const DashboardState({
    this.semaine,
    this.messageSemaine,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  DashboardState copyWith({
    Semaine? semaine,
    String? messageSemaine,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
  }) {
    return DashboardState(
      semaine: semaine ?? this.semaine,
      messageSemaine: messageSemaine ?? this.messageSemaine,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────
class DashboardNotifier extends StateNotifier<DashboardState> {
  final GetSemaineCourante _getSemaineCourante;
  final EmployeeDashboardRepository _repository;
  final Ref _ref;
  DateTime? _lastLoadedAt;

  DashboardNotifier(this._getSemaineCourante, this._repository, this._ref)
      : super(const DashboardState());

  Future<void> charger({bool force = false}) async {
    final employee = _ref.read(employeeCourantProvider);
    if (employee == null) return;
    if (state.isLoading || state.isRefreshing) return;

    final hasData = state.semaine != null;
    final cacheIsFresh = _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) < const Duration(minutes: 3);
    if (!force && hasData && cacheIsFresh) return;

    state = state.copyWith(
      isLoading: !hasData,
      isRefreshing: hasData,
      error: null,
    );

    final semaineResult = await _getSemaineCourante(employeeId: employee.id);
    final messageResult = await _repository.getMessageSemaine();
    final message = messageResult.fold((_) => null, (m) => m);

    semaineResult.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: failure.message,
      ),
      (semaine) {
        _lastLoadedAt = DateTime.now();
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          semaine: semaine,
          messageSemaine: message,
        );
      },
    );
  }

  Future<void> rafraichir() => charger(force: true);
}

// ── Provider ──────────────────────────────────────────────
final dashboardNotifierProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(
    ref.watch(getSemaineCouranteProvider),
    ref.watch(employeeDashboardRepositoryProvider),
    ref,
  );
});
