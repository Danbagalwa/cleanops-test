import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat_groupe/presentation/widgets/chat_input_widget.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';
import '../../domain/entities/memo.dart';
import '../providers/memo_provider.dart';

// ── Helpers ────────────────────────────────────────────────

const _kAvatarPalette = [
  Color(0xFF1A7A3C),
  Color(0xFF1A4A7A),
  Color(0xFF7B1FA2),
  Color(0xFF00897B),
  Color(0xFFE65100),
  Color(0xFFC62828),
  Color(0xFF283593),
  Color(0xFF558B2F),
];

const _fondConversation = Color(0xFFF5F6FA);

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
  if (diff == 1) return 'Hier';
  if (diff < 7) return DateFormat('EEE', 'fr_FR').format(dt);
  return DateFormat('dd/MM', 'fr_FR').format(dt);
}

String _titreConversation(List<Memo> memos, bool isResponsable) {
  if (memos.isEmpty) return isResponsable ? 'Conversation' : 'La direction';
  if (isResponsable) {
    for (final m in memos) {
      if (m.estDeEmploye && m.auteurPrenom != null) return m.auteurPrenom!;
    }
    return memos.first.auteurPrenom ?? 'Préposée';
  }
  return 'La direction';
}

/// À qui appartient la photo de l'interlocuteur : la préposée pour le
/// responsable, l'auteur d'un message du responsable pour la préposée.
ProprietairePhoto? _proprietaireConversation(
    List<Memo> memos, bool isResponsable, String preposeeId) {
  if (isResponsable) {
    return ProprietairePhoto(TypeProprietairePhoto.employe, preposeeId);
  }
  for (final m in memos) {
    if (!m.estDeEmploye) {
      return ProprietairePhoto(TypeProprietairePhoto.employe, m.auteurId);
    }
  }
  return null;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

BoxDecoration get _carte => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.grisMedium),
    );

// ══════════════════════════════════════════════════════════
// ÉCRAN
// ══════════════════════════════════════════════════════════

class MemoScreen extends ConsumerStatefulWidget {
  final String? employeeId;
  final String? date;
  const MemoScreen({super.key, this.employeeId, this.date});

  @override
  ConsumerState<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends ConsumerState<MemoScreen> {
  final _rechercheCtrl = TextEditingController();
  String? _selectedId;
  bool _nonLuesSeules = false;
  String _recherche = '';

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

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

  void _selectionner(String? id) => setState(() => _selectedId = id);

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(employeeCourantProvider);
    final isResponsable = employee?.isResponsable ?? false;
    final compact = estCompact(context);
    final marge = compact ? 12.0 : 24.0;

    // ── Préposée : sa conversation avec la direction ─────
    if (!isResponsable) {
      final myId = employee?.id ?? widget.employeeId ?? '';
      return _Page(
        marge: marge,
        sousTitre: 'Messages privés avec la direction',
        barre: BarreSection(
          titre: 'Conversation avec la direction',
          onRetour: () => context.backOrHome(AppRoutes.employeeDashboard),
          actions: [
            ActionSection(
              icone: Icons.refresh_rounded,
              infoBulle: 'Actualiser',
              onPressed: () => ref
                  .read(memoConversationNotifierProvider(myId).notifier)
                  .chargerConversation(),
            ),
          ],
        ),
        contenu: _Conversation(
          key: ValueKey(myId),
          preposeeId: myId,
          isResponsable: false,
        ),
      );
    }

    // ── Responsable : liste des préposées + conversation ─
    final liste = ref.watch(memoListNotifierProvider);
    final totalNonLus = liste.preposees.fold(0, (s, p) => s + p.nonLusCount);
    final q = _recherche.trim().toLowerCase();
    final preposees = liste.preposees
        .where((p) =>
            (!_nonLuesSeules || p.nonLusCount > 0) &&
            (q.isEmpty || p.prenom.toLowerCase().contains(q)))
        .toList();
    final enConversationMobile = compact && _selectedId != null;

    Future<void> actualiser() async {
      await ref.read(memoListNotifierProvider.notifier).charger();
      if (_selectedId != null) {
        await ref
            .read(memoConversationNotifierProvider(_selectedId!).notifier)
            .chargerConversation();
      }
    }

    final panneauListe = _ListePreposees(
      state: liste,
      preposees: preposees,
      selectedId: compact ? null : _selectedId,
      nonLuesSeules: _nonLuesSeules,
      rechercheCtrl: _rechercheCtrl,
      onRecherche: (v) => setState(() => _recherche = v),
      onSelect: _selectionner,
    );

    final Widget contenu;
    if (compact) {
      contenu = enConversationMobile
          ? _Conversation(
              key: ValueKey(_selectedId),
              preposeeId: _selectedId!,
              isResponsable: true,
            )
          : panneauListe;
    } else {
      contenu = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 330, child: panneauListe),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: _selectedId == null
                ? const _AucuneConversation()
                : _Conversation(
                    key: ValueKey(_selectedId),
                    preposeeId: _selectedId!,
                    isResponsable: true,
                  ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: !enConversationMobile,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectionner(null);
      },
      child: _Page(
        marge: marge,
        chargement: liste.isLoading && liste.preposees.isNotEmpty,
        sousTitre: totalNonLus > 0
            ? 'Messages privés avec les préposées — $totalNonLus non lu'
                '${totalNonLus > 1 ? 's' : ''}'
            : 'Messages privés avec les préposées',
        barre: BarreSection(
          titre: enConversationMobile
              ? 'Conversation'
              : 'Conversations (${liste.preposees.length})',
          onRetour: enConversationMobile
              ? () => _selectionner(null)
              : () => context.backOrHome(AppRoutes.employerDashboard),
          filtres: enConversationMobile
              ? const []
              : [
                  FiltreSection(
                    icone: Icons.forum_outlined,
                    infoBulle: 'Toutes les conversations',
                    actif: !_nonLuesSeules,
                    onTap: () => setState(() => _nonLuesSeules = false),
                  ),
                  FiltreSection(
                    icone: Icons.mark_chat_unread_outlined,
                    infoBulle: 'Non lues',
                    actif: _nonLuesSeules,
                    pastille: totalNonLus > 0,
                    onTap: () => setState(() => _nonLuesSeules = true),
                  ),
                ],
          actions: [
            ActionSection(
              icone: Icons.refresh_rounded,
              infoBulle: 'Actualiser',
              onPressed: liste.isLoading ? null : actualiser,
            ),
          ],
        ),
        contenu: contenu,
      ),
    );
  }
}

