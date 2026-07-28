import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/chat_groupe_datasource.dart';
import '../../data/repositories/chat_groupe_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_groupe_repository.dart';

// ── Infrastructure ────────────────────────────────────────

final chatGroupeDatasourceProvider = Provider<ChatGroupeDatasource>(
  (_) => ChatGroupeDatasourceImpl(),
);

final chatGroupeRepositoryProvider = Provider<ChatGroupeRepository>((ref) {
  return ChatGroupeRepositoryImpl(ref.watch(chatGroupeDatasourceProvider));
});

// ── State ─────────────────────────────────────────────────

class ChatGroupeState {
  final List<ChatMessage> messages;
  final List<ChatMessage> messagesEpingles;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSending;
  final bool hasMore;
  final String? error;

  const ChatGroupeState({
    this.messages = const [],
    this.messagesEpingles = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSending = false,
    this.hasMore = true,
    this.error,
  });

  ChatGroupeState copyWith({
    List<ChatMessage>? messages,
    List<ChatMessage>? messagesEpingles,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSending,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return ChatGroupeState(
      messages: messages ?? this.messages,
      messagesEpingles: messagesEpingles ?? this.messagesEpingles,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────

class ChatGroupeNotifier extends StateNotifier<ChatGroupeState> {
  final ChatGroupeRepository _repo;
  final ChatGroupeDatasource _ds;
  final String _currentUserId;

  bool _disposed = false;

  ChatGroupeNotifier({
    required ChatGroupeRepository repo,
    required ChatGroupeDatasource ds,
    required String currentUserId,
  })  : _repo = repo,
        _ds = ds,
        _currentUserId = currentUserId,
        super(const ChatGroupeState());

  // ── Chargement initial ─────────────────────────────────

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getMessages(offset: 0, limit: 50);
    if (_disposed) return;
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (msgs) => state = state.copyWith(
        isLoading: false,
        messages: msgs,
        hasMore: msgs.length >= 50,
      ),
    );
    await _refreshEpingles();
  }

  // ── Pagination (scroll vers le haut = messages plus anciens) ──

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    final result = await _repo.getMessages(
        offset: state.messages.length, limit: 50);
    if (_disposed) return;
    result.fold(
      (_) => state = state.copyWith(isLoadingMore: false),
      (older) => state = state.copyWith(
        isLoadingMore: false,
        messages: [...state.messages, ...older],
        hasMore: older.length >= 50,
      ),
    );
  }

  // ── Envoi ─────────────────────────────────────────────

  Future<bool> envoyerMessage(String texte) async {
    if (texte.trim().isEmpty || _currentUserId.isEmpty) return false;
    state = state.copyWith(isSending: true, clearError: true);
    final result = await _repo.envoyerMessage(
        auteurId: _currentUserId, message: texte.trim());
    if (_disposed) return false;
    return result.fold(
      (f) {
        state = state.copyWith(isSending: false, error: f.message);
        return false;
      },
      (msg) {
        state = state.copyWith(
          isSending: false,
          messages: [msg, ...state.messages],
        );
        return true;
      },
    );
  }

  // ── Épingler / Désépingler ─────────────────────────────

  Future<void> epinglerMessage(String messageId) async {
    if (_currentUserId.isEmpty) return;
    final result = await _repo.epinglerMessage(
        messageId: messageId, epingleParId: _currentUserId);
    if (_disposed) return;
    result.fold(
      (f) => state = state.copyWith(error: f.message),
      (updated) {
        state = state.copyWith(
          messages: _remplacerMessage(updated),
          messagesEpingles: [
            updated,
            ...state.messagesEpingles.where((m) => m.id != updated.id),
          ],
        );
      },
    );
  }

  Future<void> desepinglerMessage(String messageId) async {
    final result =
        await _repo.desepinglerMessage(messageId: messageId);
    if (_disposed) return;
    result.fold(
      (f) => state = state.copyWith(error: f.message),
      (updated) {
        state = state.copyWith(
          messages: _remplacerMessage(updated),
          messagesEpingles:
              state.messagesEpingles.where((m) => m.id != updated.id).toList(),
        );
      },
    );
  }

  // ── Suppression ────────────────────────────────────────

  Future<void> supprimerMessage(String messageId) async {
    if (_currentUserId.isEmpty) return;
    final result = await _repo.supprimerMessage(
        messageId: messageId, supprimeParId: _currentUserId);
    if (_disposed) return;
    result.fold(
      (f) => state = state.copyWith(error: f.message),
      (_) {
        state = state.copyWith(
          messages:
              state.messages.where((m) => m.id != messageId).toList(),
          messagesEpingles:
              state.messagesEpingles.where((m) => m.id != messageId).toList(),
        );
      },
    );
  }

  // ── Realtime ───────────────────────────────────────────

  void initRealtime() {
    _ds.initRealtime(onNew: (msg) {
      if (_disposed) return;
      // Éviter doublon (au cas où le sender le reçoit aussi via realtime)
      if (state.messages.any((m) => m.id == msg.id)) return;
      if (msg.isSupprime) return;
      state = state.copyWith(messages: [msg, ...state.messages]);
      if (msg.isEpingle) {
        state = state.copyWith(
          messagesEpingles: [
            msg,
            ...state.messagesEpingles.where((m) => m.id != msg.id),
          ],
        );
      }
    });
  }

  Future<void> disposeRealtime() => _ds.disposeRealtime();

  // ── Helpers ────────────────────────────────────────────

  Future<void> _refreshEpingles() async {
    final result = await _repo.getMessagesEpingles();
    if (_disposed) return;
    result.fold(
      (_) {},
      (epingles) =>
          state = state.copyWith(messagesEpingles: epingles),
    );
  }

  List<ChatMessage> _remplacerMessage(ChatMessage updated) {
    return state.messages
        .map((m) => m.id == updated.id ? updated : m)
        .toList();
  }

  @override
  void dispose() {
    _disposed = true;
    _ds.disposeRealtime();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────

final chatGroupeNotifierProvider =
    StateNotifierProvider.autoDispose<ChatGroupeNotifier, ChatGroupeState>(
        (ref) {
  final employee = ref.watch(employeeCourantProvider);
  return ChatGroupeNotifier(
    repo: ref.watch(chatGroupeRepositoryProvider),
    ds: ref.watch(chatGroupeDatasourceProvider),
    currentUserId: employee?.id ?? '',
  );
});
