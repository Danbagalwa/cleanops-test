import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/dialogue_app.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/export_menu_button.dart'
    show showExportSuccess;
import '../../../../core/widgets/mise_en_page.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pdf/domain/usecases/generate_messages_semaine_export.dart';
import '../../../pdf/presentation/screens/messages_semaine_pdf_preview_screen.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';
import '../../domain/entities/message_semaine.dart';
import '../providers/message_semaine_provider.dart'
    show getMessageAutomatique, messageSemaineNotifierProvider, messagesFete;

enum _Statut { tous, actif, archives }

enum _Tri { publication, auteur, duree }

final _fmt = DateFormat('dd/MM/yyyy HH:mm');

const _orange = Color(0xFFE65100);

Color _couleurType(MessageType type) => switch (type) {
      MessageType.personnalise => AppColors.rouge,
      MessageType.automatique => const Color(0xFF1769AA),
      MessageType.fete => const Color(0xFFB54708),
    };

IconData _iconeType(MessageType type) => switch (type) {
      MessageType.personnalise => Icons.chat_bubble_outline_rounded,
      MessageType.automatique => Icons.auto_awesome_outlined,
      MessageType.fete => Icons.celebration_outlined,
    };

String _duree(MessageSemaine m) {
  final j = joursAffichage(m);
  return '$j jour${j > 1 ? 's' : ''}';
}

class MessagesSemaineScreen extends ConsumerStatefulWidget {
  const MessagesSemaineScreen({super.key});

  @override
  ConsumerState<MessagesSemaineScreen> createState() =>
      _MessagesSemaineScreenState();
}

class _MessagesSemaineScreenState extends ConsumerState<MessagesSemaineScreen> {
  _Statut _statut = _Statut.tous;
  MessageType? _type;
  String _recherche = '';
  _Tri _tri = _Tri.publication;
  bool _croissant = false;
  int _page = 0;
  int _parPage = 10;

