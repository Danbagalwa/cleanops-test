import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_groupe_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/epingle_banner.dart';
import '../widgets/message_options_bottom_sheet.dart';

// ── Largeur max du contenu chat (desktop centré) ──────────
const double _kMaxWidth = 860;

class ChatGroupeScreen extends ConsumerStatefulWidget {
  const ChatGroupeScreen({super.key});

  @override
  ConsumerState<ChatGroupeScreen> createState() => _ChatGroupeScreenState();
}

class _ChatGroupeScreenState extends ConsumerState<ChatGroupeScreen> {
  final _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      final n = ref.read(chatGroupeNotifierProvider.notifier);
      n.loadMessages();
      n.initRealtime();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    _autoScroll = pos.pixels < 80;
    // Scroll vers le haut (vieux messages) → pagination
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(chatGroupeNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatGroupeNotifierProvider);
    final employee = ref.watch(employeeCourantProvider);
    final isResponsable = employee?.isResponsable ?? false;
    final myId = employee?.id ?? '';

    // Auto-scroll vers le bas quand un nouveau message arrive
    ref.listen(chatGroupeNotifierProvider, (prev, next) {
      if (prev != null &&
          next.messages.length > prev.messages.length &&
          _autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFEFE7DC), // fond style WhatsApp
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.backOrHome(isResponsable
              ? AppRoutes.employerDashboard
              : AppRoutes.employeeDashboard),
        ),
        title: Row(
          children: [
            // Avatar du groupe
            Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat Équipe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Toute l\'équipe',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualiser',
            onPressed: () =>
                ref.read(chatGroupeNotifierProvider.notifier).loadMessages(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Bandeau épinglés (centré sur desktop) ──────────
          if (state.messagesEpingles.isNotEmpty)
            _Centered(
              child: EpingleBanner(epingles: state.messagesEpingles),
            ),

          // ── Bandeau erreur ─────────────────────────────────
          if (state.error != null)
            _Centered(
              child: _ErrorBanner(message: state.error!),
            ),

          // ── Liste des messages ─────────────────────────────
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.rouge))
                : state.messages.isEmpty
                    ? const _EmptyState()
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: _kMaxWidth),
                          child: ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            itemCount: state.messages.length +
                                (state.isLoadingMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              // Indicateur de chargement en haut de liste
                              if (i == state.messages.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.rouge,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final msg = state.messages[i];
                              // prevMsg = message plus ancien (index +1 en reverse)
                              final prevMsg =
                                  i < state.messages.length - 1
                                      ? state.messages[i + 1]
                                      : null;
                              // nextMsg = message plus récent (index -1 en reverse)
                              final nextMsg =
                                  i > 0 ? state.messages[i - 1] : null;

                              final isMine = msg.auteurId == myId;
                              final isStreakStart = prevMsg == null ||
                                  prevMsg.auteurId != msg.auteurId;
                              final isStreakEnd = nextMsg == null ||
                                  nextMsg.auteurId != msg.auteurId;

                              // Séparateur de date quand le jour change
                              final showDate = prevMsg != null &&
                                  !_sameDay(msg.dateEnvoi, prevMsg.dateEnvoi);

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showDate)
                                    _DateSeparator(date: msg.dateEnvoi),
                                  ChatBubble(
                                    message: msg,
                                    isMine: isMine,
                                    isStreakStart: isStreakStart,
                                    isStreakEnd: isStreakEnd,
                                    onLongPress: isResponsable
                                        ? () =>
                                            _showOptions(context, ref, msg)
                                        : null,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
          ),

          // ── Zone de saisie (centrée sur desktop) ──────────
          _Centered(
            child: ChatInputWidget(
              isSending: state.isSending,
              onEnvoyer: (texte) => ref
                  .read(chatGroupeNotifierProvider.notifier)
                  .envoyerMessage(texte),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref, ChatMessage msg) {
    showMessageOptions(
      context: context,
      message: msg,
      onEpingler: () =>
          ref.read(chatGroupeNotifierProvider.notifier).epinglerMessage(msg.id),
      onDesepingler: () => ref
          .read(chatGroupeNotifierProvider.notifier)
          .desepinglerMessage(msg.id),
      onSupprimer: () =>
          ref.read(chatGroupeNotifierProvider.notifier).supprimerMessage(msg.id),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Widget helper : contraint + centré ────────────────────
class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxWidth),
        child: child,
      ),
    );
  }
}

// ── Séparateur de date ─────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  static const _jours = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
    'Vendredi', 'Samedi', 'Dimanche',
  ];
  static const _mois = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  String get _label {
    final now = DateTime.now();
    if (_sameDay(date, now)) return 'Aujourd\'hui';
    final hier = now.subtract(const Duration(days: 1));
    if (_sameDay(date, hier)) return 'Hier';
    return '${_jours[date.weekday - 1]} ${date.day} ${_mois[date.month - 1]}';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.black.withValues(alpha: 0.12),
              endIndent: 10,
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFD1E7DD).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              _label,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF2D4A3E),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.black.withValues(alpha: 0.12),
              indent: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bannière d'erreur ──────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.rouge.withValues(alpha: 0.1),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.rouge),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.rouge),
            ),
          ),
        ],
      ),
    );
  }
}

// ── État vide ──────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: Color(0xFF90A4AE),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun message pour l\'instant',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF546E7A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Soyez le premier à écrire !',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
