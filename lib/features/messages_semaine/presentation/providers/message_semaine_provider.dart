import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/message_semaine_datasource.dart';
import '../../data/repositories/message_semaine_repository_impl.dart';
import '../../domain/entities/message_semaine.dart';
import '../../domain/repositories/message_semaine_repository.dart';

// ── Contenu automatique selon le jour ─────────────────────

String getMessageAutomatique() {
  return switch (DateTime.now().weekday) {
    1 => "Bonne semaine à toute l'équipe ! 💪",
    2 => "On continue sur cette belle lancée ! ⭐",
    3 => "Mi-semaine — vous êtes fantastiques ! 😊",
    4 => "Presque vendredi — courage ! 🌟",
    5 => "Dernière ligne droite — bravo ! 🎉",
    _ => "Bonne journée à toute l'équipe ! 😊",
  };
}

const List<String> messagesFete = [
  "Joyeuses fêtes à toute l'équipe ! 🎄",
  "Joyeuses Pâques ! 🐣",
  "Bienvenue au printemps ! 🌸",
  "Bonne fête à tous ! 🎃",
  "Bonne année à toute l'équipe ! 🎆",
  "Bonne Saint-Valentin ! ❤️",
  "Joyeuse fête des Mères ! 🌷",
];

// ── Infrastructure ─────────────────────────────────────────

final messageSemaineDatasourceProvider = Provider<MessageSemaineDatasource>(
  (_) => MessageSemaineDatasourceImpl(),
);

final messageSemaineRepositoryProvider = Provider<MessageSemaineRepository>(
  (ref) => MessageSemaineRepositoryImpl(
    ref.watch(messageSemaineDatasourceProvider),
  ),
);

// ══════════════════════════════════════════════════════════
// State
// ══════════════════════════════════════════════════════════

class MessageSemaineState {
  final MessageSemaine? messageActif;
  final List<MessageSemaine> historique;
  final bool isLoading;
  final String? error;

  const MessageSemaineState({
    this.messageActif,
    this.historique = const [],
    this.isLoading = false,
    this.error,
  });

  MessageSemaineState copyWith({
    MessageSemaine? messageActif,
    bool clearMessageActif = false,
    List<MessageSemaine>? historique,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MessageSemaineState(
      messageActif:
          clearMessageActif ? null : messageActif ?? this.messageActif,
      historique: historique ?? this.historique,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ══════════════════════════════════════════════════════════
// Notifier
// ══════════════════════════════════════════════════════════

class MessageSemaineNotifier extends StateNotifier<MessageSemaineState> {
  final MessageSemaineRepository _repo;
  final String? _currentEmployeeId;

  MessageSemaineNotifier(this._repo, this._currentEmployeeId)
      : super(const MessageSemaineState()) {
    loadMessageActif();
  }

  Future<void> loadMessageActif() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getMessageActif();
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (msg) => state = state.copyWith(
        isLoading: false,
        messageActif: msg,
        clearMessageActif: msg == null,
      ),
    );
  }

  Future<void> loadHistorique() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getHistorique();
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (list) => state = state.copyWith(isLoading: false, historique: list),
    );
  }

  Future<bool> creerMessage(String contenu, MessageType type) async {
    if (_currentEmployeeId == null) {
      state = state.copyWith(error: 'Utilisateur non identifié');
      return false;
    }
    // Un message suggéré sans texte reçoit la suggestion du jour ; un texte
    // fourni (republication) est gardé tel quel.
    final resolvedContenu =
        type == MessageType.automatique && contenu.trim().isEmpty
            ? getMessageAutomatique()
            : contenu;
    state = state.copyWith(isLoading: true, clearError: true);
    final result =
        await _repo.creerMessage(resolvedContenu, type, _currentEmployeeId);
    return result.fold(
      (f) {
        state = state.copyWith(isLoading: false, error: f.message);
        return false;
      },
      (msg) {
        // Le nouveau message devient l'actif ; l'ancien passe en archivé
        // (le serveur le désactive au même moment).
        final updated = [
          msg,
          for (final m in state.historique)
            if (m.id != msg.id) m.isActif ? m.archive(msg.dateCreation) : m,
        ];
        state = state.copyWith(
          isLoading: false,
          messageActif: msg,
          historique: updated,
        );
        return true;
      },
    );
  }

  Future<bool> desactiverMessage(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.desactiverMessage(id);
    return result.fold(
      (f) {
        state = state.copyWith(isLoading: false, error: f.message);
        return false;
      },
      (_) {
        final updatedHistorique =
            state.historique.map((m) => m.id == id ? m.archive() : m).toList();
        state = state.copyWith(
          isLoading: false,
          clearMessageActif: state.messageActif?.id == id,
          messageActif:
              state.messageActif?.id == id ? null : state.messageActif,
          historique: updatedHistorique,
        );
        return true;
      },
    );
  }
}

// ── Provider ───────────────────────────────────────────────

final messageSemaineNotifierProvider = StateNotifierProvider.autoDispose<
    MessageSemaineNotifier, MessageSemaineState>((ref) {
  final employee = ref.watch(employeeCourantProvider);
  return MessageSemaineNotifier(
    ref.watch(messageSemaineRepositoryProvider),
    employee?.id,
  );
});
