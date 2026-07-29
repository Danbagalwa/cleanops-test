import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/entities/message_semaine.dart';
import '../providers/message_semaine_provider.dart'
    show getMessageAutomatique, messageSemaineNotifierProvider, messagesFete;

class MessagesSemaineScreen extends ConsumerStatefulWidget {
  const MessagesSemaineScreen({super.key});

  @override
  ConsumerState<MessagesSemaineScreen> createState() =>
      _MessagesSemaineScreenState();
}

class _MessagesSemaineScreenState extends ConsumerState<MessagesSemaineScreen> {
  final _searchController = TextEditingController();
  MessageType? _typeFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final notifier = ref.read(messageSemaineNotifierProvider.notifier);
    await Future.wait([
      notifier.loadMessageActif(),
      notifier.loadHistorique(),
    ]);
  }

  List<MessageSemaine> _filtered(List<MessageSemaine> messages) {
    final query = _searchController.text.trim().toLowerCase();
    return messages.where((message) {
      final matchesType = _typeFilter == null || message.type == _typeFilter;
      final matchesQuery = query.isEmpty ||
          message.contenu.toLowerCase().contains(query) ||
          (message.prenomCreePar?.toLowerCase().contains(query) ?? false);
      return matchesType && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messageSemaineNotifierProvider);
    final messages = _filtered(state.historique);
    final isDesktop = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        surfaceTintColor: AppColors.rouge,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.backOrHome(AppRoutes.employerDashboard),
        ),
        title: const Text(
          'Messages de la semaine',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: state.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton(
              tooltip: 'Créer un message',
              onPressed: state.isLoading ? null : _openCreation,
              backgroundColor: AppColors.rouge,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            ),
      body: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 16,
                24,
                isDesktop ? 32 : 16,
                100,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: state.isLoading && state.historique.isEmpty
                        ? const _PageSkeleton()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PageHeader(
                                total: state.historique.length,
                                isDesktop: isDesktop,
                                onCreate: _openCreation,
                              ),
                              if (state.error != null) ...[
                                const SizedBox(height: 16),
                                _ErrorBanner(onRetry: _refresh),
                              ],
                              const SizedBox(height: 24),
                              if (isDesktop)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: _ActiveSection(
                                        message: state.messageActif,
                                        loading: state.isLoading,
                                        onCreate: _openCreation,
                                        onDisable: _disable,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      flex: 6,
                                      child: _HistorySection(
                                        messages: messages,
                                        total: state.historique.length,
                                        controller: _searchController,
                                        selectedType: _typeFilter,
                                        onSearch: (_) => setState(() {}),
                                        onTypeChanged: (value) =>
                                            setState(() => _typeFilter = value),
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                _ActiveSection(
                                  message: state.messageActif,
                                  loading: state.isLoading,
                                  onCreate: _openCreation,
                                  onDisable: _disable,
                                ),
                                const SizedBox(height: 24),
                                _HistorySection(
                                  messages: messages,
                                  total: state.historique.length,
                                  controller: _searchController,
                                  selectedType: _typeFilter,
                                  onSearch: (_) => setState(() {}),
                                  onTypeChanged: (value) =>
                                      setState(() => _typeFilter = value),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _disable(MessageSemaine message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.visibility_off_outlined,
            color: Color(0xFFE65100),
          ),
        ),
        title: const Text('Masquer ce message ?'),
        content: const Text(
          'Il ne sera plus visible par l’équipe, mais restera disponible dans '
          'l’historique.',
          textAlign: TextAlign.center,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Garder le message'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Masquer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(messageSemaineNotifierProvider.notifier)
        .desactiverMessage(message.id);
    if (!mounted) return;
    _showFeedback(
      ok
          ? 'Le message a été retiré du tableau de bord.'
          : 'Le message n’a pas pu être masqué. Vous pouvez réessayer.',
      success: ok,
    );
  }

  Future<void> _openCreation() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreationSheet(
        onConfirm: (content, type) => ref
            .read(messageSemaineNotifierProvider.notifier)
            .creerMessage(content, type),
      ),
    );
    if (created == true && mounted) {
      _showFeedback('Le message est maintenant visible par toute l’équipe.');
    }
  }

  void _showFeedback(String message, {bool success = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              success ? const Color(0xFF176B3A) : const Color(0xFF9F2D2D),
          content: Row(
            children: [
              Icon(
                success
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.total,
    required this.isDesktop,
    required this.onCreate,
  });

  final int total;
  final bool isDesktop;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.rouge, AppColors.rougeLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.rouge.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informez toute l’équipe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total message${total > 1 ? 's' : ''} publié'
                  '${total > 1 ? 's' : ''} au total',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .78),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop)
            FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.rouge,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Nouveau message',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveSection extends StatelessWidget {
  const _ActiveSection({
    required this.message,
    required this.loading,
    required this.onCreate,
    required this.onDisable,
  });

  final MessageSemaine? message;
  final bool loading;
  final VoidCallback onCreate;
  final ValueChanged<MessageSemaine> onDisable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          title: 'Visible actuellement',
          subtitle: 'Ce que l’équipe voit sur son tableau de bord',
          icon: Icons.visibility_outlined,
        ),
        const SizedBox(height: 12),
        if (message == null)
          _EmptyActiveCard(onCreate: onCreate)
        else
          _ActiveMessageCard(
            message: message!,
            loading: loading,
            onDisable: () => onDisable(message!),
          ),
      ],
    );
  }
}