/// Squelette commun : en-tête fixe, barre de section, puis une zone qui
/// occupe toute la hauteur restante (la conversation gère son défilement).
class _Page extends StatelessWidget {
  final double marge;
  final String sousTitre;
  final BarreSection barre;
  final Widget contenu;
  final bool chargement;

  const _Page({
    required this.marge,
    required this.sousTitre,
    required this.barre,
    required this.contenu,
    this.chargement = false,
  });

  @override
  Widget build(BuildContext context) {
    return PageAvecEnTete(
      chargement: chargement,
      enTete: EnTetePage(
        icone: Icons.mark_email_unread_rounded,
        titre: 'Mémos',
        sousTitre: sousTitre,
      ),
      contenu: Padding(
        padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.md)
            .plusBarre(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            barre,
            const SizedBox(height: AppSizes.md),
            Expanded(child: contenu),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// LISTE DES PRÉPOSÉES (responsable)
// ══════════════════════════════════════════════════════════

class _ListePreposees extends ConsumerWidget {
  final MemoListState state;
  final List<PreposeeResume> preposees;
  final String? selectedId;
  final bool nonLuesSeules;
  final TextEditingController rechercheCtrl;
  final ValueChanged<String> onRecherche;
  final ValueChanged<String> onSelect;

  const _ListePreposees({
    required this.state,
    required this.preposees,
    required this.selectedId,
    required this.nonLuesSeules,
    required this.rechercheCtrl,
    required this.onRecherche,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget corps;
    if (state.isLoading && state.preposees.isEmpty) {
      corps = const Center(
          child: CircularProgressIndicator(color: AppColors.rouge));
    } else if (state.error != null && state.preposees.isEmpty) {
      corps = _ErrorView(
        message: state.error!,
        onRetry: () => ref.read(memoListNotifierProvider.notifier).charger(),
      );
    } else if (state.preposees.isEmpty) {
      corps = const _PlaceholderView(
        icon: Icons.forum_outlined,
        titre: 'Aucune préposée',
        sousTitre: 'Les préposées actives apparaîtront ici.',
      );
    } else if (preposees.isEmpty) {
      corps = _PlaceholderView(
        icon: nonLuesSeules
            ? Icons.mark_chat_read_outlined
            : Icons.search_off_rounded,
        titre: nonLuesSeules ? 'Tout est lu' : 'Aucun résultat',
        sousTitre: nonLuesSeules
            ? 'Aucune conversation avec des messages non lus.'
            : 'Aucune préposée ne correspond à la recherche.',
      );
    } else {
      corps = RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: () => ref.read(memoListNotifierProvider.notifier).charger(),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: preposees.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72, color: AppColors.grisMedium),
          itemBuilder: (_, i) {
            final r = preposees[i];
            return _ConversationTile(
              resume: r,
              isSelected: selectedId == r.employeeId,
              onTap: () => onSelect(r.employeeId),
            );
          },
        ),
      );
    }

    return Container(
      decoration: _carte,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: ChampRecherche(
              controller: rechercheCtrl,
              indice: 'Rechercher une préposée',
              onChanged: onRecherche,
            ),
          ),
          const Divider(height: 1, color: AppColors.grisMedium),
          Expanded(child: corps),
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
    final hasUnread = resume.nonLusCount > 0;
    final tempsStr = _tempsConversation(resume.dernierEnvoi);

    return Material(
      color:
          isSelected ? AppColors.rouge.withValues(alpha: 0.07) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected ? AppColors.rouge : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(11, 10, 14, 10),
          child: Row(
            children: [
              AvatarProfil(
                proprietaire: ProprietairePhoto(
                    TypeProprietairePhoto.employe, resume.employeeId),
                initiales: initiale,
                rayon: 22,
                couleurFond: _avatarColor(resume.prenom),
                tailleTexte: 15,
                poidsTexte: FontWeight.w700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            resume.prenom,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight:
                                  hasUnread ? FontWeight.w800 : FontWeight.w600,
                              color: AppColors.noir,
                            ),
                          ),
                        ),
                        if (tempsStr.isNotEmpty)
                          Text(
                            tempsStr,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: hasUnread
                                  ? AppColors.rouge
                                  : AppColors.grisText,
                              fontWeight:
                                  hasUnread ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
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
                              fontSize: 12.5,
                              fontStyle: resume.dernierMessage == null
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: hasUnread
                                  ? AppColors.noir
                                  : AppColors.grisText,
                              fontWeight:
                                  hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            constraints: const BoxConstraints(minWidth: 20),
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
                                color: Colors.white,
                              ),
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

class _AucuneConversation extends StatelessWidget {
  const _AucuneConversation();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _carte,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.rouge.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_unread_outlined,
                  size: 40, color: AppColors.rouge),
            ),
            const SizedBox(height: AppSizes.md),
            const Text(
              'Sélectionnez une conversation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.noir,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'pour échanger des messages privés avec une préposée.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.grisText),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// CONVERSATION
// ══════════════════════════════════════════════════════════

class _Conversation extends ConsumerStatefulWidget {
  final String preposeeId;
  final bool isResponsable;

  const _Conversation({
    super.key,
    required this.preposeeId,
    required this.isResponsable,
  });

  @override
  ConsumerState<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends ConsumerState<_Conversation> {
  final _scrollController = ScrollController();
  int _lastCount = 0;
  bool _enBas = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final p = _scrollController.position;
      final enBas = p.pixels >= p.maxScrollExtent - 80;
      if (enBas != _enBas) setState(() => _enBas = enBas);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _allerEnBas({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (instant) {
        _scrollController.jumpTo(max);
      } else {
        _scrollController.animateTo(max,
            duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _envoyer(String texte) async {
    await ref
        .read(memoConversationNotifierProvider(widget.preposeeId).notifier)
        .envoyerMemo(texte);
    _allerEnBas();
    // La liste (dernier message, heure) suit l'envoi.
    if (widget.isResponsable) {
      ref.read(memoListNotifierProvider.notifier).charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(memoConversationNotifierProvider(widget.preposeeId));

    if (state.memos.length != _lastCount) {
      final premier = _lastCount == 0;
      final dernierEstAMoi = state.memos.isNotEmpty &&
          (widget.isResponsable
              ? state.memos.last.estDeEmployeur
              : state.memos.last.estDeEmploye);
      _lastCount = state.memos.length;
      if (premier || _enBas || dernierEstAMoi) _allerEnBas(instant: premier);
      // Ouvrir la conversation marque ses mémos comme lus : les compteurs de
      // la liste suivent une fois l'enregistrement fait.
      if (premier && widget.isResponsable) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) ref.read(memoListNotifierProvider.notifier).charger();
        });
      }
    }

    final titre = _titreConversation(state.memos, widget.isResponsable);
    final initiale = titre.isNotEmpty ? titre[0].toUpperCase() : '?';

    return Container(
      decoration: _carte,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Interlocuteur ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                AvatarProfil(
                  proprietaire: _proprietaireConversation(
                      state.memos, widget.isResponsable, widget.preposeeId),
                  initiales: initiale,
                  rayon: 19,
                  couleurFond: _avatarColor(titre),
                  tailleTexte: 14,
                  poidsTexte: FontWeight.w700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.noir,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 12, color: AppColors.grisText),
                          const SizedBox(width: 3),
                          Text(
                            'Conversation privée · ${state.memos.length} '
                            'message${state.memos.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.grisText),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Actualiser la conversation',
                  onPressed: () => ref
                      .read(memoConversationNotifierProvider(widget.preposeeId)
                          .notifier)
                      .chargerConversation(),
                  icon:
                      const Icon(Icons.refresh_rounded, color: AppColors.rouge),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.grisMedium),
          if (state.error != null) _ErreurBandeau(message: state.error!),

          // ── Messages ─────────────────────────────────────
          Expanded(
            child: ColoredBox(
              color: _fondConversation,
              child: Stack(
                children: [
                  Positioned.fill(child: _messages(state)),
                  if (!_enBas && state.memos.isNotEmpty)
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
          ChatInputWidget(isSending: state.isSending, onEnvoyer: _envoyer),
        ],
      ),
    );
  }

  Widget _messages(MemoConversationState state) {
    if (state.isLoading && state.memos.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.rouge));
    }
    if (state.memos.isEmpty) {
      return _PlaceholderView(
        icon: Icons.chat_bubble_outline_rounded,
        titre: 'Pas encore de message',
        sousTitre: widget.isResponsable
            ? 'Écrivez le premier mémo à cette préposée.'
            : 'Écrivez à la direction : votre message reste privé.',
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: state.memos.length,
      itemBuilder: (_, i) {
        final memo = state.memos[i];
        final isMine =
            widget.isResponsable ? memo.estDeEmployeur : memo.estDeEmploye;
        final precedent = i > 0 ? state.memos[i - 1] : null;
        final nouveauJour =
            precedent == null || !_sameDay(precedent.dateEnvoi, memo.dateEnvoi);
        final debutSerie = nouveauJour || precedent.auteur != memo.auteur;
        return Column(children: [
          if (nouveauJour) _DateSeparateur(date: memo.dateEnvoi),
          _Bulle(memo: memo, isMine: isMine, debutSerie: debutSerie),
        ]);
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
// COMPOSANTS
// ══════════════════════════════════════════════════════════

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
      label = 'Aujourd’hui';
    } else if (today.difference(dtDay).inDays == 1) {
      label = 'Hier';
    } else {
      final t = DateFormat(
              date.year == now.year ? 'EEEE d MMMM' : 'EEEE d MMMM yyyy',
              'fr_FR')
          .format(date);
      label = t[0].toUpperCase() + t.substring(1);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
              label,
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

class _Bulle extends StatelessWidget {
  final Memo memo;
  final bool isMine;
  final bool debutSerie;
  const _Bulle({
    required this.memo,
    required this.isMine,
    required this.debutSerie,
  });

  @override
  Widget build(BuildContext context) {
    final maxW = (MediaQuery.sizeOf(context).width * 0.72).clamp(200.0, 520.0);

    return Padding(
      padding: EdgeInsets.only(
        top: debutSerie ? 6 : 1,
        bottom: 2,
        left: isMine ? 56 : 0,
        right: isMine ? 0 : 56,
      ),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: isMine ? AppColors.rouge : Colors.white,
            border: isMine ? null : Border.all(color: AppColors.grisMedium),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine && debutSerie && memo.auteurPrenom != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    memo.auteurPrenom!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _avatarColor(memo.auteurPrenom!),
                    ),
                  ),
                ),
              Text(
                memo.message,
                style: TextStyle(
                  fontSize: 14.5,
                  color: isMine ? Colors.white : AppColors.noir,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateHelper.formatHeure(memo.dateEnvoi),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.72)
                          : AppColors.grisText,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: memo.isLu ? 'Lu' : 'Envoyé',
                      child: Icon(
                        memo.isLu ? Icons.done_all_rounded : Icons.done_rounded,
                        size: 14,
                        color: memo.isLu
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppColors.refus.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 15, color: AppColors.refus),
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

class _PlaceholderView extends StatelessWidget {
  final IconData icon;
  final String titre;
  final String sousTitre;
  const _PlaceholderView(
      {required this.icon, required this.titre, required this.sousTitre});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.rouge.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.rouge),
            ),
            const SizedBox(height: 12),
            Text(
              titre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.noir,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sousTitre,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.grisText),
            ),
          ],
        ),
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
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 44, color: AppColors.grisText),
            const SizedBox(height: AppSizes.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.grisDark),
            ),
            const SizedBox(height: AppSizes.md),
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
