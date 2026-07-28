import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/resident_remote_datasource.dart';
import '../../data/repositories/resident_repository_impl.dart';
import '../../domain/entities/resident.dart';
import '../../domain/repositories/resident_repository.dart';
import '../../domain/usecases/get_residents.dart';
import '../../domain/usecases/creer_resident.dart';
import '../../domain/usecases/attribuer_pin.dart';
import '../../domain/usecases/desactiver_resident.dart';

// ── Infrastructure ─────────────────────────────────────────

final residentDatasourceProvider = Provider<ResidentRemoteDatasource>(
  (_) => ResidentRemoteDatasourceImpl(),
);

final residentRepositoryProvider = Provider<ResidentRepository>(
  (ref) => ResidentRepositoryImpl(ref.watch(residentDatasourceProvider)),
);

final _getResidentsProvider = Provider(
  (ref) => GetResidents(ref.watch(residentRepositoryProvider)),
);
final _creerResidentProvider = Provider(
  (ref) => CreerResident(ref.watch(residentRepositoryProvider)),
);
final _attribuerPinProvider = Provider(
  (ref) => AttribuerPin(ref.watch(residentRepositoryProvider)),
);
final _desactiverResidentProvider = Provider(
  (ref) => DesactiverResident(ref.watch(residentRepositoryProvider)),
);

// ══════════════════════════════════════════════════════════
// State
// ══════════════════════════════════════════════════════════

class ResidentState {
  final List<Resident> residents;
  final bool isLoading;
  final String? error;

  const ResidentState({
    this.residents = const [],
    this.isLoading = false,
    this.error,
  });

  int get totalActifs => residents.where((r) => r.isActif).length;

  int get totalInscrits =>
      residents.where((r) => r.isActif && r.aApplication).length;

  int get totalSansApp =>
      residents.where((r) => r.isActif && !r.aApplication).length;

  ResidentState copyWith({
    List<Resident>? residents,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      ResidentState(
        residents: residents ?? this.residents,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

// ══════════════════════════════════════════════════════════
// Notifier
// ══════════════════════════════════════════════════════════

class ResidentNotifier extends StateNotifier<ResidentState> {
  final GetResidents _getResidents;
  final CreerResident _creerResident;
  final AttribuerPin _attribuerPin;
  final DesactiverResident _desactiverResident;
  final ResidentRepository _repo;
  final String? _currentEmployeeId;

  ResidentNotifier({
    required GetResidents getResidents,
    required CreerResident creerResident,
    required AttribuerPin attribuerPin,
    required DesactiverResident desactiverResident,
    required ResidentRepository repo,
    required String? currentEmployeeId,
  })  : _getResidents = getResidents,
        _creerResident = creerResident,
        _attribuerPin = attribuerPin,
        _desactiverResident = desactiverResident,
        _repo = repo,
        _currentEmployeeId = currentEmployeeId,
        super(const ResidentState()) {
    loadResidents();
  }

  Future<void> loadResidents() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getResidents();
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (list) => state = state.copyWith(isLoading: false, residents: list),
    );
  }

  Future<bool> creerResident(
    String appartementId,
    String nom,
    String prenom,
    bool aApplication,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _creerResident(CreerResidentParams(
      appartementId: appartementId,
      nom: nom,
      prenom: prenom,
      aApplication: aApplication,
    ));
    return result.fold(
      (f) {
        state = state.copyWith(isLoading: false, error: f.message);
        return false;
      },
      (r) {
        state = state.copyWith(
          isLoading: false,
          residents: [...state.residents, r]
            ..sort((a, b) => a.prenom.compareTo(b.prenom)),
        );
        return true;
      },
    );
  }

  Future<bool> creerResidentAvecPin(
    String appartementId,
    String nom,
    String prenom,
    bool aApplication,
    String pin,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final creerResult = await _creerResident(CreerResidentParams(
      appartementId: appartementId,
      nom: nom,
      prenom: prenom,
      aApplication: aApplication,
    ));

    Resident? newResident;
    final creerOk = creerResult.fold(
      (f) {
        state = state.copyWith(isLoading: false, error: f.message);
        return false;
      },
      (r) {
        newResident = r;
        state = state.copyWith(
          isLoading: false,
          residents: [...state.residents, r]
            ..sort((a, b) => a.prenom.compareTo(b.prenom)),
        );
        return true;
      },
    );

    if (!creerOk || newResident == null) return false;

    final pinResult = await _attribuerPin(newResident!.id, pin);
    return pinResult.fold(
      (f) {
        state = state.copyWith(error: f.message);
        return false;
      },
      (updated) {
        _updateLocalement(updated);
        return true;
      },
    );
  }

  Future<bool> attribuerPin(String residentId, String pin) async {
    final result = await _attribuerPin(residentId, pin);
    return result.fold(
      (f) {
        state = state.copyWith(error: f.message);
        return false;
      },
      (updated) {
        _updateLocalement(updated);
        return true;
      },
    );
  }

  Future<bool> desactiverResident(String residentId) async {
    if (_currentEmployeeId == null) return false;
    final result =
        await _desactiverResident(residentId, _currentEmployeeId);
    return result.fold(
      (f) {
        state = state.copyWith(error: f.message);
        return false;
      },
      (updated) {
        _updateLocalement(updated);
        return true;
      },
    );
  }

  Future<bool> activerResident(String residentId) async {
    final result = await _repo.activerResident(residentId);
    return result.fold(
      (f) {
        state = state.copyWith(error: f.message);
        return false;
      },
      (updated) {
        _updateLocalement(updated);
        return true;
      },
    );
  }

  Future<bool> toggleApplication(
      String residentId, bool aApplication) async {
    final result =
        await _repo.toggleApplication(residentId, aApplication);
    return result.fold(
      (f) {
        state = state.copyWith(error: f.message);
        return false;
      },
      (updated) {
        _updateLocalement(updated);
        return true;
      },
    );
  }

  void _updateLocalement(Resident updated) {
    state = state.copyWith(
      residents: state.residents
          .map((r) => r.id == updated.id ? updated : r)
          .toList(),
    );
  }
}

// ── Provider ───────────────────────────────────────────────

final residentNotifierProvider = StateNotifierProvider.autoDispose<
    ResidentNotifier, ResidentState>((ref) {
  final employee = ref.watch(employeeCourantProvider);
  return ResidentNotifier(
    getResidents: ref.watch(_getResidentsProvider),
    creerResident: ref.watch(_creerResidentProvider),
    attribuerPin: ref.watch(_attribuerPinProvider),
    desactiverResident: ref.watch(_desactiverResidentProvider),
    repo: ref.watch(residentRepositoryProvider),
    currentEmployeeId: employee?.id,
  );
});