class _ActiveMessageCard extends StatelessWidget {
  const _ActiveMessageCard({
    required this.message,
    required this.loading,
    required this.onDisable,
  });

  final MessageSemaine message;
  final bool loading;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E9F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TypeBadge(type: message.type),
              const Spacer(),
              const _StatusBadge(active: true),
            ],
          ),
          const SizedBox(height: 20),
          const Icon(
            Icons.format_quote_rounded,
            color: AppColors.rougeLight,
            size: 30,
          ),
          const SizedBox(height: 6),
          SelectableText(
            message.contenu,
            style: const TextStyle(
              color: AppColors.noir,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFEDEDFC),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: AppColors.rouge,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${message.prenomCreePar ?? 'Responsable'} • '
                  '${_formatDate(message.dateCreation)}',
                  style: const TextStyle(
                    color: AppColors.grisDark,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading ? null : onDisable,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE65100),
                side: const BorderSide(color: Color(0xFFFFCC9B)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.visibility_off_outlined, size: 18),
              label: const Text(
                'Retirer du tableau de bord',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: .04, end: 0);
  }
}

class _EmptyActiveCard extends StatelessWidget {
  const _EmptyActiveCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E9F2)),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFEDEDFC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.rouge,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun message visible',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Publiez une information, un encouragement ou un rappel pour '
            'toute l’équipe.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisDark, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Créer un message'),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.messages,
    required this.total,
    required this.controller,
    required this.selectedType,
    required this.onSearch,
    required this.onTypeChanged,
  });

  final List<MessageSemaine> messages;
  final int total;
  final TextEditingController controller;
  final MessageType? selectedType;
  final ValueChanged<String> onSearch;
  final ValueChanged<MessageType?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: 'Historique',
          subtitle: '$total publication${total > 1 ? 's' : ''}',
          icon: Icons.history_rounded,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE7E9F2)),
          ),
          child: Column(
            children: [
              TextField(
                controller: controller,
                onChanged: onSearch,
                decoration: InputDecoration(
                  hintText: 'Rechercher dans les messages…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          onPressed: () {
                            controller.clear();
                            onSearch('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Tous',
                      selected: selectedType == null,
                      onTap: () => onTypeChanged(null),
                    ),
                    for (final type in MessageType.values) ...[
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: _typeLabel(type),
                        selected: selectedType == type,
                        onTap: () => onTypeChanged(type),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (messages.isEmpty)
                const _EmptyHistory()
              else
                ...messages.asMap().entries.map(
                      (entry) => _HistoryItem(message: entry.value)
                          .animate(delay: (entry.key * 35).ms)
                          .fadeIn(duration: 250.ms),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.message});

  final MessageSemaine message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _typeColor(message.type).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _typeIcon(message.type),
              color: _typeColor(message.type),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.contenu,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.noir,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${message.prenomCreePar ?? 'Responsable'} • '
                  '${_formatDate(message.dateCreation)}',
                  style: const TextStyle(
                    color: AppColors.grisText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(active: message.isActif),
        ],
      ),
    );
  }
}

class _CreationSheet extends StatefulWidget {
  const _CreationSheet({required this.onConfirm});

  final Future<bool> Function(String content, MessageType type) onConfirm;

  @override
  State<_CreationSheet> createState() => _CreationSheetState();
}

class _CreationSheetState extends State<_CreationSheet> {
  final _controller = TextEditingController();
  MessageType _type = MessageType.personnalise;
  String? _selectedHoliday;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => switch (_type) {
        MessageType.personnalise => _controller.text.trim().isNotEmpty,
        MessageType.automatique => true,
        MessageType.fete => _selectedHoliday != null,
      };