  /// `null` : choisi selon la largeur (grille sur téléphone, tableau sinon).
  ModeAffichage? _mode;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    final notifier = ref.read(messageSemaineNotifierProvider.notifier);
    await Future.wait([
      notifier.loadMessageActif(),
      notifier.loadHistorique(),
    ]);
  }

  void _changer(VoidCallback maj) => setState(() {
        maj();
        _page = 0;
      });

  void _trier(_Tri tri) => _changer(() {
        _croissant = _tri == tri ? !_croissant : tri == _Tri.auteur;
        _tri = tri;
      });

  bool _duStatut(MessageSemaine m) => switch (_statut) {
        _Statut.tous => true,
        _Statut.actif => m.isActif,
        _Statut.archives => !m.isActif,
      };

  List<MessageSemaine> _lignes(List<MessageSemaine> tous) {
    final q = _recherche.trim().toLowerCase();
    int sens(int c) => _croissant ? c : -c;
    return tous.where((m) {
      if (!_duStatut(m)) return false;
      if (_type != null && m.type != _type) return false;
      return q.isEmpty ||
          m.contenu.toLowerCase().contains(q) ||
          m.auteur.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => switch (_tri) {
            _Tri.publication => sens(a.dateCreation.compareTo(b.dateCreation)),
            _Tri.auteur =>
              sens(a.auteur.toLowerCase().compareTo(b.auteur.toLowerCase())),
            _Tri.duree => sens(joursAffichage(a).compareTo(joursAffichage(b))),
          });
  }

  String _descriptionFiltres() {
    final f = <String>[
      if (_statut == _Statut.actif) 'Visible',
      if (_statut == _Statut.archives) 'Archivés',
      if (_type != null) libelleTypeMessage(_type!),
      if (_recherche.trim().isNotEmpty) '« ${_recherche.trim()} »',
    ];
    return f.isEmpty ? 'Tous les messages' : f.join(' · ');
  }

  // ── Actions ────────────────────────────────────────────

  Future<void> _publier({MessageSemaine? remplace}) async {
    final publie = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreationDialog(
        remplace:
            remplace ?? ref.read(messageSemaineNotifierProvider).messageActif,
        onConfirm: (contenu, type) => ref
            .read(messageSemaineNotifierProvider.notifier)
            .creerMessage(contenu, type),
      ),
    );
    if (publie == true && mounted) {
      NotificationApp.succes(
          context, 'Le message est maintenant visible par toute l’équipe.');
    }
  }

  Future<void> _republier(MessageSemaine m) async {
    final actif = ref.read(messageSemaineNotifierProvider).messageActif;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ConfirmationDialog(
        titre: 'Republier ce message',
        message: m,
        texte: actif == null
            ? 'Il sera de nouveau visible sur le tableau de bord de toute '
                'l’équipe.'
            : 'Il remplacera le message visible actuellement, qui passera '
                'dans l’historique.',
        libelleAction: 'Republier',
        onConfirm: () => ref
            .read(messageSemaineNotifierProvider.notifier)
            .creerMessage(m.contenu, m.type),
      ),
    );
    if (!mounted || ok == null) return;
    ok
        ? NotificationApp.succes(
            context, 'Le message est de nouveau visible par l’équipe.')
        : NotificationApp.erreur(
            context, 'La publication n’a pas abouti. Vous pouvez réessayer.');
  }

  Future<void> _retirer(MessageSemaine m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmationDialog(
        titre: 'Retirer ce message',
        message: m,
        texte: 'Il ne sera plus visible par l’équipe, mais restera dans '
            'l’historique. Vous pourrez le republier.',
        libelleAction: 'Retirer',
        onConfirm: () => ref
            .read(messageSemaineNotifierProvider.notifier)
            .desactiverMessage(m.id),
      ),
    );
    if (!mounted || ok == null) return;
    ok
        ? NotificationApp.succes(
            context, 'Le message a été retiré du tableau de bord.')
        : NotificationApp.erreur(context,
            'Le message n’a pas pu être retiré. Vous pouvez réessayer.');
  }

  void _ouvrir(MessageSemaine m) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _DetailMessage(
        message: m,
        onRepublier: () {
          Navigator.of(ctx).pop();
          _republier(m);
        },
        onRetirer: () {
          Navigator.of(ctx).pop();
          _retirer(m);
        },
      ),
    );
  }

  void _exporterPdf(List<MessageSemaine> lignes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MessagesSemainePdfPreviewScreen(
          messages: lignes,
          filtres: _descriptionFiltres(),
          generatedBy:
              ref.read(employeeCourantProvider)?.nomComplet ?? 'CleanOps',
        ),
      ),
    );
  }

  void _exporterExcel(List<MessageSemaine> lignes) {
    try {
      const GenerateMessagesSemaineExcel()(
        messages: lignes,
        filtres: _descriptionFiltres(),
      );
      showExportSuccess(context, 'L’historique des messages a été téléchargé.');
    } catch (error) {
      AppFeedback.showError(context, error);
    }
  }

  // ── Construction ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messageSemaineNotifierProvider);
    final compact = estCompact(context);
    final mode =
        compact ? ModeAffichage.grille : (_mode ?? ModeAffichage.tableau);
    final marge = compact ? 12.0 : 24.0;

    final tous = state.historique;
    final lignes = _lignes(tous);
    final nbPages = lignes.isEmpty ? 1 : ((lignes.length - 1) ~/ _parPage) + 1;
    final page = _page.clamp(0, nbPages - 1);
    final visibles = lignes.skip(page * _parPage).take(_parPage).toList();
    final actif = state.messageActif;

    FiltreSection filtre(_Statut s, IconData icone, String info,
            {bool pastille = false}) =>
        FiltreSection(
          icone: icone,
          infoBulle: info,
          actif: _statut == s,
          pastille: pastille,
          onTap: () => _changer(() => _statut = s),
        );

    final recherche = ChampRecherche(
      indice: 'Rechercher un message ou un auteur',
      onChanged: (v) => _changer(() => _recherche = v),
    );
    final nouveau = FilledButton.icon(
      onPressed: state.isLoading ? null : () => _publier(),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Nouveau message'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.rouge,
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    );

    Widget corps;
    if (state.isLoading && tous.isEmpty) {
      corps = const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.rouge)),
      );
    } else if (state.error != null && tous.isEmpty) {
      corps = CarteContenu(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: AppErrorNotice(error: state.error!, onRetry: _refresh),
      );
    } else if (tous.isEmpty) {
      corps = const _EtatVide(
        titre: 'Aucun message publié',
        texte: 'Les messages publiés pour l’équipe apparaîtront ici.',
      );
    } else if (lignes.isEmpty) {
      corps = _EtatVide(
        titre: 'Aucun message ne correspond',
        texte: 'Modifiez les filtres ou la recherche.',
        onReinitialiser: () => _changer(() {
          _statut = _Statut.tous;
          _type = null;
        }),
      );
    } else {
      corps = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == ModeAffichage.tableau)
            _TableauMessages(
              lignes: visibles,
              premierNumero: page * _parPage + 1,
              tri: _tri,
              croissant: _croissant,
              onTrier: _trier,
              onOuvrir: _ouvrir,
              onRepublier: _republier,
              onRetirer: _retirer,
            )
          else
            _GrilleMessages(
              lignes: visibles,
              onOuvrir: _ouvrir,
              onRepublier: _republier,
              onRetirer: _retirer,
            ),
          const SizedBox(height: AppSizes.md),
          BarrePagination(
            page: page,
            parPage: _parPage,
            total: lignes.length,
            onPage: (p) => setState(() => _page = p),
            onParPage: (n) => _changer(() => _parPage = n),
          ),
        ],
      );
    }

    return PageAvecEnTete(
      chargement: state.isLoading,
      enTete: EnTetePage(
        icone: Icons.campaign_rounded,
        titre: 'Messages de la semaine',
        sousTitre: actif == null
            ? 'Aucun message n’est affiché à l’équipe en ce moment'
            : 'Le message affiché sur le tableau de bord de toute l’équipe',
      ),
      contenu: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
              .plusBarre(context),
          children: [
            BarreSection(
              titre: 'Messages (${lignes.length})',
              onRetour: () => context.backOrHome(AppRoutes.employerDashboard),
              filtres: [
                filtre(
                    _Statut.tous, Icons.list_alt_rounded, 'Tous les messages'),
                filtre(_Statut.actif, Icons.visibility_outlined,
                    'Visible actuellement',
                    pastille: actif != null),
                filtre(
                    _Statut.archives, Icons.inventory_2_outlined, 'Archivés'),
              ],
              actions: [
                ActionSection(
                  icone: Icons.print_rounded,
                  infoBulle: 'Imprimer ou exporter en PDF',
                  onPressed: lignes.isEmpty || state.isLoading
                      ? null
                      : () => _exporterPdf(lignes),
                ),
                ActionSection(
                  icone: Icons.download_rounded,
                  infoBulle: 'Télécharger en Excel',
                  onPressed: lignes.isEmpty || state.isLoading
                      ? null
                      : () => _exporterExcel(lignes),
                ),
                ActionSection(
                  icone: Icons.refresh_rounded,
                  infoBulle: 'Actualiser',
                  onPressed: state.isLoading ? null : _refresh,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            if (!(state.isLoading && tous.isEmpty))
              actif == null
                  ? _AucunMessageVisible(onPublier: () => _publier())
                  : _MessageVisible(
                      message: actif,
                      enCours: state.isLoading,
                      onRemplacer: () => _publier(remplace: actif),
                      onRetirer: () => _retirer(actif),
                    ),
            if (tous.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              _FiltreTypes(
                messages: tous.where(_duStatut).toList(),
                selection: _type,
                onChanged: (t) => _changer(() => _type = t),
              ),
            ],
            const SizedBox(height: AppSizes.md),
            if (compact) ...[
              recherche,
              const SizedBox(height: 10),
              nouveau,
            ] else
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: recherche,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  nouveau,
                  const SizedBox(width: AppSizes.md),
                  BasculeAffichage(
                    mode: mode,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                ],
              ),
            const SizedBox(height: AppSizes.md),
            corps,
          ],
        ),
      ),
    );
  }
}

