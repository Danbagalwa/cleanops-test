import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/resident_espace_datasource.dart';
import '../../data/repositories/resident_espace_repository_impl.dart';
import '../../domain/entities/demande_resident.dart';
import '../../domain/entities/notification_resident.dart';
import '../../domain/entities/tache_resident.dart';
import '../../domain/repositories/resident_espace_repository.dart';

// ── Infrastructure ────────────────────────────────────────

final residentEspaceDatasourceProvider = Provider<ResidentEspaceDatasource>(
  (_) => ResidentEspaceDatasourceImpl(),
);

final residentEspaceRepositoryProvider = Provider<ResidentEspaceRepository>(
  (ref) => ResidentEspaceRepositoryImpl(
      ref.watch(residentEspaceDatasourceProvider)),
);

// ── State ─────────────────────────────────────────────────

class ResidentEspaceState {
  final List<TacheResident> taches;
  final List<DemandeResident> demandes;
  final List<NotificationResident> notifications;
  final bool isLoadingTaches;
  final bool isLoadingDemandes;
  final bool isLoadingNotifications;
  final bool isSendingDemande;
  final String? errorTaches;
  final String? errorDemandes;

  const ResidentEspaceState({
    this.taches = const [],
    this.demandes = const [],
    this.notifications = const [],
    this.isLoadingTaches = false,
    this.isLoadingDemandes = false,
    this.isLoadingNotifications = false,
    this.isSendingDemande = false,
    this.errorTaches,
    this.errorDemandes,
  });

  // ── Computed — tâches ─────────────────────────────────────

  TacheResident? get menageAujourdhui =>
      taches.where((t) => t.estPrevu && t.estAujourdhui).firstOrNull;

  List<TacheResident> get prochaines {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return taches
        .where((t) => t.estPrevu && !t.dateReelle.isBefore(today))
        .toList();
  }

  List<TacheResident> get tachesNonFaites =>
      taches.where((t) => t.estPrevu).toList();

  TacheResident? get dernierMenage {
    final faits = taches.where((t) => t.estFait).toList();
    return faits.isEmpty ? null : faits.last;
  }

  // ── Computed — demandes / notifications ───────────────────

  int get badgeDemandes =>
      demandes.where((d) => d.attendsReponseResident).length;

  int get nombreNotificationsNonLues =>
      notifications.where((n) => !n.isLue).length;

  List<NotificationResident> get notificationsNonLues =>
      notifications.where((n) => !n.isLue).toList();

  // ── copyWith ──────────────────────────────────────────────

  ResidentEspaceState copyWith({
    List<TacheResident>? taches,
    List<DemandeResident>? demandes,
    List<NotificationResident>? notifications,
    bool? isLoadingTaches,
    bool? isLoadingDemandes,
    bool? isLoadingNotifications,
    bool? isSendingDemande,
    String? errorTaches,
    String? errorDemandes,
    bool clearErrorTaches = false,
    bool clearErrorDemandes = false,
  }) =>
      ResidentEspaceState(
        taches: taches ?? this.taches,
        demandes: demandes ?? this.demandes,
        notifications: notifications ?? this.notifications,
        isLoadingTaches: isLoadingTaches ?? this.isLoadingTaches,
        isLoadingDemandes: isLoadingDemandes ?? this.isLoadingDemandes,
        isLoadingNotifications:
            isLoadingNotifications ?? this.isLoadingNotifications,
        isSendingDemande: isSendingDemande ?? this.isSendingDemande,
        errorTaches: clearErrorTaches ? null : errorTaches ?? this.errorTaches,
        errorDemandes:
            clearErrorDemandes ? null : errorDemandes ?? this.errorDemandes,
      );
}

// ── Notifier ──────────────────────────────────────────────

class ResidentEspaceNotifier extends StateNotifier<ResidentEspaceState> {
  final ResidentEspaceRepository _repo;
  final String _residentId;
  final String _residentPrenom;
  final String _residentNom;

  ResidentEspaceNotifier({
    required ResidentEspaceRepository repo,
    required String residentId,
    required String residentPrenom,
    required String residentNom,
  })  : _repo = repo,
        _residentId = residentId,
        _residentPrenom = residentPrenom,
        _residentNom = residentNom,
        super(const ResidentEspaceState()) {
    if (residentId.isNotEmpty) charger();
  }

  Future<void> charger() async {
    chargerTaches();
    chargerDemandes();
    chargerNotifications();
  }