  String get _content => switch (_type) {
        MessageType.personnalise => _controller.text.trim(),
        MessageType.automatique => getMessageAutomatique(),
        MessageType.fete => _selectedHoliday ?? '',
      };

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;
    setState(() => _loading = true);
    final ok = await widget.onConfirm(_content, _type);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'La publication n’a pas abouti. Vérifiez votre connexion et '
            'réessayez.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Align(
        alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(24),
            bottom: Radius.circular(isDesktop ? 24 : 0),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: MediaQuery.sizeOf(context).height * .9,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7D9E0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEDFC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.campaign_outlined,
                          color: AppColors.rouge,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nouveau message',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Visible immédiatement par toute l’équipe',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.grisDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed:
                            _loading ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Quel type de message souhaitez-vous publier ?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<MessageType>(
                    segments: const [
                      ButtonSegment(
                        value: MessageType.personnalise,
                        icon: Icon(Icons.edit_outlined),
                        label: Text('Libre'),
                      ),
                      ButtonSegment(
                        value: MessageType.automatique,
                        icon: Icon(Icons.auto_awesome_outlined),
                        label: Text('Suggéré'),
                      ),
                      ButtonSegment(
                        value: MessageType.fete,
                        icon: Icon(Icons.celebration_outlined),
                        label: Text('Fête'),
                      ),
                    ],
                    selected: {_type},
                    showSelectedIcon: false,
                    onSelectionChanged: _loading
                        ? null
                        : (selection) => setState(() {
                              _type = selection.first;
                              _selectedHoliday = null;
                              _controller.clear();
                            }),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: switch (_type) {
                      MessageType.personnalise => TextField(
                          key: const ValueKey('custom'),
                          controller: _controller,
                          enabled: !_loading,
                          autofocus: true,
                          minLines: 4,
                          maxLines: 6,
                          maxLength: 280,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Votre message',
                            hintText:
                                'Ex. Merci à toute l’équipe pour votre travail…',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: const Color(0xFFF7F8FC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.rouge,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      MessageType.automatique => _MessagePreview(
                          key: const ValueKey('auto'),
                          content: getMessageAutomatique(),
                        ),
                      MessageType.fete => _HolidayPicker(
                          key: const ValueKey('holiday'),
                          selected: _selectedHoliday,
                          onSelected: (value) =>
                              setState(() => _selectedHoliday = value),
                        ),
                    },
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _loading ? null : () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _canSubmit && !_loading ? _submit : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.rouge,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          icon: _loading
                              ? const SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _loading ? 'Publication…' : 'Publier le message',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HolidayPicker extends StatelessWidget {
  const _HolidayPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choisissez un message prêt à publier',
          style: TextStyle(fontSize: 13, color: AppColors.grisDark),
        ),
        const SizedBox(height: 10),
        for (final message in messagesFete)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelected(message),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: selected == message
                      ? AppColors.rouge.withValues(alpha: .07)
                      : const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected == message
                        ? AppColors.rouge
                        : const Color(0xFFE7E9F2),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(message)),
                    if (selected == message)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.rouge,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MessagePreview extends StatelessWidget {
  const _MessagePreview({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6D5FA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.rouge),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suggestion du jour',
                  style: TextStyle(
                    color: AppColors.rouge,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  content,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.rouge),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.grisDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.rouge.withValues(alpha: .1),
      side: BorderSide(
        color: selected ? AppColors.rouge : const Color(0xFFE7E9F2),
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.rouge : AppColors.grisDark,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      showCheckmark: false,
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final MessageType type;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_typeIcon(type), size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            _typeLabel(type),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF176B3A) : const Color(0xFF667085);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Actif' : 'Archivé',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: AppColors.grisMedium, size: 36),
          SizedBox(height: 10),
          Text(
            'Aucun message ne correspond à votre recherche.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisDark, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFC2410C)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Nous n’avons pas pu actualiser les messages. Vos données '
              'restent en sécurité.',
              style: TextStyle(
                color: Color(0xFF9A3412),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _PageSkeleton extends StatelessWidget {
  const _PageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SkeletonBox(height: 130, radius: 24),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _SkeletonBox(height: 330, radius: 20)),
                  SizedBox(width: 24),
                  Expanded(child: _SkeletonBox(height: 430, radius: 20)),
                ],
              );
            }
            return const Column(
              children: [
                _SkeletonBox(height: 330, radius: 20),
                SizedBox(height: 24),
                _SkeletonBox(height: 430, radius: 20),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EAF0),
        borderRadius: BorderRadius.circular(radius),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fade(begin: .45, end: .9, duration: 800.ms);
  }
}

Color _typeColor(MessageType type) => switch (type) {
      MessageType.personnalise => AppColors.rouge,
      MessageType.automatique => const Color(0xFF1769AA),
      MessageType.fete => const Color(0xFFB54708),
    };

IconData _typeIcon(MessageType type) => switch (type) {
      MessageType.personnalise => Icons.chat_bubble_outline_rounded,
      MessageType.automatique => Icons.auto_awesome_outlined,
      MessageType.fete => Icons.celebration_outlined,
    };

String _typeLabel(MessageType type) => switch (type) {
      MessageType.personnalise => 'Personnalisé',
      MessageType.automatique => 'Suggéré',
      MessageType.fete => 'Fête',
    };

String _formatDate(DateTime date) {
  final difference = DateTime.now().difference(date);
  if (!difference.isNegative && difference.inMinutes < 1) {
    return 'À l’instant';
  }
  if (!difference.isNegative && difference.inHours < 1) {
    return 'Il y a ${difference.inMinutes} min';
  }
  if (!difference.isNegative && difference.inDays < 1) {
    return 'Il y a ${difference.inHours} h';
  }
  if (!difference.isNegative && difference.inDays < 7) {
    return 'Il y a ${difference.inDays} j';
  }
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
