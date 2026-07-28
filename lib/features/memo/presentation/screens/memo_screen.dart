import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/memo.dart';
import '../providers/memo_provider.dart';

// ── Helpers ────────────────────────────────────────────────

const _kAvatarPalette = [
  Color(0xFF1A7A3C), Color(0xFF1A4A7A), Color(0xFF7B1FA2),
  Color(0xFF00897B), Color(0xFFE65100), Color(0xFFC62828),
  Color(0xFF283593), Color(0xFF558B2F),
];

Color _avatarColor(String prenom) {
  if (prenom.isEmpty) return _kAvatarPalette[0];
  return _kAvatarPalette[prenom.codeUnitAt(0) % _kAvatarPalette.length];
}

String _tempsConversation(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dtDay = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(dtDay).inDays;
  if (diff == 0) return DateHelper.formatHeure(dt);
  if (diff < 7) return DateFormat('E', 'fr_FR').format(dt);
  return DateFormat('dd/MM', 'fr_FR').format(dt);
}

String _titreConversation(List<Memo> memos, bool isResponsable) {
  if (memos.isEmpty) return 'Conversation';
  if (isResponsable) {
    for (final m in memos) {
      if (m.estDeEmploye && m.auteurPrenom != null) return m.auteurPrenom!;
    }
    return memos.first.auteurPrenom ?? 'Préposée';
  }
  return 'Responsable';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ══════════════════════════════════════════════════════════
// SCREEN ROOT
// ══════════════════════════════════════════════════════════

class MemoScreen extends ConsumerStatefulWidget {
  final String? employeeId;
  final String? date;
  const MemoScreen({super.key, this.employeeId, this.date});

  @override
  ConsumerState<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends ConsumerState<MemoScreen> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.employeeId;
  }

  @override
  void didUpdateWidget(MemoScreen old) {
    super.didUpdateWidget(old);
    if (widget.employeeId != old.employeeId) {
      setState(() => _selectedId = widget.employeeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(employeeCourantProvider);
    final isResponsable = employee?.isResponsable ?? false;
    final isWide = MediaQuery.of(context).size.width >= 700;

    // Préposée: toujours sa propre conversation, sans liste
    if (!isResponsable) {
      final myId = employee?.id ?? widget.employeeId ?? '';
      return _ConversationScaffold(
        preposeeId: myId,
        isResponsable: false,
        showBack: true,
        onBack: () => context.backOrHome(AppRoutes.employeeDashboard),
      );
    }

    // Responsable: 2 colonnes sur desktop, pile sur mobile
    if (isWide) {
      return _SplitLayout(
        selectedId: _selectedId,
        onSelect: (id) => setState(() => _selectedId = id),
      );
    }

    // Mobile: PopScope pour le bouton retour Android
    return PopScope(
      canPop: _selectedId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selectedId = null);
      },
      child: _selectedId != null
          ? _ConversationScaffold(
              key: ValueKey(_selectedId),
              preposeeId: _selectedId!,
              isResponsable: true,
              showBack: true,
              onBack: () => setState(() => _selectedId = null),
            )
          : _ListeScaffold(
              onSelect: (id) => setState(() => _selectedId = id),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// SPLIT LAYOUT – desktop ≥ 700 px
// ══════════════════════════════════════════════════════════

class _SplitLayout extends StatelessWidget {
  final String? selectedId;
  final void Function(String) onSelect;
  const _SplitLayout({required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Colonne gauche: liste
          SizedBox(
            width: 340,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    right: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              child: _ListePanel(selectedId: selectedId, onSelect: onSelect),
            ),
          ),

          // Colonne droite: conversation
          Expanded(
            child: selectedId == null
                ? const _EmptyConversation()
                : _ConversationPanel(
                    key: ValueKey(selectedId),
                    preposeeId: selectedId!,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Panneau gauche ─────────────────────────────────────────

class _ListePanel extends ConsumerWidget {
  final String? selectedId;
  final void Function(String) onSelect;
  const _ListePanel({required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.of(context).padding.top;
    final state = ref.watch(memoListNotifierProvider);

    return Column(
      children: [
        // Header rouge
        Container(
          color: AppColors.rouge,
          padding: EdgeInsets.fromLTRB(
              AppSizes.md, topPad + 12, AppSizes.xs, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text('Messages',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3)),
              ),
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
        ),

        // Contenu
        Expanded(child: _buildContent(context, ref, state)),
      ],
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, MemoListState state) {
    if (state.isLoading && state.preposees.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.rouge));
    }
    if (state.error != null) {
      return _ErrorView(
          message: state.error!,
          onRetry: () =>
              ref.read(memoListNotifierProvider.notifier).charger());
    }
    if (state.preposees.isEmpty) {
      return const _PlaceholderView(
          icon: Icons.forum_outlined,
          titre: 'Aucune préposée',
          sousTitre: 'Les préposées actives\napparaîtront ici.');
    }

    final totalNonLus =
        state.preposees.fold(0, (s, p) => s + p.nonLusCount);

    return Column(
      children: [
        if (totalNonLus > 0) _NonLusBanner(count: totalNonLus),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.rouge,
            onRefresh: () =>
                ref.read(memoListNotifierProvider.notifier).charger(),
            child: ListView.separated(
              itemCount: state.preposees.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1, indent: 80, color: Color(0xFFF0F0F0)),
              itemBuilder: (_, i) {
                final r = state.preposees[i];
                return _ConversationTile(
                  resume: r,
                  isSelected: selectedId == r.employeeId,
                  onTap: () => onSelect(r.employeeId),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Panneau droit: conversation (sans Scaffold) ────────────

class _ConversationPanel extends ConsumerStatefulWidget {
  final String preposeeId;
  const _ConversationPanel({super.key, required this.preposeeId});

  @override
  ConsumerState<_ConversationPanel> createState() =>
      _ConversationPanelState();
}

class _ConversationPanelState extends ConsumerState<_ConversationPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final state =
        ref.watch(memoConversationNotifierProvider(widget.preposeeId));

    if (state.memos.length != _lastCount) {
      final wasEmpty = _lastCount == 0;
      _lastCount = state.memos.length;
      _scrollToBottom(instant: wasEmpty);
    }

    final titre = _titreConversation(state.memos, true);

    return ColoredBox(
      color: const Color(0xFFF2F2F7),
      child: Column(
        children: [
          _PanelHeader(
            topPad: topPad,
            titre: titre,
            onRefresh: () => ref
                .read(memoConversationNotifierProvider(widget.preposeeId)
                    .notifier)
                .chargerConversation(),
          ),
          Expanded(child: _buildMessages(state)),
          if (state.error != null) _ErreurBandeau(message: state.error!),
          _InputBar(
            controller: _controller,
            isSending: state.isSending,
            onSend: _envoyer,
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(MemoConversationState state) {
    if (state.isLoading && state.memos.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.rouge));
    }
    if (state.memos.isEmpty) {
      return const _PlaceholderView(
          icon: Icons.chat_bubble_outline_rounded,
          titre: 'Pas encore de message',
          sousTitre: 'Envoyez le premier !');
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: AppSizes.md),
      itemCount: state.memos.length,
      itemBuilder: (_, i) {
        final memo = state.memos[i];
        final isMine = memo.estDeEmployeur;
        final showDate =
            i == 0 || !_sameDay(state.memos[i - 1].dateEnvoi, memo.dateEnvoi);
        return Column(children: [
          if (showDate) _DateSeparateur(date: memo.dateEnvoi),
          _Bulle(memo: memo, isMine: isMine),
        ]);
      },
    );
  }

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (instant) {
        _scrollController.jumpTo(max);
      } else {
        _scrollController.animateTo(max,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _envoyer() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty) return;
    _controller.clear();
    await ref
        .read(memoConversationNotifierProvider(widget.preposeeId).notifier)
        .envoyerMemo(msg);
    _scrollToBottom();
  }
}

// ── Header panneau droit (split) ──────────────────────────

class _PanelHeader extends StatelessWidget {
  final double topPad;
  final String titre;
  final VoidCallback onRefresh;
  const _PanelHeader(
      {required this.topPad, required this.titre, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final initiale = titre.isNotEmpty ? titre[0].toUpperCase() : '?';
    final couleur = _avatarColor(titre);
    return Container(
      color: AppColors.rouge,
      padding: EdgeInsets.fromLTRB(AppSizes.md, topPad + 12, AppSizes.xs, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: couleur,
            child: Text(initiale,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const Text('Conversation privée',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// MOBILE SCAFFOLDS
// ══════════════════════════════════════════════════════════

class _ListeScaffold extends ConsumerWidget {
  final void Function(String) onSelect;
  const _ListeScaffold({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memoListNotifierProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.backOrHome(AppRoutes.employerDashboard),
        ),
        title: const Text('Messages',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, MemoListState state) {
    if (state.isLoading && state.preposees.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.rouge));
    }
    if (state.error != null && state.preposees.isEmpty) {
      return _ErrorView(
          message: state.error!,
          onRetry: () =>
              ref.read(memoListNotifierProvider.notifier).charger());
    }
    if (state.preposees.isEmpty) {
      return const _PlaceholderView(
          icon: Icons.forum_outlined,
          titre: 'Aucune préposée',
          sousTitre: 'Les préposées actives apparaîtront ici.');
    }

    final totalNonLus =
        state.preposees.fold(0, (s, p) => s + p.nonLusCount);

    return Column(
      children: [
        if (totalNonLus > 0) _NonLusBanner(count: totalNonLus),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.rouge,
            onRefresh: () =>
                ref.read(memoListNotifierProvider.notifier).charger(),
            child: ListView.separated(
              itemCount: state.preposees.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1, indent: 80, color: Color(0xFFF0F0F0)),
              itemBuilder: (_, i) {
                final r = state.preposees[i];
                return _ConversationTile(
                  resume: r,
                  isSelected: false,
                  onTap: () => onSelect(r.employeeId),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ConversationScaffold extends ConsumerStatefulWidget {
  final String preposeeId;
  final bool isResponsable;
  final bool showBack;
  final VoidCallback? onBack;
  const _ConversationScaffold({
    super.key,
    required this.preposeeId,
    required this.isResponsable,
    required this.showBack,
    this.onBack,
  });

  @override
  ConsumerState<_ConversationScaffold> createState() =>
      _ConversationScaffoldState();
}

class _ConversationScaffoldState
    extends ConsumerState<_ConversationScaffold> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(memoConversationNotifierProvider(widget.preposeeId));

    if (state.memos.length != _lastCount) {
      final wasEmpty = _lastCount == 0;
      _lastCount = state.memos.length;
      _scrollToBottom(instant: wasEmpty);
    }

    final titre = _titreConversation(state.memos, widget.isResponsable);
    final initiale = titre.isNotEmpty ? titre[0].toUpperCase() : '?';
    final couleur = _avatarColor(titre);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leading: widget.showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: widget.onBack,
              )
            : null,
        title: Padding(
          padding:
              EdgeInsets.only(left: widget.showBack ? 0 : AppSizes.sm),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: couleur,
                child: Text(initiale,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const Text('Conversation privée',
                      style:
                          TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref
                .read(memoConversationNotifierProvider(widget.preposeeId)
                    .notifier)
                .chargerConversation(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(state)),
          if (state.error != null) _ErreurBandeau(message: state.error!),
          _InputBar(
            controller: _controller,
            isSending: state.isSending,
            onSend: _envoyer,
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(MemoConversationState state) {
    if (state.isLoading && state.memos.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.rouge));
    }
    if (state.memos.isEmpty) {
      return const _PlaceholderView(
          icon: Icons.chat_bubble_outline_rounded,
          titre: 'Pas encore de message',
          sousTitre: 'Envoyez le premier !');
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: AppSizes.md),
      itemCount: state.memos.length,
      itemBuilder: (_, i) {
        final memo = state.memos[i];
        final isMine = widget.isResponsable
            ? memo.estDeEmployeur
            : memo.estDeEmploye;
        final showDate =
            i == 0 || !_sameDay(state.memos[i - 1].dateEnvoi, memo.dateEnvoi);
        return Column(children: [
          if (showDate) _DateSeparateur(date: memo.dateEnvoi),
          _Bulle(memo: memo, isMine: isMine),
        ]);
      },
    );
  }

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (instant) {
        _scrollController.jumpTo(max);
      } else {
        _scrollController.animateTo(max,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _envoyer() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty) return;
    _controller.clear();
    await ref
        .read(memoConversationNotifierProvider(widget.preposeeId).notifier)
        .envoyerMemo(msg);
    _scrollToBottom();
  }
}

// ══════════════════════════════════════════════════════════
// COMPOSANTS PARTAGÉS
// ══════════════════════════════════════════════════════════

class _NonLusBanner extends StatelessWidget {
  final int count;
  const _NonLusBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.rouge.withValues(alpha: 0.06),
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.mark_chat_unread_outlined,
              size: 16, color: AppColors.rouge),
          const SizedBox(width: 6),
          Text(
            '$count message${count > 1 ? 's' : ''} non lu${count > 1 ? 's' : ''}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.rouge),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final PreposeeResume resume;
  final bool isSelected;
  final VoidCallback onTap;
  const _ConversationTile(
      {required this.resume, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initiale =
        resume.prenom.isNotEmpty ? resume.prenom[0].toUpperCase() : '?';
    final couleur = _avatarColor(resume.prenom);
    final hasUnread = resume.nonLusCount > 0;
    final tempsStr = _tempsConversation(resume.dernierEnvoi);

    return Material(
      color: isSelected
          ? AppColors.rouge.withValues(alpha: 0.07)
          : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: couleur,
                child: Text(initiale,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(resume.prenom,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: AppColors.noir)),
                        ),
                        if (tempsStr.isNotEmpty)
                          Text(tempsStr,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: hasUnread
                                      ? AppColors.rouge
                                      : AppColors.grisText,
                                  fontWeight: hasUnread
                                      ? FontWeight.w600
                                      : FontWeight.normal)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            resume.dernierMessage ??
                                'Commencer une conversation',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                color: hasUnread
                                    ? AppColors.noir
                                    : AppColors.grisText,
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.normal),
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            constraints:
                                const BoxConstraints(minWidth: 20),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.rouge,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${resume.nonLusCount}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F2F7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 40, color: AppColors.rouge),
            ),
            const SizedBox(height: AppSizes.lg),
            const Text('Sélectionnez une conversation',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grisDark)),
            const SizedBox(height: 6),
            const Text('pour envoyer des messages privés',
                style: TextStyle(fontSize: 14, color: AppColors.grisText)),
          ],
        ),
      ),
    );
  }
}

class _DateSeparateur extends StatelessWidget {
  final DateTime date;
  const _DateSeparateur({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dtDay = DateTime(date.year, date.month, date.day);
    final String label;
    if (dtDay == today) {
      label = "Aujourd'hui";
    } else if (today.difference(dtDay).inDays == 1) {
      label = 'Hier';
    } else {
      label = DateHelper.formatDate(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.grisDark,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

class _Bulle extends StatelessWidget {
  final Memo memo;
  final bool isMine;
  const _Bulle({required this.memo, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.72;

    return Padding(
      padding: EdgeInsets.only(
          bottom: 3, left: isMine ? 64 : 0, right: isMine ? 0 : 64),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: isMine ? AppColors.rouge : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 4,
                  offset: const Offset(0, 1)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nom expéditeur (messages reçus uniquement)
              if (!isMine && memo.auteurPrenom != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    memo.auteurPrenom!,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _avatarColor(memo.auteurPrenom!)),
                  ),
                ),

              // Texte + méta sur la même ligne
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      memo.message,
                      style: TextStyle(
                          fontSize: 14.5,
                          color: isMine ? Colors.white : AppColors.noir,
                          height: 1.35),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateHelper.formatHeure(memo.dateEnvoi),
                        style: TextStyle(
                            fontSize: 10,
                            color: isMine
                                ? Colors.white60
                                : AppColors.grisText),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 3),
                        Icon(
                          memo.isLu
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 13,
                          color: memo.isLu
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.white54,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  const _InputBar(
      {required this.controller,
      required this.isSending,
      required this.onSend});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onTextChange() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(
                color: Colors.black.withValues(alpha: 0.07), width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(
          AppSizes.sm, AppSizes.sm, AppSizes.sm, AppSizes.sm + bottomPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: widget.controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  hintStyle: TextStyle(color: AppColors.grisText),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) {
                  if (_hasText) widget.onSend();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedScale(
            scale: _hasText ? 1.0 : 0.85,
            duration: const Duration(milliseconds: 150),
            child: AnimatedOpacity(
              opacity: _hasText ? 1.0 : 0.35,
              duration: const Duration(milliseconds: 150),
              child: GestureDetector(
                onTap: (_hasText && !widget.isSending) ? widget.onSend : null,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                      color: AppColors.rouge, shape: BoxShape.circle),
                  child: widget.isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErreurBandeau extends StatelessWidget {
  final String message;
  const _ErreurBandeau({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 6),
      color: AppColors.rouge.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.rouge),
          const SizedBox(width: 6),
          Expanded(
              child: Text(message,
                  style: const TextStyle(fontSize: 12, color: AppColors.rouge))),
        ],
      ),
    );
  }
}

class _PlaceholderView extends StatelessWidget {
  final IconData icon;
  final String titre;
  final String sousTitre;
  const _PlaceholderView(
      {required this.icon, required this.titre, required this.sousTitre});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: AppColors.grisMedium),
          const SizedBox(height: AppSizes.md),
          Text(titre,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grisDark)),
          const SizedBox(height: 4),
          Text(sousTitre,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.grisText)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.grisText),
            const SizedBox(height: AppSizes.md),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.grisDark)),
            const SizedBox(height: AppSizes.lg),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.rouge),
              label: const Text('Réessayer',
                  style: TextStyle(color: AppColors.rouge)),
            ),
          ],
        ),
      ),
    );
  }
}
