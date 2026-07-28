import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/employer_dashboard_datasource.dart';
import '../../data/repositories/employer_dashboard_repository_impl.dart';
import '../../domain/entities/progression_jour.dart';
import '../../domain/repositories/employer_dashboard_repository.dart';

// ── Infrastructure ────────────────────────────────────────
final employerDashboardDatasourceProvider =
    Provider<EmployerDashboardDatasource>(
  (_) => EmployerDashboardDatasourceImpl(),
);

final employerDashboardRepositoryProvider =
    Provider<EmployerDashboardRepository>((ref) {
  return EmployerDashboardRepositoryImpl(
    ref.watch(employerDashboardDatasourceProvider),
  );
});

// ── État ──────────────────────────────────────────────────
class EmployerDashboardState {
  final List<ProgressionJour> progressions;
  final bool isLoading;
  final String? error;

  const EmployerDashboardState({
    this.progressions = const [],
    this.isLoading = false,
    this.error,
  });

  EmployerDashboardState copyWith({
    List<ProgressionJour>? progressions,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return EmployerDashboardState(
      progressions: progressions ?? this.progressions,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────
class EmployerDashboardNotifier
    extends StateNotifier<EmployerDashboardState> {
  final EmployerDashboardRepository _repo;

  EmployerDashboardNotifier(this._repo)
      : super(const EmployerDashboardState());

  Future<void> loadProgressionJour() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getProgressionJour();
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (list) => state = state.copyWith(isLoading: false, progressions: list),
    );
  }
}

// ── Provider ──────────────────────────────────────────────
final employerDashboardNotifierProvider = StateNotifierProvider<
    EmployerDashboardNotifier, EmployerDashboardState>((ref) {
  return EmployerDashboardNotifier(
    ref.watch(employerDashboardRepositoryProvider),
  );
});