  Future<void> chargerTaches() async {
    state = state.copyWith(isLoadingTaches: true, clearErrorTaches: true);
    final result = await _repo.getTaches(_residentId);
    result.fold(
      (f) => state =
          state.copyWith(isLoadingTaches: false, errorTaches: f.message),
      (taches) =>
          state = state.copyWith(isLoadingTaches: false, taches: taches),
    );
  }

  Future<void> chargerDemandes() async {
    state = state.copyWith(isLoadingDemandes: true, clearErrorDemandes: true);
    final result = await _repo.getDemandes(_residentId);
    result.fold(
      (f) => state =
          state.copyWith(isLoadingDemandes: false, errorDemandes: f.message),
      (demandes) =>
          state = state.copyWith(isLoadingDemandes: false, demandes: demandes),
    );
  }

  Future<void> chargerNotifications() async {
    state = state.copyWith(isLoadingNotifications: true);
    final result = await _repo.getNotificationsResident(_residentId);
    result.fold(
      (_) => state = state.copyWith(isLoadingNotifications: false),
      (notifs) => state =
          state.copyWith(isLoadingNotifications: false, notifications: notifs),
    );
  }

  Future<bool> creerDemande({
    required TypeDemande type,
    String? tacheJourId,
    required String motif,
    bool estUrgente = false,
  }) async {
    state = state.copyWith(isSendingDemande: true, clearErrorDemandes: true);
    final result = await _repo.creerDemande(
      residentId: _residentId,
      type: type,
      tacheJourId: tacheJourId,
      motif: motif,
      estUrgente: estUrgente,
    );
    return result.fold(
      (f) {
        state =
            state.copyWith(isSendingDemande: false, errorDemandes: f.message);
        return false;
      },
      (demande) {
        state = state.copyWith(
          isSendingDemande: false,
          demandes: [demande, ...state.demandes],
        );
        return true;
      },
    );
  }

  Future<void> accepterProposition(String demandeId) async {
    final result = await _repo.accepterProposition(
      demandeId: demandeId,
      residentPrenom: _residentPrenom,
      residentNom: _residentNom,
    );
    result.fold(
      (f) => state = state.copyWith(errorDemandes: f.message),
      (updated) => state = state.copyWith(
        demandes:
            state.demandes.map((d) => d.id == updated.id ? updated : d).toList(),
      ),
    );
  }

  Future<void> refuserProposition(String demandeId) async {
    final result = await _repo.refuserProposition(
      demandeId: demandeId,
      residentPrenom: _residentPrenom,
      residentNom: _residentNom,
    );
    result.fold(
      (f) => state = state.copyWith(errorDemandes: f.message),
      (updated) => state = state.copyWith(
        demandes:
            state.demandes.map((d) => d.id == updated.id ? updated : d).toList(),
      ),
    );
  }

  Future<void> marquerNotificationLue(String notifId) async {
    // Optimistic update
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.id == notifId ? _asLue(n) : n)
          .toList(),
    );
    await _repo.marquerNotificationLue(notifId);
  }

  Future<void> toutMarquerLu() async {
    final nonLues = state.notificationsNonLues;
    if (nonLues.isEmpty) return;
    state = state.copyWith(
      notifications: state.notifications.map(_asLue).toList(),
    );
    for (final n in nonLues) {
      await _repo.marquerNotificationLue(n.id);
    }
  }
}

// Crée une copie d'une notification avec isLue = true
NotificationResident _asLue(NotificationResident n) => _NotifLue(n);

class _NotifLue extends NotificationResident {
  _NotifLue(NotificationResident src)
      : super(
          id: src.id,
          residentId: src.residentId,
          tacheJourId: src.tacheJourId,
          type: src.type,
          message: src.message,
          isLue: true,
          createdAt: src.createdAt,
        );
}

// ── Providers ─────────────────────────────────────────────

final residentEspaceNotifierProvider = StateNotifierProvider.autoDispose<
    ResidentEspaceNotifier, ResidentEspaceState>((ref) {
  final employee = ref.watch(employeeCourantProvider);
  return ResidentEspaceNotifier(
    repo: ref.watch(residentEspaceRepositoryProvider),
    residentId: employee?.id ?? '',
    residentPrenom: employee?.prenom ?? '',
    residentNom: employee?.nom ?? '',
  );
});

/// Badge notifications non lues — safe à watch même pour les non-résidents.
final badgeNotifResidentProvider = Provider.autoDispose<int>((ref) {
  final employee = ref.watch(employeeCourantProvider);
  if (employee?.isResident != true) return 0;
  return ref.watch(residentEspaceNotifierProvider).nombreNotificationsNonLues;
});
