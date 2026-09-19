import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/demande_equipe_datasource.dart';
import '../../data/repositories/demande_equipe_repository_impl.dart';
import '../../domain/entities/demande_equipe.dart';
import '../../domain/repositories/demande_equipe_repository.dart';

// ── Infrastructure ────────────────────────────────────────

final demandeEquipeDatasourceProvider = Provider<DemandeEquipeDatasource>(
  (_) => DemandeEquipeDatasourceImpl(),
);

final demandeEquipeRepositoryProvider = Provider<DemandeEquipeRepository>(
  (ref) =>
      DemandeEquipeRepositoryImpl(ref.watch(demandeEquipeDatasourceProvider)),
);

// ── Côté employé — mes demandes ────────────────────────────

class MesDemandesEquipeState {
  final List<DemandeEquipe> demandes;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const MesDemandesEquipeState({
    this.demandes = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  MesDemandesEquipeState copyWith({
    List<DemandeEquipe>? demandes,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) =>
      MesDemandesEquipeState(
        demandes: demandes ?? this.demandes,
        isLoading: isLoading ?? this.isLoading,
        isSending: isSending ?? this.isSending,
        error: clearError ? null : error ?? this.error,
      );
}

class MesDemandesEquipeNotifier extends StateNotifier<MesDemandesEquipeState> {
  final DemandeEquipeRepository _repo;
  final String _employeeId;
  final String _employeePrenom;
  final String _employeeNom;

  MesDemandesEquipeNotifier({
    required DemandeEquipeRepository repo,
    required String employeeId,
    required String employeePrenom,
    required String employeeNom,
  })  : _repo = repo,
        _employeeId = employeeId,
        _employeePrenom = employeePrenom,
        _employeeNom = employeeNom,
        super(const MesDemandesEquipeState()) {
    if (employeeId.isNotEmpty) charger();
  }

  Future<void> charger() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getMesDemandes(_employeeId);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (list) => state = state.copyWith(isLoading: false, demandes: list),
    );
  }

  Future<bool> creerDemande({
    required TypeDemandeEquipe type,
    required DateTime dateDebut,
    DateTime? dateFin,
    required String motif,
  }) async {
    state = state.copyWith(isSending: true, clearError: true);
    final result = await _repo.creerDemande(
      employeeId: _employeeId,
      employeePrenom: _employeePrenom,
      employeeNom: _employeeNom,
      type: type,
      dateDebut: dateDebut,
      dateFin: dateFin,
      motif: motif,
    );
    return result.fold(
      (f) {
        state = state.copyWith(isSending: false, error: f.message);
        return false;
      },
      (demande) {
        state = state.copyWith(
          isSending: false,
          demandes: [demande, ...state.demandes],
        );
        return true;
      },
    );
  }
}

final mesDemandesEquipeNotifierProvider = StateNotifierProvider.autoDispose<
    MesDemandesEquipeNotifier, MesDemandesEquipeState>((ref) {
  final employee = ref.watch(employeeCourantProvider);
  return MesDemandesEquipeNotifier(
    repo: ref.watch(demandeEquipeRepositoryProvider),
    employeeId: employee?.id ?? '',
    employeePrenom: employee?.prenom ?? '',
    employeeNom: employee?.nom ?? '',
  );
});

// ── Côté responsable — toutes les demandes ─────────────────

class DemandesEquipeResponsableState {
  final List<DemandeEquipe> demandes;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const DemandesEquipeResponsableState({
    this.demandes = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  List<DemandeEquipe> get enAttente =>
      demandes.where((d) => d.enAttente).toList();
  List<DemandeEquipe> get resolues =>
      demandes.where((d) => d.resolue).toList();
  int get badgeEnAttente => enAttente.length;

  DemandesEquipeResponsableState copyWith({
    List<DemandeEquipe>? demandes,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) =>
      DemandesEquipeResponsableState(
        demandes: demandes ?? this.demandes,
        isLoading: isLoading ?? this.isLoading,
        isSending: isSending ?? this.isSending,
        error: clearError ? null : error ?? this.error,
      );
}

class DemandesEquipeResponsableNotifier
    extends StateNotifier<DemandesEquipeResponsableState> {
  final DemandeEquipeRepository _repo;
  final String _responsableId;

  DemandesEquipeResponsableNotifier(this._repo, this._responsableId)
      : super(const DemandesEquipeResponsableState()) {
    charger();
  }

  Future<void> charger() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getAllDemandes();
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (demandes) =>
          state = state.copyWith(isLoading: false, demandes: demandes),
    );
  }

  Future<bool> traiter({
    required String demandeId,
    required bool approuve,
    String? note,
  }) async {
    state = state.copyWith(isSending: true, clearError: true);
    final result = await _repo.traiterDemande(
      demandeId: demandeId,
      traiteParId: _responsableId,
      approuve: approuve,
      note: note,
    );
    return result.fold(
      (f) {
        state = state.copyWith(isSending: false, error: f.message);
        return false;
      },
      (updated) {
        state = state.copyWith(
          isSending: false,
          demandes: state.demandes
              .map((d) => d.id == updated.id ? updated : d)
              .toList(),
        );
        return true;
      },
    );
  }
}

final demandesEquipeResponsableProvider = StateNotifierProvider.autoDispose<
    DemandesEquipeResponsableNotifier, DemandesEquipeResponsableState>((ref) {
  final employee = ref.watch(employeeCourantProvider);
  return DemandesEquipeResponsableNotifier(
    ref.watch(demandeEquipeRepositoryProvider),
    employee?.id ?? '',
  );
});