// ── Message visible actuellement ───────────────────────────

class _MessageVisible extends StatelessWidget {
  final MessageSemaine message;
  final bool enCours;
  final VoidCallback onRemplacer;
  final VoidCallback onRetirer;

  const _MessageVisible({
    required this.message,
    required this.enCours,
    required this.onRemplacer,
    required this.onRetirer,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    final compact = estCompact(context);
    final jours = joursAffichage(m);
    final boutons = [
      OutlinedButton.icon(
        onPressed: enCours ? null : onRetirer,
        icon: const Icon(Icons.visibility_off_outlined, size: 17),
        label: const Text('Retirer'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _orange,
          side: const BorderSide(color: Color(0xFFFFCC9B)),
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 42),
        ),
      ),
      FilledButton.icon(
        onPressed: enCours ? null : onRemplacer,
        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
        label: const Text('Remplacer'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.rouge,
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 42),
        ),
      ),
    ];

    final bord = BorderSide(color: AppColors.rouge.withValues(alpha: 0.35));
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        // Liseré bleu à gauche : le message que l'équipe voit.
        border: Border(
          left: const BorderSide(color: AppColors.rouge, width: 5),
          top: bord,
          right: bord,
          bottom: bord,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const _Pastille(Icons.visibility_rounded,
                    'Visible actuellement', AppColors.fait),
                _BadgeType(m.type),
                Text(
                  'depuis $jours jour${jours > 1 ? 's' : ''}',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.grisText),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SelectableText(
              m.contenu,
              style: TextStyle(
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: AppColors.noir,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _Auteur(m)),
                if (!compact) ...[
                  boutons[0],
                  const SizedBox(width: 10),
                  boutons[1],
                ],
              ],
            ),
            if (compact) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: boutons[0]),
                  const SizedBox(width: 10),
                  Expanded(child: boutons[1]),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AucunMessageVisible extends StatelessWidget {
  final VoidCallback onPublier;
  const _AucunMessageVisible({required this.onPublier});

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.rouge.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded,
                color: AppColors.rouge),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aucun message visible',
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.noir)),
                SizedBox(height: 2),
                Text(
                  'Publiez une information, un encouragement ou un rappel '
                  'pour toute l’équipe.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.grisDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onPublier,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Publier'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rouge,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filtre par type (avec effectifs) ───────────────────────

class _FiltreTypes extends StatelessWidget {
  final List<MessageSemaine> messages;
  final MessageType? selection;
  final ValueChanged<MessageType?> onChanged;

  const _FiltreTypes({
    required this.messages,
    required this.selection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    _Tuile tuile(MessageType? t) => _Tuile(
          icone: t == null ? Icons.apps_rounded : _iconeType(t),
          couleur: t == null ? AppColors.rouge : _couleurType(t),
          libelle: t == null ? 'Tous les types' : libelleTypeMessage(t),
          nombre: t == null
              ? messages.length
              : messages.where((m) => m.type == t).length,
          actif: selection == t,
          onTap: () => onChanged(selection == t ? null : t),
        );
    final tuiles = [tuile(null), for (final t in MessageType.values) tuile(t)];

    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      const minimum = 160.0;
      if (c.maxWidth >= tuiles.length * minimum + ecart * (tuiles.length - 1)) {
        return Row(
          children: [
            for (final (i, t) in tuiles.indexed) ...[
              if (i > 0) const SizedBox(width: ecart),
              Expanded(child: t),
            ],
          ],
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, t) in tuiles.indexed) ...[
              if (i > 0) const SizedBox(width: ecart),
              SizedBox(width: minimum, child: t),
            ],
          ],
        ),
      );
    });
  }
}

