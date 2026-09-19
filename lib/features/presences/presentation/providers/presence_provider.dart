import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/presence_datasource.dart';
import '../../data/repositories/presence_repository_impl.dart';
import '../../domain/entities/presence.dart';
import '../../domain/repositories/presence_repository.dart';

// ── Infrastructure ────────────────────────────────────────
final presenceDatasourceProvider = Provider<PresenceDatasource>(
  (_) => PresenceDatasourceImpl(),
);

final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  return PresenceRepositoryImpl(ref.watch(presenceDatasourceProvider));
});

// ── État ──────────────────────────────────────────────────
class PresenceState {
  final Presence? maPresence;
  final List<Presence> absences;
  final List<Presence> presencesAvecHeures;
  final bool isLoading;
  final String? error;

  const PresenceState({
    this.maPresence,
    this.absences = const [],
    this.presencesAvecHeures = const [],
    this.isLoading = false,
    this.error,
  });

  PresenceState copyWith({
    Presence? maPresence,
    bool clearPresence = false,
    List<Presence>? absences,
    List<Presence>? presencesAvecHeures,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PresenceState(
      maPresence: clearPresence ? null : maPresence ?? this.maPresence,
      absences: absences ?? this.absences,
      presencesAvecHeures: presencesAvecHeures ?? this.presencesAvecHeures,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ── Notifier — employé (ma présence) ─────────────────────
class MaPresenceNotifier extends StateNotifier<PresenceState> {
  final PresenceRepository _repo;
  final String _employeeId;

  MaPresenceNotifier(this._repo, this._employeeId)
      : super(const PresenceState());

  Future<void> charger(DateTime date) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result =
        await _repo.getMaPresence(employeeId: _employeeId, date: date);
    result.fold(
      (f) => state =
          state.copyWith(isLoading: false, error: f.message),
      (p) => state = state.copyWith(isLoading: false, maPresence: p),
    );
  }

  Future<void> confirmer({
    required DateTime date,
    required StatutPresence statut,
    List<String> responsableIds = const [],
    String? heureDebut,
    String? heureFin,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.confirmerPresence(
      employeeId: _employeeId,
      date: date,
      statut: statut,
      heureDebut: heureDebut,
      heureFin: heureFin,
    );

    await result.fold(
      (f) async =>
          state = state.copyWith(isLoading: false, error: f.message),
      (p) async {
        state = state.copyWith(isLoading: false, maPresence: p);

        // Envoyer alerte si absent
        if (statut.estAbsent && responsableIds.isNotEmpty) {
          await _repo.envoyerAlerteResponsable(
            presenceId: p.id,
            responsableIds: responsableIds,
            message:
                'Une préposée a signalé une absence pour aujourd\'hui.',
            entityId: p.id,
          );
        } else if (!statut.estAbsent &&
            heureDebut != null &&
            heureFin != null &&
            responsableIds.isNotEmpty) {
          // Registre informatif — horaire partiel précisé
          await _repo.envoyerAlerteResponsable(
            presenceId: p.id,
            responsableIds: responsableIds,
            message:
                'Une préposée a précisé un horaire partiel aujourd\'hui : '
                '$heureDebut → $heureFin.',
            entityId: p.id,
            type: 'Rappel',
          );
        }
      },
    );
  }
}

final maPresenceNotifierProvider = StateNotifierProvider.family<
    MaPresenceNotifier, PresenceState, String>((ref, employeeId) {
  return MaPresenceNotifier(
      ref.watch(presenceRepositoryProvider), employeeId);
});

// ── Notifier — responsable (absences du jour) ─────────────
class AbsencesNotifier extends StateNotifier<PresenceState> {
  final PresenceRepository _repo;

  AbsencesNotifier(this._repo) : super(const PresenceState());

  Future<void> charger(DateTime date) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final results = await Future.wait([
      _repo.getAbsencesDuJour(date),
      _repo.getPresencesAvecHeures(date),
    ]);
    final absencesResult = results[0];
    final heuresResult = results[1];

    absencesResult.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (list) => state = state.copyWith(isLoading: false, absences: list),
    );
    heuresResult.fold(
      (_) => null,
      (list) => state = state.copyWith(presencesAvecHeures: list),
    );
  }
}

final absencesNotifierProvider =
    StateNotifierProvider<AbsencesNotifier, PresenceState>((ref) {
  return AbsencesNotifier(ref.watch(presenceRepositoryProvider));
});
