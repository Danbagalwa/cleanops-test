import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/aire_commune_datasource.dart';
import '../../data/repositories/aire_commune_repository_impl.dart';
import '../../domain/entities/reset_aire_commune.dart';
import '../../domain/entities/tache_aire_commune.dart';
import '../../domain/repositories/aire_commune_repository.dart';

// ── Infrastructure ────────────────────────────────────────
final aireCommuneDatasourceProvider = Provider<AireCommuneDatasource>(
  (_) => AireCommuneDatasourceImpl(),
);

final aireCommuneRepositoryProvider = Provider<AireCommuneRepository>((ref) {
  return AireCommuneRepositoryImpl(ref.watch(aireCommuneDatasourceProvider));
});

// ── État ──────────────────────────────────────────────────
class AireCommuneState {
  final Map<String, List<TacheAireCommune>> tachesParCategorie;
  final bool isLoading;
  final bool isResetting;
  final String? error;
  final String? categorieSelectee;
  final List<ResetAireCommune> historiqueResets;
  final String jourResetConfig;
  final bool resetAutoActif;

  const AireCommuneState({
    this.tachesParCategorie = const {},
    this.isLoading = false,
    this.isResetting = false,
    this.error,
    this.categorieSelectee,
    this.historiqueResets = const [],
    this.jourResetConfig = 'Lundi',
    this.resetAutoActif = true,
  });

  int getTotalFait(String categorie) =>
      tachesParCategorie[categorie]
          ?.where((t) => t.statut == AireStatut.fait)
          .length ??
      0;

  int getTotal(String categorie) =>
      tachesParCategorie[categorie]?.length ?? 0;

  List<TacheAireCommune> get tachesSelectees =>
      categorieSelectee != null
          ? tachesParCategorie[categorieSelectee!] ?? []
          : [];

  List<TacheAireCommune> get toutesConfirmees =>
      tachesParCategorie.values
          .expand((l) => l)
          .where((t) => t.estFait)
          .toList()
        ..sort((a, b) =>
            (b.confirmeLE ?? DateTime(0)).compareTo(a.confirmeLE ?? DateTime(0)));

  AireCommuneState copyWith({
    Map<String, List<TacheAireCommune>>? tachesParCategorie,
    bool? isLoading,
    bool? isResetting,
    String? error,
    bool clearError = false,
    String? categorieSelectee,
    bool clearCategorie = false,
    List<ResetAireCommune>? historiqueResets,
    String? jourResetConfig,
    bool? resetAutoActif,
  }) {
    return AireCommuneState(
      tachesParCategorie:
          tachesParCategorie ?? this.tachesParCategorie,
      isLoading: isLoading ?? this.isLoading,
      isResetting: isResetting ?? this.isResetting,
      error: clearError ? null : error ?? this.error,
      categorieSelectee: clearCategorie
          ? null
          : categorieSelectee ?? this.categorieSelectee,
      historiqueResets: historiqueResets ?? this.historiqueResets,
      jourResetConfig: jourResetConfig ?? this.jourResetConfig,
      resetAutoActif: resetAutoActif ?? this.resetAutoActif,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────
class AireCommuneNotifier extends StateNotifier<AireCommuneState> {
  final AireCommuneRepository _repo;
  final String _employeeId;

  AireCommuneNotifier(this._repo, {required String employeeId})
      : _employeeId = employeeId,
        super(const AireCommuneState());

  // ── Tâches ──────────────────────────────────────────────

  Future<void> loadTaches() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getTachesAireCommune();
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (list) => state = state.copyWith(
        isLoading: false,
        tachesParCategorie: _grouper(list),
      ),
    );
  }

  Future<void> confirmerZone(String id) async {
    if (_employeeId.isEmpty) return;
    final result = await _repo.confirmerZone(id, _employeeId);
    result.fold(
      (f) => state = state.copyWith(error: f.message),
      (updated) {
        final key = _categorieKey(updated.categorie);
        final newMap =
            Map<String, List<TacheAireCommune>>.from(state.tachesParCategorie);
        if (newMap.containsKey(key)) {
          newMap[key] =
              newMap[key]!.map((t) => t.id == id ? updated : t).toList();
        }
        state = state.copyWith(tachesParCategorie: newMap, clearError: true);
      },
    );
  }

  // ── Reset ────────────────────────────────────────────────

  /// Remet TOUTES les zones de la semaine à AFaire.
  /// Retourne true si succès, false si erreur.
  Future<bool> resetSemaineComplete() async {
    if (_employeeId.isEmpty) return false;
    state = state.copyWith(isResetting: true, clearError: true);
    final result = await _repo.resetSemaineComplete(_employeeId);
    return result.fold(
      (f) {
        state = state.copyWith(isResetting: false, error: f.message);
        return false;
      },
      (_) {
        state = state.copyWith(isResetting: false, clearError: true);
        loadTaches();
        loadHistoriqueResets();
        return true;
      },
    );
  }

  /// Annule la confirmation d'une zone précise.
  Future<bool> annulerConfirmationZone(String zoneId) async {
    final result = await _repo.annulerConfirmationZone(zoneId);
    return result.fold(
      (f) {
        state = state.copyWith(error: f.message);
        return false;
      },
      (_) {
        state = state.copyWith(clearError: true);
        loadTaches();
        return true;
      },
    );
  }

  // ── Historique ────────────────────────────────────────────

  Future<void> loadHistoriqueResets() async {
    final result = await _repo.getHistoriqueResets();
    result.fold(
      (_) {},
      (resets) => state = state.copyWith(historiqueResets: resets),
    );
  }

  // ── Config ───────────────────────────────────────────────

  Future<void> loadConfig() async {
    final jour = await _repo.getJourResetConfig();
    final auto = await _repo.getResetAutoConfig();
    jour.fold((_) {}, (j) => state = state.copyWith(jourResetConfig: j));
    auto.fold((_) {}, (a) => state = state.copyWith(resetAutoActif: a));
  }

  Future<void> updateJourReset(String jour) async {
    state = state.copyWith(jourResetConfig: jour);
    await _repo.updateJourReset(jour);
  }

  Future<void> updateResetAuto(bool actif) async {
    state = state.copyWith(resetAutoActif: actif);
    await _repo.updateResetAuto(actif);
  }

  // ── Navigation ────────────────────────────────────────────

  void selectCategorie(String categorie) {
    state = state.copyWith(categorieSelectee: categorie);
  }

  void deselectionnerCategorie() {
    state = state.copyWith(clearCategorie: true);
  }

  // ── Helpers ───────────────────────────────────────────────

  static Map<String, List<TacheAireCommune>> _grouper(
      List<TacheAireCommune> list) {
    final map = <String, List<TacheAireCommune>>{};
    for (final t in list) {
      (map[_categorieKey(t.categorie)] ??= []).add(t);
    }
    return map;
  }

  static String _categorieKey(AireCategorie c) => switch (c) {
        AireCategorie.ascenseur => 'Ascenseur',
        AireCategorie.corridor => 'Corridor',
        AireCategorie.tapis => 'Tapis',
        AireCategorie.chute => 'Chute',
        AireCategorie.salon => 'Salon',
        AireCategorie.wc => 'WC',
      };
}

// ── Provider ──────────────────────────────────────────────
final aireCommuneNotifierProvider =
    StateNotifierProvider<AireCommuneNotifier, AireCommuneState>((ref) {
  final employeeId = ref.watch(employeeCourantProvider)?.id ?? '';
  return AireCommuneNotifier(
    ref.watch(aireCommuneRepositoryProvider),
    employeeId: employeeId,
  );
});
