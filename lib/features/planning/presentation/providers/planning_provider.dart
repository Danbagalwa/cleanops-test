import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/planning_datasource.dart';
import '../../data/repositories/planning_repository_impl.dart';
import '../../domain/entities/planning_template.dart';
import '../../domain/repositories/planning_repository.dart';
import '../../domain/usecases/get_planning_employee.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';

// ── Infrastructure ────────────────────────────────────────
final planningDatasourceProvider = Provider<PlanningDatasource>(
  (_) => PlanningDatasourceImpl(),
);

final planningRepositoryProvider = Provider<PlanningRepository>((ref) {
  return PlanningRepositoryImpl(ref.watch(planningDatasourceProvider));
});

final _getPlanningProvider = Provider(
  (ref) => GetPlanningEmployee(ref.watch(planningRepositoryProvider)),
);

// ── État ──────────────────────────────────────────────────
class PlanningState {
  final List<PlanningTemplate> templates;
  final bool isLoading;
  final String? error;
  final int semaineVue; // 1-4 — cycle week shown in team view

  const PlanningState({
    this.templates = const [],
    this.isLoading = false,
    this.error,
    this.semaineVue = 1,
  });

  PlanningState copyWith({
    List<PlanningTemplate>? templates,
    bool? isLoading,
    String? error,
    int? semaineVue,
  }) {
    return PlanningState(
      templates: templates ?? this.templates,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      semaineVue: semaineVue ?? this.semaineVue,
    );
  }

  List<PlanningTemplate> pourSlot(
    String employeeId,
    int semaine,
    String jour,
    PeriodeType periode,
  ) {
    return templates
        .where((t) =>
            t.employeeId == employeeId &&
            t.numeroSemaine == semaine &&
            t.jour == jour &&
            t.periode == periode)
        .toList()
      ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));
  }

  List<PlanningTemplate> pourEmployee(String employeeId) {
    return templates.where((t) => t.employeeId == employeeId).toList();
  }

  List<String> employeeIds() {
    return templates.map((t) => t.employeeId).toSet().toList();
  }
}

// ── Notifier ──────────────────────────────────────────────
class PlanningNotifier extends StateNotifier<PlanningState> {
  final GetPlanningEmployee _get;
  final PlanningRepository _repository;
  final String? _employeeId;

  PlanningNotifier({
    required GetPlanningEmployee get,
    required PlanningRepository repository,
    String? employeeId,
  })  : _get = get,
        _repository = repository,
        _employeeId = employeeId,
        super(const PlanningState());

  Future<void> charger() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _get(employeeId: _employeeId);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (list) => state = state.copyWith(isLoading: false, templates: list),
    );
  }

  Future<bool> ajouterSlot({
    required String employeeId,
    required String appartementId,
    required int numeroSemaine,
    required String jour,
    required PeriodeType periode,
  }) async {
    // Règle : un appartement ne peut être visité qu'une seule fois par jour
    final conflit = state.templates.where((t) =>
        t.appartementId == appartementId &&
        t.numeroSemaine == numeroSemaine &&
        t.jour == jour).firstOrNull;

    if (conflit != null) {
      state = state.copyWith(
        error: 'Cet appartement est déjà attribué le $jour (Sem. $numeroSemaine). '
            "Chaque appartement ne peut être visité qu'une seule fois par jour.",
      );
      return false;
    }

    final existing = state.pourSlot(employeeId, numeroSemaine, jour, periode);
    final numeroTache = existing.isEmpty ? 1 : existing.last.numeroTache + 1;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.ajouterSlot(
      employeeId: employeeId,
      appartementId: appartementId,
      numeroSemaine: numeroSemaine,
      jour: jour,
      periode: periode,
      numeroTache: numeroTache,
    );
    return result.fold(
      (f) {
        state = state.copyWith(isLoading: false, error: f.message);
        return false;
      },
      (template) {
        state = state.copyWith(
          isLoading: false,
          templates: [...state.templates, template],
        );
        return true;
      },
    );
  }

  Future<bool> supprimerSlot(String templateId) async {
    final result = await _repository.supprimerSlot(templateId);
    return result.fold(
      (f) {
        state = state.copyWith(error: f.message);
        return false;
      },
      (_) {
        state = state.copyWith(
          templates: state.templates.where((t) => t.id != templateId).toList(),
        );
        return true;
      },
    );
  }

  Future<bool> deplacerSlot({
    required String templateId,
    required String employeeId,
    required String jour,
    required PeriodeType periode,
    int? numeroTache,
  }) async {
    final current = state.templates
        .where((template) => template.id == templateId)
        .firstOrNull;
    if (current == null) {
      state = state.copyWith(
        error:
            'Cet élément n’est plus disponible. Actualisez le planning pour continuer.',
      );
      return false;
    }

    final destination = state.pourSlot(
      employeeId,
      current.numeroSemaine,
      jour,
      periode,
    );
    final position = numeroTache ??
        (destination.isEmpty ? 1 : destination.last.numeroTache + 1);

    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.deplacerSlot(
      id: templateId,
      employeeId: employeeId,
      jour: jour,
      periode: periode,
      numeroTache: position,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (updated) {
        state = state.copyWith(
          isLoading: false,
          templates: state.templates
              .map((template) =>
                  template.id == templateId ? updated : template)
              .toList(),
        );
        return true;
      },
    );
  }

  void changerSemaine(int semaine) {
    state = state.copyWith(semaineVue: semaine);
  }
}

// ── Provider (family par employeeId) ─────────────────────
// null = charger tous les templates (vue équipe responsable)
// String = charger uniquement cet employé (vue préposée ou navigation directe)
final planningNotifierProvider = StateNotifierProvider.family<
    PlanningNotifier, PlanningState, String?>(
  (ref, employeeId) => PlanningNotifier(
    get: ref.watch(_getPlanningProvider),
    repository: ref.watch(planningRepositoryProvider),
    employeeId: employeeId,
  ),
);
