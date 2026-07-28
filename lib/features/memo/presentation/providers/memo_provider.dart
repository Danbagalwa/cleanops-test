import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/memo_datasource.dart';
import '../../data/models/memo_model.dart';
import '../../data/repositories/memo_repository_impl.dart';
import '../../domain/entities/memo.dart';
import '../../domain/repositories/memo_repository.dart';

// ── Infrastructure ────────────────────────────────────────
final memoDatasourceProvider = Provider<MemoDatasource>(
  (_) => MemoDatasourceImpl(),
);

final memoRepositoryProvider = Provider<MemoRepository>((ref) {
  return MemoRepositoryImpl(ref.watch(memoDatasourceProvider));
});

// ══════════════════════════════════════════════════════════
// Liste préposées (Vue responsable)
// ══════════════════════════════════════════════════════════

class MemoListState {
  final List<PreposeeResume> preposees;
  final bool isLoading;
  final String? error;

  const MemoListState({
    this.preposees = const [],
    this.isLoading = false,
    this.error,
  });

  MemoListState copyWith({
    List<PreposeeResume>? preposees,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MemoListState(
      preposees: preposees ?? this.preposees,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class MemoListNotifier extends StateNotifier<MemoListState> {
  final MemoRepository _repo;
  MemoListNotifier(this._repo) : super(const MemoListState()) {
    charger();
  }

  Future<void> charger() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getPreposeeesAvecDernierMemo();
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (list) => state = state.copyWith(isLoading: false, preposees: list),
    );
  }
}

final memoListNotifierProvider =
    StateNotifierProvider.autoDispose<MemoListNotifier, MemoListState>((ref) {
  return MemoListNotifier(ref.watch(memoRepositoryProvider));
});

// ══════════════════════════════════════════════════════════
// Conversation (Vue préposée ↔ responsable)
// ══════════════════════════════════════════════════════════

class MemoConversationState {
  final List<Memo> memos;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const MemoConversationState({
    this.memos = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  MemoConversationState copyWith({
    List<Memo>? memos,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) {
    return MemoConversationState(
      memos: memos ?? this.memos,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class MemoConversationNotifier
    extends StateNotifier<MemoConversationState> {
  final MemoRepository _repo;
  final MemoDatasource _ds;
  final String _preposeeId;
  final String _currentEmployeeId;
  final AuteurType _auteurCourant;
  RealtimeChannel? _channel;

  MemoConversationNotifier({
    required MemoRepository repo,
    required MemoDatasource ds,
    required String preposeeId,
    required String currentEmployeeId,
    required AuteurType auteurCourant,
  })  : _repo = repo,
        _ds = ds,
        _preposeeId = preposeeId,
        _currentEmployeeId = currentEmployeeId,
        _auteurCourant = auteurCourant,
        super(const MemoConversationState()) {
    _init();
  }

  Future<void> _init() async {
    await chargerConversation();
    _channel = _ds.subscriberConversation(_preposeeId, _ajouterMemoParId);
  }

  Future<void> _ajouterMemoParId(String memoId) async {
    try {
      final MemoModel memo = await _ds.getMemoById(memoId);
      if (state.memos.any((m) => m.id == memo.id)) return;
      state = state.copyWith(memos: [...state.memos, memo]);
      _repo.marquerCommeLu(_preposeeId, _auteurCourant);
    } catch (_) {
      chargerConversation();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> chargerConversation() async {
    state = state.copyWith(
        isLoading: state.memos.isEmpty, clearError: true);
    final result = await _repo.getConversation(_preposeeId);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (memos) {
        state = state.copyWith(isLoading: false, memos: memos);
        _repo.marquerCommeLu(_preposeeId, _auteurCourant);
      },
    );
  }

  Future<bool> envoyerMemo(String message) async {
    if (message.trim().isEmpty) return false;
    state = state.copyWith(isSending: true, clearError: true);
    final result = await _repo.envoyerMemo(
      preposeeId: _preposeeId,
      auteurId: _currentEmployeeId,
      auteur: _auteurCourant,
      message: message.trim(),
    );
    return result.fold(
      (f) {
        state = state.copyWith(isSending: false, error: f.message);
        return false;
      },
      (memo) {
        // Évite les doublons si le Realtime a déjà ajouté le message
        final updated = [...state.memos];
        if (!updated.any((m) => m.id == memo.id)) {
          updated.add(memo);
        }
        state = state.copyWith(isSending: false, memos: updated);
        return true;
      },
    );
  }
}

final memoConversationNotifierProvider = StateNotifierProvider.autoDispose
    .family<MemoConversationNotifier, MemoConversationState, String>(
        (ref, preposeeId) {
  final employee = ref.watch(employeeCourantProvider);
  final auteurCourant =
      (employee?.isResponsable ?? false) ? AuteurType.employeur : AuteurType.employe;
  return MemoConversationNotifier(
    repo: ref.watch(memoRepositoryProvider),
    ds: ref.watch(memoDatasourceProvider),
    preposeeId: preposeeId,
    currentEmployeeId: employee?.id ?? '',
    auteurCourant: auteurCourant,
  );
});
