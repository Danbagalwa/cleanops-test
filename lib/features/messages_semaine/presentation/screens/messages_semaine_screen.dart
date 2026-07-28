import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/entities/message_semaine.dart';
import '../providers/message_semaine_provider.dart'
    show
        messageSemaineNotifierProvider,
        getMessageAutomatique,
        messagesFete;

class MessagesSemaineScreen extends ConsumerStatefulWidget {
  const MessagesSemaineScreen({super.key});

  @override
  ConsumerState<MessagesSemaineScreen> createState() =>
      _MessagesSemaineScreenState();
}

class _MessagesSemaineScreenState
    extends ConsumerState<MessagesSemaineScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final n = ref.read(messageSemaineNotifierProvider.notifier);
      n.loadMessageActif();
      n.loadHistorique();
    });
  }

  Future<void> _rafraichir() async {
    final n = ref.read(messageSemaineNotifierProvider.notifier);
    await Future.wait([n.loadMessageActif(), n.loadHistorique()]);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messageSemaineNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.backOrHome(AppRoutes.employerDashboard),
        ),
        title: const Text(
          'Messages de la semaine',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirCreation(context),
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nouveau message',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _rafraichir,
        child: state.isLoading && state.historique.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.rouge))
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.md, AppSizes.md, AppSizes.md, 100),
                children: [
                  // ── Message actif ──────────────────────────
                  const _SectionLabel(label: 'Message actif'),
                  const SizedBox(height: AppSizes.sm),
                  state.messageActif != null
                      ? _MessageActifCard(
                          message: state.messageActif!,
                          isLoading: state.isLoading,
                          onDesactiver: () => _desactiver(
                              context, state.messageActif!.id),
                        )
                      : _AucunMessageCard(
                          onCreer: () => _ouvrirCreation(context)),

                  if (state.error != null) ...[
                    const SizedBox(height: AppSizes.md),
                    _ErreurBaniere(message: state.error!),
                  ],

                  const SizedBox(height: AppSizes.xl),

                  // ── Historique ─────────────────────────────
                  const _SectionLabel(label: 'Historique'),
                  const SizedBox(height: AppSizes.sm),

                  if (state.historique.isEmpty && !state.isLoading)
                    const _HistoriqueVide()
                  else
                    ...state.historique.asMap().entries.map(
                          (e) => _HistoriqueItem(
                            message: e.value,
                          )
                              .animate(
                                  delay: Duration(
                                      milliseconds: e.key * 50))
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.08, end: 0),
                        ),
                ],
              ),
      ),
    );
  }

  Future<void> _desactiver(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
        title: const Text('Désactiver ce message ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Le message ne sera plus visible sur le tableau de bord de l\'équipe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref
          .read(messageSemaineNotifierProvider.notifier)
          .desactiverMessage(id);
    }
  }

  void _ouvrirCreation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreationSheet(
        onConfirmer: (contenu, type) async {
          Navigator.pop(context);
          await ref
              .read(messageSemaineNotifierProvider.notifier)
              .creerMessage(contenu, type);
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// CARTE — message actif
// ══════════════════════════════════════════════════════════

class _MessageActifCard extends StatelessWidget {
  final MessageSemaine message;
  final bool isLoading;
  final VoidCallback onDesactiver;

  const _MessageActifCard({
    required this.message,
    required this.isLoading,
    required this.onDesactiver,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.rouge, AppColors.rougeFonce],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.rouge.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge type + label actif
            Row(
              children: [
                _TypeBadge(type: message.type),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 7, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        'Actif',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),

            // Contenu
            Text(
              message.contenu,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSizes.sm),

            // Auteur + date
            Text(
              [
                if (message.prenomCreePar != null)
                  'Par ${message.prenomCreePar}',
                _formatDate(message.dateCreation),
              ].join(' · '),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                ),
              ),

            const SizedBox(height: AppSizes.md),

            // Bouton désactiver
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onDesactiver,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                icon: const Icon(Icons.stop_circle_outlined, size: 17),
                label: const Text(
                  'Désactiver ce message',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.06, end: 0, curve: Curves.easeOut);
  }
}

// ── Aucun message actif ────────────────────────────────────

class _AucunMessageCard extends StatelessWidget {
  final VoidCallback onCreer;
  const _AucunMessageCard({required this.onCreer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
            color: const Color(0xFFEEEEEE), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          const Icon(Icons.campaign_outlined,
              size: 42, color: AppColors.grisMedium),
          const SizedBox(height: AppSizes.sm),
          const Text(
            'Aucun message actif',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.noir,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Créez un message motivant pour toute l\'équipe.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.grisText),
          ),
          const SizedBox(height: AppSizes.lg),
          FilledButton.icon(
            onPressed: onCreer,
            style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Créer un message'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// HISTORIQUE
// ══════════════════════════════════════════════════════════

class _HistoriqueItem extends StatelessWidget {
  final MessageSemaine message;
  const _HistoriqueItem({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône type
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _typeBg(message.type),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _typeEmoji(message.type),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: AppSizes.md),

          // Contenu + méta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.contenu,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: message.isActif
                        ? AppColors.noir
                        : AppColors.grisDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (message.prenomCreePar != null)
                      message.prenomCreePar!,
                    _formatDate(message.dateCreation),
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.grisText),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSizes.sm),

          // Statut
          if (message.isActif)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.rouge.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Actif',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.rouge,
                ),
              ),
            )
          else
            const Text(
              'Archivé',
              style: TextStyle(fontSize: 11, color: AppColors.grisText),
            ),
        ],
      ),
    );
  }

  Color _typeBg(MessageType t) => switch (t) {
        MessageType.fete         => const Color(0xFFFFF3E0),
        MessageType.automatique  => const Color(0xFFE3F2FD),
        MessageType.personnalise => const Color(0xFFF3E5F5),
      };

  String _typeEmoji(MessageType t) => switch (t) {
        MessageType.fete         => '🎉',
        MessageType.automatique  => '🤖',
        MessageType.personnalise => '💬',
      };
}