class _Tuile extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String libelle;
  final int nombre;
  final bool actif;
  final VoidCallback onTap;

  const _Tuile({
    required this.icone,
    required this.couleur,
    required this.libelle,
    required this.nombre,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: actif ? AppColors.rouge.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: actif ? AppColors.rouge : AppColors.grisMedium,
          width: actif ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, size: 17, color: couleur),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$nombre',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.noir,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      libelle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                        color: actif ? AppColors.rouge : AppColors.grisDark,
                      ),
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

// ── Éléments communs ───────────────────────────────────────

class _Pastille extends StatelessWidget {
  final IconData icone;
  final String texte;
  final Color couleur;
  const _Pastille(this.icone, this.texte, this.couleur);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 13, color: couleur),
            const SizedBox(width: 4),
            Text(
              texte,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: couleur),
            ),
          ],
        ),
      );
}

class _BadgeType extends StatelessWidget {
  final MessageType type;
  const _BadgeType(this.type);

  @override
  Widget build(BuildContext context) =>
      _Pastille(_iconeType(type), libelleTypeMessage(type), _couleurType(type));
}

class _BadgeStatut extends StatelessWidget {
  final bool actif;
  const _BadgeStatut(this.actif);

  @override
  Widget build(BuildContext context) => actif
      ? const _Pastille(Icons.visibility_rounded, 'Visible', AppColors.fait)
      : const _Pastille(
          Icons.inventory_2_outlined, 'Archivé', AppColors.grisDark);
}

