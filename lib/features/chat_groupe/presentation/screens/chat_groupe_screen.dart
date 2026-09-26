import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_groupe_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/epingle_banner.dart';
import '../widgets/message_options_bottom_sheet.dart';

/// Largeur à partir de laquelle le panneau latéral (épinglés, participants)
/// s'affiche à droite de la conversation.
const double _kLargeurPanneau = 1100;

const _fondConversation = Color(0xFFF5F6FA);

class ChatGroupeScreen extends ConsumerStatefulWidget {
  const ChatGroupeScreen({super.key});

  @override
  ConsumerState<ChatGroupeScreen> createState() => _ChatGroupeScreenState();
}

class _ChatGroupeScreenState extends ConsumerState<ChatGroupeScreen> {
  final _scrollController = ScrollController();
  final _rechercheCtrl = TextEditingController();
  bool _enBas = true;
  bool _epinglesSeuls = false;
  bool _rechercheOuverte = false;
  String _recherche = '';

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
    _rechercheCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    final enBas = pos.pixels < 80;
    if (enBas != _enBas) setState(() => _enBas = enBas);
    // Liste inversée : le haut de l'écran = les messages les plus anciens.
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(chatGroupeNotifierProvider.notifier).loadMore();
    }
  }

  void _allerEnBas() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _basculerRecherche() => setState(() {
        _rechercheOuverte = !_rechercheOuverte;
        if (!_rechercheOuverte) {
          _rechercheCtrl.clear();
          _recherche = '';
        }
      });

  List<ChatMessage> _visibles(ChatGroupeState state) {
    final q = _recherche.trim().toLowerCase();
    // Les épinglés viennent de leur propre liste : un épinglé ancien n'est pas
    // forcément parmi les messages déjà chargés.
    final source = _epinglesSeuls
        ? ([...state.messagesEpingles]
          ..sort((a, b) => b.dateEnvoi.compareTo(a.dateEnvoi)))
        : state.messages;
    return source.where((m) {
      return q.isEmpty ||
          m.message.toLowerCase().contains(q) ||
          m.prenomAuteur.toLowerCase().contains(q);
    }).toList();
  }

  // ── Actions responsable ────────────────────────────────

  Future<void> _apres(Future<void> action, String succes) async {
    await action;
    if (!mounted) return;
    final erreur = ref.read(chatGroupeNotifierProvider).error;
    if (erreur != null) {
      NotificationApp.erreur(context, erreur);
    } else {
      NotificationApp.succes(context, succes);
    }
  }

  void _epingler(ChatMessage m) => _apres(
      ref.read(chatGroupeNotifierProvider.notifier).epinglerMessage(m.id),
      'Message épinglé pour toute l’équipe.');

  void _desepingler(ChatMessage m) => _apres(
      ref.read(chatGroupeNotifierProvider.notifier).desepinglerMessage(m.id),
      'Message désépinglé.');

  void _supprimer(ChatMessage m) => _apres(
      ref.read(chatGroupeNotifierProvider.notifier).supprimerMessage(m.id),
      'Message supprimé.');

  void _showOptions(ChatMessage msg) {
    showMessageOptions(
      context: context,
      message: msg,
      onEpingler: () => _epingler(msg),
      onDesepingler: () => _desepingler(msg),
      onSupprimer: () => _supprimer(msg),
    );
  }

  // ── Construction ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatGroupeNotifierProvider);
    final employee = ref.watch(employeeCourantProvider);
    final isResponsable = employee?.isResponsable ?? false;
    final myId = employee?.id ?? '';
    final compact = estCompact(context);
    final marge = compact ? 12.0 : 24.0;
    final avecPanneau = MediaQuery.sizeOf(context).width >= _kLargeurPanneau;
    final visibles = _visibles(state);
    final filtre = _epinglesSeuls || _recherche.trim().isNotEmpty;

    // Nouveau message : on descend s'il est à moi ou si on était déjà en bas.
    ref.listen(chatGroupeNotifierProvider, (prev, next) {
      if (prev == null || next.messages.length <= prev.messages.length) return;
      final dernier = next.messages.first;
      if (_enBas || dernier.auteurId == myId) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _allerEnBas());
      }
    });

    final conversation = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grisMedium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_rechercheOuverte)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.grisMedium)),
              ),
              child: ChampRecherche(
                controller: _rechercheCtrl,
                indice: 'Rechercher un message ou un prénom',
                onChanged: (v) => setState(() => _recherche = v),
              ),
            ),
          if (!avecPanneau &&
              !_epinglesSeuls &&
              state.messagesEpingles.isNotEmpty)
            EpingleBanner(epingles: state.messagesEpingles),
          if (state.error != null) _ErrorBanner(message: state.error!),
          Expanded(
            child: ColoredBox(
              color: _fondConversation,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _Messages(
                      state: state,
                      visibles: visibles,
                      filtre: filtre,
                      epinglesSeuls: _epinglesSeuls,
                      myId: myId,
                      controller: _scrollController,
                      onOptions: isResponsable ? _showOptions : null,
                    ),
                  ),
                  if (!_enBas)
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: Tooltip(
                        message: 'Aller aux derniers messages',
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(
                              side: BorderSide(color: AppColors.grisMedium)),
                          elevation: 2,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _allerEnBas,
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.rouge),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.grisMedium),
          ChatInputWidget(
            isSending: state.isSending,
            onEnvoyer: (texte) => ref
                .read(chatGroupeNotifierProvider.notifier)
                .envoyerMessage(texte),
          ),
        ],
      ),
    );

    return PageAvecEnTete(
      chargement: state.isLoading && state.messages.isNotEmpty,
      enTete: const EnTetePage(
        icone: Icons.forum_rounded,
        titre: 'Chat Équipe',
        sousTitre: 'Discussion partagée avec toute l’équipe',
      ),
      contenu: Padding(
        padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.md)
            .plusBarre(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BarreSection(
              titre: _epinglesSeuls
                  ? 'Messages épinglés (${state.messagesEpingles.length})'
                  : 'Discussion de l’équipe',
              onRetour: () => context.backOrHome(isResponsable
                  ? AppRoutes.employerDashboard
                  : AppRoutes.employeeDashboard),
              filtres: [
                FiltreSection(
                  icone: Icons.forum_outlined,
                  infoBulle: 'Tous les messages',
                  actif: !_epinglesSeuls,
                  onTap: () => setState(() {
                    _epinglesSeuls = false;
                    _enBas = true;
                  }),
                ),
                FiltreSection(
                  icone: Icons.push_pin_outlined,
                  infoBulle: 'Messages épinglés',
                  actif: _epinglesSeuls,
                  pastille: state.messagesEpingles.isNotEmpty,
                  onTap: () => setState(() {
                    _epinglesSeuls = true;
                    _enBas = true;
                  }),
                ),
              ],
              actions: [
                ActionSection(
                  icone: _rechercheOuverte
                      ? Icons.search_off_rounded
                      : Icons.search_rounded,
                  infoBulle: _rechercheOuverte
                      ? 'Fermer la recherche'
                      : 'Rechercher dans la discussion',
                  onPressed: _basculerRecherche,
                ),
                ActionSection(
                  icone: Icons.refresh_rounded,
                  infoBulle: 'Actualiser',
                  onPressed: state.isLoading
                      ? null
                      : () => ref
                          .read(chatGroupeNotifierProvider.notifier)
                          .loadMessages(),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Expanded(
              child: avecPanneau
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: conversation),
                        const SizedBox(width: AppSizes.md),
                        SizedBox(
                          width: 300,
                          child: _PanneauLateral(
                            state: state,
                            isResponsable: isResponsable,
                            onDesepingler: _desepingler,
                          ),
                        ),
                      ],
                    )
                  : conversation,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Liste des messages ─────────────────────────────────────

class _Messages extends StatelessWidget {
  final ChatGroupeState state;
  final List<ChatMessage> visibles;
  final bool filtre;
  final bool epinglesSeuls;
  final String myId;
  final ScrollController controller;
  final ValueChanged<ChatMessage>? onOptions;

  const _Messages({
    required this.state,
    required this.visibles,
    required this.filtre,
    required this.epinglesSeuls,
    required this.myId,
    required this.controller,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.rouge));
    }
    if (state.messages.isEmpty) {
      return const _EtatVide(
        icone: Icons.chat_bubble_outline_rounded,
        titre: 'Aucun message pour l’instant',
        texte: 'Soyez le premier à écrire à l’équipe !',
      );
    }
    if (visibles.isEmpty) {
      return _EtatVide(
        icone:
            epinglesSeuls ? Icons.push_pin_outlined : Icons.search_off_rounded,
        titre: epinglesSeuls
            ? 'Aucun message épinglé'
            : 'Aucun message ne correspond',
        texte: epinglesSeuls
            ? 'Les responsables peuvent épingler un message important.'
            : 'Essayez un autre mot ou un autre prénom.',
      );
    }

    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: visibles.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == visibles.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.rouge),
              ),
            ),
          );
        }

        final msg = visibles[i];
        // Liste inversée : i + 1 = plus ancien, i - 1 = plus récent.
        final plusAncien = i < visibles.length - 1 ? visibles[i + 1] : null;
        final plusRecent = i > 0 ? visibles[i - 1] : null;
        final memeJourQueAvant = plusAncien != null &&
            _memeJour(msg.dateEnvoi, plusAncien.dateEnvoi);
        final debut = filtre ||
            plusAncien == null ||
            plusAncien.auteurId != msg.auteurId ||
            !memeJourQueAvant;
        final fin = filtre ||
            plusRecent == null ||
            plusRecent.auteurId != msg.auteurId ||
            !_memeJour(msg.dateEnvoi, plusRecent.dateEnvoi);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!memeJourQueAvant) _SeparateurDate(date: msg.dateEnvoi),
            ChatBubble(
              message: msg,
              isMine: msg.auteurId == myId,
              isStreakStart: debut,
              isStreakEnd: fin,
              onLongPress: onOptions == null ? null : () => onOptions!(msg),
            ),
          ],
        );
      },
    );
  }
}