class _HistoriqueVide extends StatelessWidget {
  const _HistoriqueVide();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: AppSizes.lg),
      child: Center(
        child: Text(
          'Aucun message dans l\'historique.',
          style: TextStyle(color: AppColors.grisText, fontSize: 13),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// BOTTOM SHEET — création
// ══════════════════════════════════════════════════════════

class _CreationSheet extends StatefulWidget {
  final Future<void> Function(String contenu, MessageType type) onConfirmer;
  const _CreationSheet({required this.onConfirmer});

  @override
  State<_CreationSheet> createState() => _CreationSheetState();
}

class _CreationSheetState extends State<_CreationSheet> {
  final _ctrl = TextEditingController();
  MessageType _type = MessageType.personnalise;
  String? _selectedFeteMessage;
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _changerType(MessageType t) {
    setState(() {
      _type = t;
      _selectedFeteMessage = null;
      _ctrl.clear();
    });
  }

  bool get _peutSoumettre {
    return switch (_type) {
      MessageType.automatique  => true,
      MessageType.fete         => _selectedFeteMessage != null,
      MessageType.personnalise => _ctrl.text.trim().isNotEmpty,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.lg + bottomPad),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poignée
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),

          const Text(
            'Nouveau message',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.noir,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Visible sur l\'accueil de toute l\'équipe.',
            style: TextStyle(fontSize: 13, color: AppColors.grisText),
          ),
          const SizedBox(height: AppSizes.lg),

          // Type selector
          const Text(
            'Type de message',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.grisDark,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: MessageType.values
                .map((t) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: t != MessageType.values.last
                              ? AppSizes.xs
                              : 0,
                        ),
                        child: _TypeChip(
                          type: t,
                          selected: _type == t,
                          onTap: () => _changerType(t),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSizes.lg),

          // ── Contenu selon le type ────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: switch (_type) {
              MessageType.personnalise => _ChampTexteLibre(
                  key: const ValueKey('perso'),
                  ctrl: _ctrl,
                  onChanged: () => setState(() {}),
                ),
              MessageType.automatique => _PreviewAutomatique(
                  key: const ValueKey('auto'),
                  message: getMessageAutomatique(),
                ),
              MessageType.fete => _SelecteurFete(
                  key: const ValueKey('fete'),
                  selected: _selectedFeteMessage,
                  onSelect: (m) =>
                      setState(() => _selectedFeteMessage = m),
                ),
            },
          ),

          const SizedBox(height: AppSizes.lg),

          // Bouton confirmer
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: (_loading || !_peutSoumettre) ? null : _soumettre,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rouge,
                disabledBackgroundColor:
                    AppColors.rouge.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Publier le message',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _soumettre() async {
    final contenu = switch (_type) {
      MessageType.automatique  => '',
      MessageType.fete         => _selectedFeteMessage!,
      MessageType.personnalise => _ctrl.text.trim(),
    };
    setState(() => _loading = true);
    await widget.onConfirmer(contenu, _type);
  }
}

// ── Champ texte libre (Personnalisé) ──────────────────────

class _ChampTexteLibre extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onChanged;
  const _ChampTexteLibre({super.key, required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: 3,
      maxLength: 200,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        hintText: '💪 Bonne semaine à toute l\'équipe !',
        filled: true,
        fillColor: const Color(0xFFF7F7F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.rouge, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(AppSizes.md),
      ),
    );
  }
}

// ── Aperçu message automatique ─────────────────────────────

class _PreviewAutomatique extends StatelessWidget {
  final String message;
  const _PreviewAutomatique({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        children: [
          const Text('🤖', style: TextStyle(fontSize: 22)),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Message généré automatiquement',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sélecteur message fête ─────────────────────────────────

class _SelecteurFete extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  const _SelecteurFete({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: messagesFete.map((msg) {
        final isSelected = selected == msg;
        return GestureDetector(
          onTap: () => onSelect(msg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: AppSizes.xs),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.rouge.withValues(alpha: 0.07)
                  : const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: isSelected ? AppColors.rouge : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    msg,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? AppColors.rouge : AppColors.noir,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.rouge, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final MessageType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  String get _emoji => switch (type) {
        MessageType.personnalise => '💬',
        MessageType.automatique  => '🤖',
        MessageType.fete         => '🎉',
      };

  String get _label => switch (type) {
        MessageType.personnalise => 'Perso',
        MessageType.automatique  => 'Auto',
        MessageType.fete         => 'Fête',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.rouge.withValues(alpha: 0.09)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: selected ? AppColors.rouge : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(_emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              _label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.rouge : AppColors.grisDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// WIDGETS UTILITAIRES
// ══════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.grisDark,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final MessageType type;
  const _TypeBadge({required this.type});

  String get _label => switch (type) {
        MessageType.personnalise => '💬 Personnalisé',
        MessageType.automatique  => '🤖 Automatique',
        MessageType.fete         => '🎉 Fête',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErreurBaniere extends StatelessWidget {
  final String message;
  const _ErreurBaniere({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border:
            Border.all(color: AppColors.rouge.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.rouge),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.rouge,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Formater date ─────────────────────────────────────────
String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