class _Auteur extends StatelessWidget {
  final MessageSemaine message;
  final bool avecDate;
  const _Auteur(this.message, {this.avecDate = true});

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Row(
      children: [
        AvatarProfil(
          proprietaire:
              ProprietairePhoto(TypeProprietairePhoto.employe, m.creePar),
          initiales: m.auteur.isEmpty ? '?' : m.auteur[0].toUpperCase(),
          rayon: 14,
          couleurFond: AppColors.rouge.withValues(alpha: 0.12),
          couleurTexte: AppColors.rouge,
          tailleTexte: 11,
          poidsTexte: FontWeight.bold,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            avecDate
                ? '${m.auteur} · ${_fmt.format(m.dateCreation.toLocal())}'
                : m.auteur,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.grisDark),
          ),
        ),
      ],
    );
  }
}

// ── Tableau ────────────────────────────────────────────────

const _styleEnTete = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.grisDark,
);

class _TableauMessages extends StatelessWidget {
  final List<MessageSemaine> lignes;
  final int premierNumero;
  final _Tri tri;
  final bool croissant;
  final ValueChanged<_Tri> onTrier;
  final ValueChanged<MessageSemaine> onOuvrir;
  final ValueChanged<MessageSemaine> onRepublier;
  final ValueChanged<MessageSemaine> onRetirer;

  const _TableauMessages({
    required this.lignes,
    required this.premierNumero,
    required this.tri,
    required this.croissant,
    required this.onTrier,
    required this.onOuvrir,
    required this.onRepublier,
    required this.onRetirer,
  });

  @override
  Widget build(BuildContext context) {
    Widget entete(String libelle, _Tri t) => _EnTeteTri(
          libelle: libelle,
          actif: tri == t,
          croissant: croissant,
          onTap: () => onTrier(t),
        );

    return CarteContenu(
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF7F8FA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                    width: 36, child: Text('N°', style: _styleEnTete)),
                const Expanded(
                    flex: 5, child: Text('Message', style: _styleEnTete)),
                const Expanded(
                    flex: 2, child: Text('Type', style: _styleEnTete)),
                Expanded(flex: 3, child: entete('Publié par', _Tri.auteur)),
                Expanded(flex: 2, child: entete('Publié le', _Tri.publication)),
                Expanded(flex: 2, child: entete('Affiché', _Tri.duree)),
                const Expanded(
                    flex: 2, child: Text('Statut', style: _styleEnTete)),
                const SizedBox(
                  width: 96,
                  child: Text('Actions',
                      textAlign: TextAlign.center, style: _styleEnTete),
                ),
              ],
            ),
          ),
          for (final (i, m) in lignes.indexed) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.grisMedium),
            _LigneMessage(
              message: m,
              numero: premierNumero + i,
              onOuvrir: () => onOuvrir(m),
              onRepublier: () => onRepublier(m),
              onRetirer: () => onRetirer(m),
            ),
          ],
        ],
      ),
    );
  }
}

class _EnTeteTri extends StatelessWidget {
  final String libelle;
  final bool actif;
  final bool croissant;
  final VoidCallback onTap;