bool _memeJour(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _libelleJour(DateTime date) {
  final maintenant = DateTime.now();
  if (_memeJour(date, maintenant)) return 'Aujourd’hui';
  if (_memeJour(date, maintenant.subtract(const Duration(days: 1)))) {
    return 'Hier';
  }
  final t = DateFormat(
          date.year == maintenant.year ? 'EEEE d MMMM' : 'EEEE d MMMM yyyy',
          'fr_FR')
      .format(date);
  return t[0].toUpperCase() + t.substring(1);
}

class _SeparateurDate extends StatelessWidget {
  final DateTime date;
  const _SeparateurDate({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.grisMedium)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.grisMedium),
            ),
            child: Text(
              _libelleJour(date),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.grisDark,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.grisMedium)),
        ],
      ),
    );
  }
}

// ── Panneau latéral (grand écran) ──────────────────────────

class _PanneauLateral extends StatelessWidget {
  final ChatGroupeState state;
  final bool isResponsable;
  final ValueChanged<ChatMessage> onDesepingler;

  const _PanneauLateral({
    required this.state,
    required this.isResponsable,
    required this.onDesepingler,
  });

  @override
  Widget build(BuildContext context) {
    // Participants : auteurs des messages chargés, du plus actif au moins actif.
    final parAuteur = <String, (String, int)>{};
    for (final m in state.messages) {
      final (prenom, n) = parAuteur[m.auteurId] ?? (m.prenomAuteur, 0);
      parAuteur[m.auteurId] = (prenom, n + 1);
    }
    final participants = parAuteur.entries.toList()
      ..sort((a, b) => b.value.$2.compareTo(a.value.$2));

    Widget titre(IconData icone, String texte, Color couleur) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(
            children: [
              Icon(icone, size: 16, color: couleur),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  texte,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.noir,
                  ),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Épinglés ─────────────────────────────────────
        Flexible(
          flex: 3,
          child: CarteContenu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titre(
                    Icons.push_pin_rounded,
                    'ÉPINGLÉS (${state.messagesEpingles.length})',
                    couleurEpingle),
                const Divider(height: 1, color: AppColors.grisMedium),
                Expanded(
                  child: state.messagesEpingles.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'Aucun message épinglé pour le moment.',
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.grisText),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(10),
                          itemCount: state.messagesEpingles.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final m = state.messagesEpingles[i];
                            return _CarteEpingle(
                              message: m,
                              onDesepingler:
                                  isResponsable ? () => onDesepingler(m) : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.md),
        // ── Participants ─────────────────────────────────
        Flexible(
          flex: 2,
          child: CarteContenu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titre(Icons.people_alt_rounded,
                    'PARTICIPANTS (${participants.length})', AppColors.rouge),
                const Divider(height: 1, color: AppColors.grisMedium),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: [
                      for (final p in participants)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          child: Row(
                            children: [
                              AvatarProfil(
                                proprietaire: ProprietairePhoto(
                                    TypeProprietairePhoto.employe, p.key),
                                initiales: p.value.$1.isNotEmpty
                                    ? p.value.$1[0].toUpperCase()
                                    : '?',
                                rayon: 14,
                                couleurFond: couleurAuteur(p.value.$1),
                                tailleTexte: 11,
                                poidsTexte: FontWeight.w600,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.value.$1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.noir),
                                ),
                              ),
                              Text(
                                '${p.value.$2} msg',
                                style: const TextStyle(
                                    fontSize: 11.5, color: AppColors.grisText),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CarteEpingle extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onDesepingler;
  const _CarteEpingle({required this.message, required this.onDesepingler});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: couleurEpingle.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: couleurEpingle.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.prenomAuteur,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: couleurAuteur(message.prenomAuteur),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.message,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.35, color: AppColors.noir),
                ),
                const SizedBox(height: 4),
                Text(
                  _libelleJour(message.dateEnvoi),
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.grisText),
                ),
              ],
            ),
          ),
          if (onDesepingler != null)
            IconButton(
              tooltip: 'Désépingler',
              onPressed: onDesepingler,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              color: couleurEpingle,
              icon: const Icon(Icons.push_pin_outlined),
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
      color: AppColors.refus.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: AppColors.refus),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: AppColors.refus),
            ),
          ),
        ],
      ),
    );
  }
}

// ── État vide ──────────────────────────────────────────────

class _EtatVide extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String texte;

  const _EtatVide({
    required this.icone,
    required this.titre,
    required this.texte,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.rouge.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 40, color: AppColors.rouge),
            ),
            const SizedBox(height: 14),
            Text(
              titre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.noir,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              texte,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grisText, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
