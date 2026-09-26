import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reception/presentation/reception_sections.dart'
    show receptionMessagesRoute;
import '../../domain/entities/notification.dart';
import '../providers/notifications_provider.dart';
import 'package:cleanops/core/widgets/espace_barre_mobile.dart';
import 'package:cleanops/core/widgets/notification_app.dart';

/// Centre de notifications, commun à tous les profils : filtres « Toutes /
/// Non lues » et par catégorie, regroupement par jour, et pour chaque
/// notification lecture, retour en « non lue » et suppression (menu ⋮ ou
/// glissement sur téléphone).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _nonLues = false;

  /// Catégorie filtrée (`null` : toutes).
  NotificationCategory? _categorie;

  NotificationsNotifier get _notifier =>
      ref.read(notificationsNotifierProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsNotifierProvider);
    final compact = estCompact(context);
    final marge = compact ? 12.0 : 24.0;

    final toutes = state.notifications;
    final nonLues = state.unreadCount;
    // Catégories réellement présentes, dans l'ordre de l'énumération.
    final categories = [
      for (final c in NotificationCategory.values)
        if (toutes.any((n) => n.category == c)) c,
    ];
    final categorie = categories.contains(_categorie) ? _categorie : null;
    final visibles = [
      for (final n in toutes)
        if ((!_nonLues || !n.isRead) &&
            (categorie == null || n.category == categorie))
          n,
    ];

    return PageAvecEnTete(
      chargement: state.isLoading,
      enTete: EnTetePage(
        icone: Icons.notifications_rounded,
        titre: 'Notifications',
        sousTitre: nonLues == 0
            ? 'Vous êtes à jour'
            : '$nonLues non lue${nonLues > 1 ? 's' : ''} sur ${toutes.length}',
      ),
      contenu: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BarreSection(
                  titre: '${_nonLues ? 'Non lues' : 'Toutes'} '
                      '(${visibles.length})',
                  onRetour: _retour,
                  filtres: [
                    FiltreSection(
                      icone: Icons.inbox_outlined,
                      infoBulle: 'Toutes les notifications',
                      actif: !_nonLues,
                      onTap: () => setState(() => _nonLues = false),
                    ),
                    FiltreSection(
                      icone: Icons.mark_email_unread_outlined,
                      infoBulle: 'Non lues',
                      actif: _nonLues,
                      pastille: nonLues > 0,
                      onTap: () => setState(() => _nonLues = true),
                    ),
                  ],
                  actions: [
                    ActionSection(
                      icone: Icons.done_all_rounded,
                      infoBulle: 'Tout marquer comme lu',
                      onPressed: nonLues > 0 ? _toutLire : null,
                    ),
                    ActionSection(
                      icone: Icons.refresh_rounded,
                      infoBulle: 'Actualiser',
                      onPressed: state.isLoading ? null : _notifier.load,
                    ),
                  ],
                ),
                if (categories.length > 1) ...[
                  const SizedBox(height: AppSizes.md),
                  _FiltresCategorie(
                    categories: categories,
                    active: categorie,
                    compteurs: {
                      for (final c in categories)
                        c: toutes
                            .where((n) =>
                                n.category == c && (!_nonLues || !n.isRead))
                            .length,
                    },
                    onChanged: (c) => setState(() => _categorie = c),
                  ),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: AppSizes.md),
                  const _ErreurActualisation(),
                ],
                const SizedBox(height: AppSizes.md),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.rouge,
                    onRefresh: _notifier.load,
                    child: _Liste(
                      chargementInitial: state.isLoading && toutes.isEmpty,
                      notifications: visibles,
                      vide: _messageVide(categorie),
                      routeDe: _routeFor,
                      onOuvrir: _ouvrir,
                      onBasculerLecture: _basculerLecture,
                      onSupprimer: _supprimer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({String titre, String detail}) _messageVide(NotificationCategory? c) {
    if (_nonLues) {
      return (
        titre: 'Aucune notification non lue',
        detail: 'Vous avez pris connaissance de toutes les informations.',
      );
    }
    if (c != null) {
      return (
        titre: 'Aucune notification « ${_libelleCategorie(c)} »',
        detail: 'Choisissez une autre catégorie pour voir le reste.',
      );
    }
    return (
      titre: 'Aucune notification pour le moment',
      detail: 'Les nouvelles informations importantes apparaîtront ici.',
    );
  }

  void _retour() {
    final employee = ref.read(employeeCourantProvider);
    context.backOrHome(
      employee == null ? AppRoutes.employeeDashboard : accueilDe(employee),
    );
  }

  Future<void> _toutLire() async {
    final ok = await _notifier.markAllAsRead();
    if (!mounted) return;
    ok
        ? NotificationApp.succes(
            context, 'Toutes les notifications ont été marquées comme lues.')
        : NotificationApp.erreur(
            context, 'Nous n’avons pas pu mettre à jour les notifications.');
  }

  Future<void> _ouvrir(AppNotification notification) async {
    final ok = await _notifier.markAsRead(notification.id);
    if (!mounted) return;
    if (!ok) {
      NotificationApp.erreur(
        context,
        'La notification reste disponible. Sa lecture n’a pas pu être '
        'enregistrée.',
      );
      return;
    }
    final route = _routeFor(notification);
    if (route != null) context.go(route);
  }

  Future<void> _basculerLecture(AppNotification notification) async {
    final ok = notification.isRead
        ? await _notifier.markAsUnread(notification.id)
        : await _notifier.markAsRead(notification.id);
    if (!mounted || ok) return;
    NotificationApp.erreur(
        context, 'Nous n’avons pas pu mettre à jour la notification.');
  }

  Future<void> _supprimer(AppNotification notification) async {
    final ok = await _notifier.delete(notification.id);
    if (!mounted) return;
    ok
        ? NotificationApp.succes(context, 'Notification supprimée.')
        : NotificationApp.erreur(
            context, 'Nous n’avons pas pu supprimer la notification.');
  }

  String? _routeFor(AppNotification notification) {
    final profil = ref.read(employeeCourantProvider)?.profil;

    // Message transmis par la Réception : la Réception retrouve la liste de ses
    // messages, le responsable l'onglet « Messages de la réception ».
    if (notification.type == 'MessageReception') {
      return switch (profil) {
        ProfilAcces.reception => receptionMessagesRoute,
        ProfilAcces.responsable => AppRoutes.demandesResidentsMessages,
        _ => null,
      };
    }
    // Le reste des écrans est fermé à la Réception.
    if (profil == ProfilAcces.reception) return null;

    return switch (notification.category) {
      NotificationCategory.absence => AppRoutes.presences,
      NotificationCategory.demande => AppRoutes.demandesResidents,
      NotificationCategory.transfert => AppRoutes.tachesDisponibles,
      NotificationCategory.planning => AppRoutes.planning,
      NotificationCategory.message => AppRoutes.memo,
      NotificationCategory.general => null,
    };
  }
}