  const _EnTeteTri({
    required this.libelle,
    required this.actif,
    required this.croissant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? AppColors.rouge : AppColors.grisDark;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(libelle,
                    overflow: TextOverflow.ellipsis,
                    style: _styleEnTete.copyWith(color: couleur)),
              ),
              const SizedBox(width: 4),
              Icon(
                !actif
                    ? Icons.swap_vert_rounded
                    : croissant
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                size: 14,
                color: couleur,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LigneMessage extends StatelessWidget {
  final MessageSemaine message;
  final int numero;
  final VoidCallback onOuvrir;
  final VoidCallback onRepublier;
  final VoidCallback onRetirer;

  const _LigneMessage({
    required this.message,
    required this.numero,
    required this.onOuvrir,
    required this.onRepublier,
    required this.onRetirer,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    const style = TextStyle(fontSize: 13, color: AppColors.grisDark);
    return Material(
      color: m.isActif
          ? AppColors.fait.withValues(alpha: 0.04)
          : Colors.transparent,
      child: InkWell(
        onTap: onOuvrir,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                  width: 36,
                  child: Text('$numero',
                      style: style.copyWith(color: AppColors.noir))),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    m.contenu,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(
                        color: AppColors.noir, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BadgeType(m.type),
                ),
              ),
              Expanded(flex: 3, child: _Auteur(m, avecDate: false)),
              Expanded(
                flex: 2,
                child:
                    Text(_fmt.format(m.dateCreation.toLocal()), style: style),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  m.isActif ? '${_duree(m)} (en cours)' : _duree(m),
                  style: style,
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BadgeStatut(m.isActif),
                ),
              ),
              SizedBox(
                width: 96,
                child: Center(
                  child: m.isActif
                      ? IconButton(
                          tooltip: 'Retirer du tableau de bord',
                          onPressed: onRetirer,
                          icon: const Icon(Icons.visibility_off_outlined,
                              color: _orange),
                        )
                      : IconButton(
                          tooltip: 'Republier',
                          onPressed: onRepublier,
                          icon: const Icon(Icons.replay_rounded,
                              color: AppColors.rouge),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grille ─────────────────────────────────────────────────

class _GrilleMessages extends StatelessWidget {
  final List<MessageSemaine> lignes;
  final ValueChanged<MessageSemaine> onOuvrir;
  final ValueChanged<MessageSemaine> onRepublier;
  final ValueChanged<MessageSemaine> onRetirer;

  const _GrilleMessages({
    required this.lignes,
    required this.onOuvrir,
    required this.onRepublier,
    required this.onRetirer,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      final colonnes = math.max(1, (c.maxWidth + ecart) ~/ (340 + ecart));
      final largeur = (c.maxWidth - ecart * (colonnes - 1)) / colonnes;
      return Wrap(
        spacing: ecart,
        runSpacing: ecart,
        children: [
          for (final m in lignes)
            SizedBox(
              width: largeur,
              child: _CarteMessage(
                message: m,
                onOuvrir: () => onOuvrir(m),
                onRepublier: () => onRepublier(m),
                onRetirer: () => onRetirer(m),
              ),
            ),
        ],
      );
    });
  }
}

class _CarteMessage extends StatelessWidget {
  final MessageSemaine message;
  final VoidCallback onOuvrir;
  final VoidCallback onRepublier;
  final VoidCallback onRetirer;

  const _CarteMessage({
    required this.message,
    required this.onOuvrir,
    required this.onRepublier,
    required this.onRetirer,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: m.isActif
              ? AppColors.fait.withValues(alpha: 0.5)
              : AppColors.grisMedium,
          width: m.isActif ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOuvrir,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.md, 12, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _BadgeType(m.type),
                    const SizedBox(width: 6),
                    _BadgeStatut(m.isActif),
                    const Spacer(),
                    m.isActif
                        ? IconButton(
                            tooltip: 'Retirer du tableau de bord',
                            onPressed: onRetirer,
                            icon: const Icon(Icons.visibility_off_outlined,
                                size: 20, color: _orange),
                          )
                        : IconButton(
                            tooltip: 'Republier',
                            onPressed: onRepublier,
                            icon: const Icon(Icons.replay_rounded,
                                size: 20, color: AppColors.rouge),
                          ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    m.contenu,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: AppColors.noir),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _Auteur(m),
                ),
                const SizedBox(height: 6),
                Text(
                  m.isActif
                      ? 'Affiché depuis ${_duree(m)}'
                      : 'Affiché ${_duree(m)}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.grisText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Détail ─────────────────────────────────────────────────

class _DetailMessage extends StatelessWidget {
  final MessageSemaine message;
  final VoidCallback onRepublier;
  final VoidCallback onRetirer;

  const _DetailMessage({
    required this.message,
    required this.onRepublier,
    required this.onRetirer,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    const style = TextStyle(fontSize: 13.5, color: AppColors.noir);
    Widget info(IconData icone, String libelle, Widget valeur) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, size: 17, color: AppColors.grisText),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                child: Text(libelle,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.grisText)),
              ),
              Expanded(child: valeur),
            ],
          ),
        );

    return DialogueApp(
      titre: 'Message de la semaine',
      largeur: 540,
      libelleAction: 'Fermer',
      onAction: () => Navigator.of(context).pop(),
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.grisLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.grisMedium),
            ),
            child: SelectableText(
              m.contenu,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: AppColors.noir),
            ),
          ),
          const SizedBox(height: 16),
          info(
              Icons.category_outlined,
              'Type',
              Align(
                  alignment: Alignment.centerLeft, child: _BadgeType(m.type))),
          info(
              Icons.flag_outlined,
              'Statut',
              Align(
                  alignment: Alignment.centerLeft,
                  child: _BadgeStatut(m.isActif))),
          info(Icons.person_outline_rounded, 'Publié par',
              Text(m.auteur, style: style)),
          info(Icons.send_outlined, 'Publié le',
              Text(_fmt.format(m.dateCreation.toLocal()), style: style)),
          if (m.dateDesactivation != null)
            info(
                Icons.visibility_off_outlined,
                'Retiré le',
                Text(_fmt.format(m.dateDesactivation!.toLocal()),
                    style: style)),
          info(
            Icons.timelapse_rounded,
            'Affiché',
            Text(m.isActif ? '${_duree(m)} (en cours)' : _duree(m),
                style: style),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: m.isActif
                ? OutlinedButton.icon(
                    onPressed: onRetirer,
                    icon: const Icon(Icons.visibility_off_outlined, size: 17),
                    label: const Text('Retirer du tableau de bord'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _orange,
                      side: const BorderSide(color: Color(0xFFFFCC9B)),
                      shape: const StadiumBorder(),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: onRepublier,
                    icon: const Icon(Icons.replay_rounded, size: 17),
                    label: const Text('Republier ce message'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rouge,
                      side: const BorderSide(color: AppColors.rouge),
                      shape: const StadiumBorder(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Confirmation (retirer / republier) ─────────────────────

class _ConfirmationDialog extends StatefulWidget {
  final String titre;
  final MessageSemaine message;
  final String texte;
  final String libelleAction;
  final Future<bool> Function() onConfirm;

  const _ConfirmationDialog({
    required this.titre,
    required this.message,
    required this.texte,
    required this.libelleAction,
    required this.onConfirm,
  });

  @override
  State<_ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<_ConfirmationDialog> {
  bool _enCours = false;

  Future<void> _confirmer() async {
    setState(() => _enCours = true);
    final ok = await widget.onConfirm();
    if (mounted) Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    return DialogueApp(
      titre: widget.titre,
      largeur: 460,
      libelleAction: widget.libelleAction,
      libelleSecondaire: 'Annuler',
      enCours: _enCours,
      onAction: _confirmer,
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.grisLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.grisMedium),
            ),
            child: Text(
              widget.message.contenu,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: AppColors.noir),
            ),
          ),
          const SizedBox(height: 12),
          Text(widget.texte,
              style: const TextStyle(
                  fontSize: 13, height: 1.4, color: AppColors.grisDark)),
        ],
      ),
    );
  }
}

// ── Nouveau message ────────────────────────────────────────

class _CreationDialog extends StatefulWidget {
  /// Message visible actuellement, qui sera remplacé.
  final MessageSemaine? remplace;
  final Future<bool> Function(String contenu, MessageType type) onConfirm;

  const _CreationDialog({required this.remplace, required this.onConfirm});

  @override
  State<_CreationDialog> createState() => _CreationDialogState();
}

class _CreationDialogState extends State<_CreationDialog> {
  final _controller = TextEditingController();
  MessageType _type = MessageType.personnalise;
  String? _fete;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _contenu => switch (_type) {
        MessageType.personnalise => _controller.text.trim(),
        MessageType.automatique => getMessageAutomatique(),
        MessageType.fete => _fete ?? '',
      };

  bool get _valide => _contenu.isNotEmpty;

  Future<void> _publier() async {
    if (!_valide || _enCours) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    final ok = await widget.onConfirm(_contenu, _type);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _enCours = false;
        _erreur = 'La publication n’a pas abouti. Vérifiez votre connexion '
            'et réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = estCompact(context);
    Widget choix(MessageType t, String titre, String description) => _Choix(
          icone: _iconeType(t),
          couleur: _couleurType(t),
          titre: titre,
          description: description,
          selectionne: _type == t,
          onTap: _enCours
              ? null
              : () => setState(() {
                    _type = t;
                    _erreur = null;
                  }),
        );
    final choixTypes = [
      choix(MessageType.personnalise, 'Libre', 'Votre propre texte'),
      choix(MessageType.automatique, 'Suggéré', 'Le message du jour'),
      choix(MessageType.fete, 'Fête', 'Un message prêt à publier'),
    ];

    return DialogueApp(
      titre: 'Nouveau message',
      largeur: 580,
      libelleAction: 'Publier',
      libelleSecondaire: 'Annuler',
      enCours: _enCours,
      onFermer: () => Navigator.pop(context, false),
      onSecondaire: () => Navigator.pop(context, false),
      onAction: _valide ? _publier : null,
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Type de message',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.noir)),
          const SizedBox(height: 8),
          if (compact)
            Column(
              children: [
                for (final (i, c) in choixTypes.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  c,
                ],
              ],
            )
          else
            Row(
              children: [
                for (final (i, c) in choixTypes.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: c),
                ],
              ],
            ),
          const SizedBox(height: 18),
          switch (_type) {
            MessageType.personnalise => TextField(
                controller: _controller,
                enabled: !_enCours,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 280,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Votre message',
                  hintText: 'Ex. Merci à toute l’équipe pour votre travail…',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    borderSide:
                        const BorderSide(color: AppColors.rouge, width: 1.5),
                  ),
                ),
              ),
            MessageType.automatique => const SizedBox.shrink(),
            MessageType.fete => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final f in messagesFete)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _OptionFete(
                        texte: f,
                        selectionne: _fete == f,
                        onTap:
                            _enCours ? null : () => setState(() => _fete = f),
                      ),
                    ),
                ],
              ),
          },
          if (_valide) ...[
            const SizedBox(height: 12),
            _Apercu(contenu: _contenu, type: _type),
          ],
          if (widget.remplace != null) ...[
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.grisDark),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Le message visible actuellement sera remplacé et passera '
                    'dans l’historique.',
                    style: TextStyle(fontSize: 12, color: AppColors.grisDark),
                  ),
                ),
              ],
            ),
          ],
          if (_erreur != null) ...[
            const SizedBox(height: 12),
            Text(_erreur!,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.refus,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}

class _Choix extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String titre;
  final String description;
  final bool selectionne;
  final VoidCallback? onTap;

  const _Choix({
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.description,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selectionne
          ? AppColors.rouge.withValues(alpha: 0.07)
          : const Color(0xFFF7F7F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        side: BorderSide(
          color: selectionne ? AppColors.rouge : const Color(0xFFE8E8E8),
          width: selectionne ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icone, size: 20, color: couleur),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: selectionne
                                ? AppColors.rouge
                                : AppColors.noir)),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.grisText)),
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

