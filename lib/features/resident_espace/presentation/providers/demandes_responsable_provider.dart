import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/demande_resident.dart';
import '../../domain/repositories/resident_espace_repository.dart';
import 'resident_espace_provider.dart';

// ── State ─────────────────────────────────────────────────

class DemandesResponsableState {
  final List<DemandeResident> demandes;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const DemandesResponsableState({
    this.demandes = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  List<DemandeResident> get enAttente =>
      demandes.where((d) => d.enAttente).toList();

  List<DemandeResident> get repondues =>
      demandes.where((d) => d.repondue).toList();

  List<DemandeResident> get resolues =>
      demandes.where((d) => d.resolue).toList();

  int get badgeEnAttente => enAttente.length;

  DemandesResponsableState copyWith({
    List<DemandeResident>? demandes,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) =>
      DemandesResponsableState(
        demandes: demandes ?? this.demandes,
        isLoading: isLoading ?? this.isLoading,
        isSending: isSending ?? this.isSending,
        error: clearError ? null : error ?? this.error,
      );
}

// ── Notifier ──────────────────────────────────────────────

class DemandesResponsableNotifier
    extends StateNotifier<DemandesResponsableState> {
  final ResidentEspaceRepository _repo;

  DemandesResponsableNotifier(this._repo)
      : super(const DemandesResponsableState()) {
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

  Future<bool> repondre({
    required String demandeId,
    required String reponse,
    DateTime? propositionDate,
    String? propositionPeriode,
  }) async {
    state = state.copyWith(isSending: true, clearError: true);
    final result = await _repo.repondreDemandeResident(
      demandeId: demandeId,
      reponse: reponse,
      propositionDate: propositionDate,
      propositionPeriode: propositionPeriode,
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

// ── Provider ──────────────────────────────────────────────

final demandesResponsableProvider = StateNotifierProvider.autoDispose<
    DemandesResponsableNotifier, DemandesResponsableState>((ref) {
  return DemandesResponsableNotifier(
      ref.watch(residentEspaceRepositoryProvider));
});