// ── Filtres par catégorie ─────────────────────────────────

class _FiltresCategorie extends StatelessWidget {
  const _FiltresCategorie({
    required this.categories,
    required this.active,
    required this.compteurs,
    required this.onChanged,
  });

  final List<NotificationCategory> categories;
  final NotificationCategory? active;
  final Map<NotificationCategory, int> compteurs;
  final ValueChanged<NotificationCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget pastille({
      required String libelle,
      required bool actif,
      required VoidCallback onTap,
      IconData? icone,
      Color? couleur,
    }) {
      final c = actif ? Colors.white : (couleur ?? AppColors.noir);
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: actif ? AppColors.rouge : Colors.white,
          shape: StadiumBorder(
            side: BorderSide(
                color: actif ? AppColors.rouge : AppColors.grisMedium),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icone != null) ...[
                    Icon(icone, size: 16, color: c),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    libelle,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: actif ? Colors.white : AppColors.noir,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          pastille(
            libelle: 'Toutes catégories',
            actif: active == null,
            onTap: () => onChanged(null),
          ),
          for (final c in categories)
            pastille(
              libelle: '${_libelleCategorie(c)} (${compteurs[c] ?? 0})',
              icone: _iconeCategorie(c),
              couleur: _couleurCategorie(c),
              actif: active == c,
              onTap: () => onChanged(active == c ? null : c),
            ),
        ],
      ),
    );
  }
}

// ── Liste regroupée par jour ──────────────────────────────

class _Liste extends StatelessWidget {
  const _Liste({
    required this.chargementInitial,
    required this.notifications,
    required this.vide,
    required this.routeDe,
    required this.onOuvrir,
    required this.onBasculerLecture,
    required this.onSupprimer,
  });

  final bool chargementInitial;
  final List<AppNotification> notifications;
  final ({String titre, String detail}) vide;
  final String? Function(AppNotification) routeDe;
  final ValueChanged<AppNotification> onOuvrir;
  final ValueChanged<AppNotification> onBasculerLecture;
  final ValueChanged<AppNotification> onSupprimer;