class _OptionFete extends StatelessWidget {
  final String texte;
  final bool selectionne;
  final VoidCallback? onTap;

  const _OptionFete({
    required this.texte,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selectionne
              ? AppColors.rouge.withValues(alpha: 0.07)
              : const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selectionne ? AppColors.rouge : const Color(0xFFE8E8E8),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selectionne
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: selectionne ? AppColors.rouge : AppColors.grisText,
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(texte, style: const TextStyle(fontSize: 13.5))),
          ],
        ),
      ),
    );
  }
}

/// Ce que l'équipe verra sur son tableau de bord.
class _Apercu extends StatelessWidget {
  final String contenu;
  final MessageType type;
  const _Apercu({required this.contenu, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.rouge.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_iphone_rounded,
                  size: 15, color: AppColors.rouge),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Aperçu sur le tableau de bord de l’équipe',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.rouge),
                ),
              ),
              _BadgeType(type),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            contenu,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: AppColors.noir),
          ),
        ],
      ),
    );
  }
}

// ── État vide ──────────────────────────────────────────────

class _EtatVide extends StatelessWidget {
  final String titre;
  final String texte;
  final VoidCallback? onReinitialiser;

  const _EtatVide({
    required this.titre,
    required this.texte,
    this.onReinitialiser,
  });

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.lg),
            decoration: BoxDecoration(
              color: AppColors.rouge.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_rounded,
                size: 44, color: AppColors.rouge),
          ),
          const SizedBox(height: AppSizes.md),
          Text(titre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.noir)),
          const SizedBox(height: AppSizes.xs),
          Text(texte,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grisText, fontSize: 13)),
          if (onReinitialiser != null) ...[
            const SizedBox(height: AppSizes.md),
            OutlinedButton.icon(
              onPressed: onReinitialiser,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Réinitialiser les filtres'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rouge,
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