  @override
  Widget build(BuildContext context) {
    final padding =
        const EdgeInsets.only(bottom: AppSizes.lg).plusBarre(context);

    if (chargementInitial) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: const [_Squelette()],
      );
    }
    if (notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [_EtatVide(titre: vide.titre, detail: vide.detail)],
      );
    }

    final groupes = _grouperParJour(notifications);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        for (final (i, groupe) in groupes.indexed) ...[
          if (i > 0) const SizedBox(height: AppSizes.lg),
          _TitreGroupe(titre: groupe.titre, nombre: groupe.items.length),
          const SizedBox(height: AppSizes.sm),
          CarteContenu(
            child: Column(
              children: [
                for (final (j, n) in groupe.items.indexed) ...[
                  if (j > 0)
                    const Divider(height: 1, color: AppColors.grisMedium),
                  _TuileNotification(
                    key: ValueKey(n.id),
                    notification: n,
                    ouvrable: routeDe(n) != null,
                    onOuvrir: () => onOuvrir(n),
                    onBasculerLecture: () => onBasculerLecture(n),
                    onSupprimer: () => onSupprimer(n),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

typedef _Groupe = ({String titre, List<AppNotification> items});

/// « Aujourd'hui », « Hier », « Cette semaine », « Plus anciennes » : la
/// liste arrive déjà triée de la plus récente à la plus ancienne.
List<_Groupe> _grouperParJour(List<AppNotification> notifications) {
  final maintenant = DateTime.now();
  final aujourdhui =
      DateTime(maintenant.year, maintenant.month, maintenant.day);
  String titreDe(DateTime date) {
    final local = date.toLocal();
    final jour = DateTime(local.year, local.month, local.day);
    final ecart = aujourdhui.difference(jour).inDays;
    if (ecart <= 0) return 'Aujourd’hui';
    if (ecart == 1) return 'Hier';
    if (ecart < 7) return 'Cette semaine';
    return 'Plus anciennes';
  }

  final groupes = <_Groupe>[];
  for (final n in notifications) {
    final titre = titreDe(n.sentAt);
    if (groupes.isEmpty || groupes.last.titre != titre) {
      groupes.add((titre: titre, items: [n]));
    } else {
      groupes.last.items.add(n);
    }
  }
  return groupes;
}

class _TitreGroupe extends StatelessWidget {
  const _TitreGroupe({required this.titre, required this.nombre});

  final String titre;
  final int nombre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '${titre.toUpperCase()} · $nombre',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.grisDark,
        ),
      ),
    );
  }
}

// ── Une notification ──────────────────────────────────────

enum _Action { lecture, suppression }

class _TuileNotification extends StatelessWidget {
  const _TuileNotification({
    super.key,
    required this.notification,
    required this.ouvrable,
    required this.onOuvrir,
    required this.onBasculerLecture,
    required this.onSupprimer,
  });

  final AppNotification notification;

  /// La notification mène à un écran (flèche à droite).
  final bool ouvrable;
  final VoidCallback onOuvrir;
  final VoidCallback onBasculerLecture;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final couleur = _couleurCategorie(n.category);
    final nonLue = !n.isRead;

    final tuile = Material(
      color: nonLue ? AppColors.rouge.withValues(alpha: .04) : Colors.white,
      child: InkWell(
        onTap: onOuvrir,
        child: Container(
          // Liseré bleu à gauche : repère visuel des non lues.
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: nonLue ? AppColors.rouge : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(13, 14, 4, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(_iconeCategorie(n.category), color: couleur, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _libelleCategorie(n.category),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: couleur,
                            ),
                          ),
                        ),
                        const Text(
                          '  ·  ',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.grisText),
                        ),
                        Text(
                          _heure(n.sentAt),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.grisText),
                        ),
                        if (nonLue) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.rouge,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.message,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.noir,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: nonLue ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (ouvrable)
                const Padding(
                  padding: EdgeInsets.only(top: 10, left: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      color: AppColors.grisText, size: 20),
                ),
              PopupMenuButton<_Action>(
                tooltip: 'Options',
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.grisDark, size: 20),
                onSelected: (a) => switch (a) {
                  _Action.lecture => onBasculerLecture(),
                  _Action.suppression => onSupprimer(),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _Action.lecture,
                    child: _LigneMenu(
                      icone: nonLue
                          ? Icons.drafts_outlined
                          : Icons.mark_email_unread_outlined,
                      libelle: nonLue
                          ? 'Marquer comme lue'
                          : 'Marquer comme non lue',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _Action.suppression,
                    child: _LigneMenu(
                      icone: Icons.delete_outline_rounded,
                      libelle: 'Supprimer',
                      couleur: AppColors.aVerifier,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Glisser vers la droite : lue / non lue ; vers la gauche : supprimer.
    return Dismissible(
      key: ValueKey('glisser-${n.id}'),
      background: _FondGlissement(
        alignement: Alignment.centerLeft,
        couleur: AppColors.rouge,
        icone:
            nonLue ? Icons.drafts_outlined : Icons.mark_email_unread_outlined,
        libelle: nonLue ? 'Lue' : 'Non lue',
      ),
      secondaryBackground: const _FondGlissement(
        alignement: Alignment.centerRight,
        couleur: AppColors.aVerifier,
        icone: Icons.delete_outline_rounded,
        libelle: 'Supprimer',
      ),
      confirmDismiss: (sens) async {
        if (sens == DismissDirection.startToEnd) {
          onBasculerLecture();
          return false; // la notification reste dans la liste
        }
        return true;
      },
      onDismissed: (_) => onSupprimer(),
      child: tuile,
    );
  }
}

class _LigneMenu extends StatelessWidget {
  const _LigneMenu({required this.icone, required this.libelle, this.couleur});

  final IconData icone;
  final String libelle;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icone, size: 19, color: couleur ?? AppColors.rouge),
          const SizedBox(width: 12),
          Text(libelle, style: TextStyle(color: couleur)),
        ],
      );
}

class _FondGlissement extends StatelessWidget {
  const _FondGlissement({
    required this.alignement,
    required this.couleur,
    required this.icone,
    required this.libelle,
  });

  final Alignment alignement;
  final Color couleur;
  final IconData icone;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: couleur,
      alignment: alignement,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            libelle,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── États ─────────────────────────────────────────────────

class _EtatVide extends StatelessWidget {
  const _EtatVide({required this.titre, required this.detail});

  final String titre;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.rouge.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 32, color: AppColors.rouge),
          ),
          const SizedBox(height: 14),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grisDark, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _ErreurActualisation extends StatelessWidget {
  const _ErreurActualisation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Color(0xFFC2410C)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Les notifications n’ont pas pu être actualisées. Vous pouvez '
              'réessayer sans risque.',
              style: TextStyle(
                color: Color(0xFF9A3412),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Squelette extends StatelessWidget {
  const _Squelette();

  @override
  Widget build(BuildContext context) {
    Widget barre(double largeur, double hauteur) => Container(
          width: largeur,
          height: hauteur,
          decoration: BoxDecoration(
            color: const Color(0xFFE9EAF0),
            borderRadius: BorderRadius.circular(4),
          ),
        );
    return CarteContenu(
      child: Column(
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.grisMedium),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE9EAF0),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        barre(110, 11),
                        const SizedBox(height: 8),
                        barre(double.infinity, 13),
                        const SizedBox(height: 6),
                        barre(180, 13),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Catégories ────────────────────────────────────────────

String _libelleCategorie(NotificationCategory c) => switch (c) {
      NotificationCategory.planning => 'Planning',
      NotificationCategory.absence => 'Présence',
      NotificationCategory.demande => 'Demande',
      NotificationCategory.transfert => 'Tâche disponible',
      NotificationCategory.message => 'Message',
      NotificationCategory.general => 'Information',
    };

Color _couleurCategorie(NotificationCategory c) => switch (c) {
      NotificationCategory.planning => AppColors.rouge,
      NotificationCategory.absence => const Color(0xFFC2410C),
      NotificationCategory.demande => const Color(0xFF1769AA),
      NotificationCategory.transfert => const Color(0xFF00796B),
      NotificationCategory.message => const Color(0xFF7B1FA2),
      NotificationCategory.general => const Color(0xFF667085),
    };

IconData _iconeCategorie(NotificationCategory c) => switch (c) {
      NotificationCategory.planning => Icons.calendar_month_outlined,
      NotificationCategory.absence => Icons.person_off_outlined,
      NotificationCategory.demande => Icons.inbox_outlined,
      NotificationCategory.transfert => Icons.swap_horiz_rounded,
      NotificationCategory.message => Icons.chat_bubble_outline_rounded,
      NotificationCategory.general => Icons.notifications_none_rounded,
    };

/// Heure d'envoi, adaptée au groupe : relative dans l'heure, heure seule
/// aujourd'hui, « Hier, 14:30 », jour de la semaine, puis date complète.
String _heure(DateTime date) {
  final local = date.toLocal();
  final maintenant = DateTime.now();
  final ecart = maintenant.difference(local);
  if (!ecart.isNegative && ecart.inMinutes < 1) return 'À l’instant';
  if (!ecart.isNegative && ecart.inHours < 1) {
    return 'Il y a ${ecart.inMinutes} min';
  }
  final aujourdhui =
      DateTime(maintenant.year, maintenant.month, maintenant.day);
  final jours = aujourdhui
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;
  final heure = DateFormat('HH:mm').format(local);
  if (jours <= 0) return heure;
  if (jours == 1) return 'Hier, $heure';
  if (jours < 7) return '${DateFormat('EEEE', 'fr_FR').format(local)}, $heure';
  return DateFormat('dd/MM/yyyy', 'fr_FR').format(local);
}
