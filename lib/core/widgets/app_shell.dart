import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'app_top_bar.dart';
import '../../features/auth/domain/entities/employee.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/photo_profil/domain/photo_profil_models.dart';
import '../../features/photo_profil/presentation/widgets/avatar_profil.dart';
import '../../features/reception/presentation/reception_sections.dart';
import '../../features/resident_espace/presentation/providers/resident_espace_provider.dart';

// ── Dimensions sidebar ────────────────────────────────────
const double _kSidebarExpanded = 280;
const double _kSidebarCollapsed = 68;
const Duration _kSidebarDuration = Duration(milliseconds: 220);

// ─────────────────────────────────────────────────────────
// Modèles
// ─────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String shortLabel;
  final String route;
  final bool mobilePrimary;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.shortLabel,
    required this.route,
    this.mobilePrimary = false,
  });
}

/// Groupe de destinations. [label] nul → liste à plat, sans en-tête ni pli.
/// Sinon, section repliable du menu latéral (une seule ouverte à la fois).
class _NavGroup {
  final String? label;
  final IconData? icon;
  final List<_NavItem> items;

  const _NavGroup({this.label, this.icon, required this.items});
}

/// Section « Accueil » du menu latéral : elle porte le tableau de bord quand le
/// menu est organisé en sections.
const String _kAccueil = 'Accueil';

// ─────────────────────────────────────────────────────────
// Préposée — famille "Mon travail" / "Équipe"
// ─────────────────────────────────────────────────────────

const _NavItem _preposeeDashboard = _NavItem(
  icon: Icons.home_outlined,
  activeIcon: Icons.home_rounded,
  label: 'Tableau de bord',
  shortLabel: 'Accueil',
  route: '/dashboard',
);

const List<_NavGroup> _preposeeGroups = [
  _NavGroup(label: 'Mon travail', icon: Icons.work_rounded, items: [
    _NavItem(
      icon: Icons.today_outlined,
      activeIcon: Icons.today_rounded,
      label: 'Ma Journée',
      shortLabel: 'Journée',
      route: '/journee',
      mobilePrimary: true,
    ),
    _NavItem(
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Planning',
      shortLabel: 'Planning',
      route: '/planning',
      mobilePrimary: true,
    ),
    _NavItem(
      icon: Icons.assignment_ind_outlined,
      activeIcon: Icons.assignment_ind_rounded,
      label: 'Tâches disponibles',
      shortLabel: 'Dispo.',
      route: '/taches-disponibles',
    ),
    _NavItem(
      icon: Icons.home_work_outlined,
      activeIcon: Icons.home_work_rounded,
      label: 'Aires communes',
      shortLabel: 'Communes',
      route: '/aire-commune',
    ),
  ]),
  _NavGroup(label: 'Équipe', icon: Icons.groups_rounded, items: [
    _NavItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Chat Équipe',
      shortLabel: 'Chat',
      route: '/chat',
      mobilePrimary: true,
    ),
    _NavItem(
      icon: Icons.sticky_note_2_outlined,
      activeIcon: Icons.sticky_note_2_rounded,
      label: 'Mémo',
      shortLabel: 'Mémo',
      route: '/memo',
    ),
    _NavItem(
      icon: Icons.event_note_outlined,
      activeIcon: Icons.event_note_rounded,
      label: 'Mes demandes',
      shortLabel: 'Demandes',
      route: '/mes-demandes-equipe',
    ),
  ]),
];

// ─────────────────────────────────────────────────────────
// Responsable — famille "Opérations" / "Équipe" / "Résidence"
// ─────────────────────────────────────────────────────────

const _NavItem _responsableDashboard = _NavItem(
  icon: Icons.dashboard_outlined,
  activeIcon: Icons.dashboard_rounded,
  label: 'Tableau de bord',
  shortLabel: 'Accueil',
  route: '/employeur',
);

const List<_NavGroup> _responsableGroups = [
  _NavGroup(label: 'Opérations', icon: Icons.fact_check_rounded, items: [
    _NavItem(
      icon: Icons.checklist_rounded,
      activeIcon: Icons.checklist_rounded,
      label: 'Progression du jour',
      shortLabel: 'Jour',
      route: '/progression-jour',
    ),
    _NavItem(
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Planning',
      shortLabel: 'Planning',
      route: '/planning',
      mobilePrimary: true,
    ),
    _NavItem(
      icon: Icons.person_off_outlined,
      activeIcon: Icons.person_off_rounded,
      label: 'Absences',
      shortLabel: 'Absences',
      route: '/presences',
    ),
    _NavItem(
      icon: Icons.home_work_outlined,
      activeIcon: Icons.home_work_rounded,
      label: 'Aires communes',
      shortLabel: 'Communes',
      route: '/aire-commune',
    ),
  ]),
  _NavGroup(label: 'Équipe', icon: Icons.groups_rounded, items: [
    _NavItem(
      icon: Icons.group_outlined,
      activeIcon: Icons.group_rounded,
      label: 'Employé(e)s',
      shortLabel: 'Équipe',
      route: '/employes',
      mobilePrimary: true,
    ),
    _NavItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Chat Équipe',
      shortLabel: 'Chat',
      route: '/chat',
      mobilePrimary: true,
    ),
    _NavItem(
      icon: Icons.sticky_note_2_outlined,
      activeIcon: Icons.sticky_note_2_rounded,
      label: 'Mémo',
      shortLabel: 'Mémo',
      route: '/memo',
    ),
    _NavItem(
      icon: Icons.event_note_outlined,
      activeIcon: Icons.event_note_rounded,
      label: 'Demandes équipe',
      shortLabel: 'Demandes éq.',
      route: '/demandes/equipe',
    ),
  ]),
  _NavGroup(label: 'Résidence', icon: Icons.apartment_rounded, items: [
    _NavItem(
      icon: Icons.apartment_outlined,
      activeIcon: Icons.apartment_rounded,
      label: 'Appartements',
      shortLabel: 'Appts',
      route: '/appartements',
    ),
    _NavItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Résidents',
      shortLabel: 'Résidents',
      route: '/residents',
    ),
    _NavItem(
      icon: Icons.inbox_outlined,
      activeIcon: Icons.inbox_rounded,
      label: 'Demandes résidents',
      shortLabel: 'Demandes rés.',
      route: '/demandes/residents',
    ),
    _NavItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'Statistiques',
      shortLabel: 'Stats',
      route: '/statistiques',
    ),
    _NavItem(
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign_rounded,
      label: 'Messages semaine',
      shortLabel: 'Messages',
      route: '/messages-semaine',
    ),
  ]),
];

// ─────────────────────────────────────────────────────────
// Résident — liste à plat (peu de destinations)
// ─────────────────────────────────────────────────────────

const _NavItem _residentDashboard = _NavItem(
  icon: Icons.home_outlined,
  activeIcon: Icons.home_rounded,
  label: 'Mon espace',
  shortLabel: 'Accueil',
  route: '/resident',
  mobilePrimary: true,
);

const List<_NavGroup> _residentGroups = [
  _NavGroup(items: [
    _NavItem(
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Mon calendrier',
      shortLabel: 'Calendrier',
      route: '/resident/calendrier',
      mobilePrimary: true,
    ),
    _NavItem(
      icon: Icons.inbox_outlined,
      activeIcon: Icons.inbox_rounded,
      label: 'Mes demandes',
      shortLabel: 'Demandes',
      route: '/resident/demandes',
      mobilePrimary: true,
    ),
    _NavItem(
      icon: Icons.person_outlined,
      activeIcon: Icons.person_rounded,
      label: 'Mon profil',
      shortLabel: 'Profil',
      route: '/resident/profil',
      mobilePrimary: true,
    ),
  ]),
];

// ─────────────────────────────────────────────────────────
// Réception — tableau de bord + les 5 sections de sa vue
// ─────────────────────────────────────────────────────────

const _NavItem _receptionDashboard = _NavItem(
  icon: Icons.dashboard_outlined,
  activeIcon: Icons.dashboard_rounded,
  label: 'Tableau de bord',
  shortLabel: 'Accueil',
  route: receptionAccueilRoute,
);

// Construits depuis `receptionSections` (source unique des libellés et des
// routes, partagée avec le tableau de bord et le routeur).
final List<_NavGroup> _receptionGroups = [
  _NavGroup(items: [
    for (final s in receptionSections)
      _NavItem(
        icon: s.icon,
        activeIcon: s.iconActive,
        label: s.titre,
        shortLabel: s.libelleCourt,
        route: s.route,
        mobilePrimary: true,
      ),
  ]),
];

// ─────────────────────────────────────────────────────────
// Helpers — dérivation des items mobiles
// ─────────────────────────────────────────────────────────

List<_NavItem> _allItems(List<_NavGroup> groups) =>
    groups.expand((g) => g.items).toList();

List<_NavItem> _mobilePrimary(_NavItem dashboard, List<_NavGroup> groups) => [
      dashboard,
      ..._allItems(groups).where((i) => i.mobilePrimary),
    ];

List<_NavGroup> _mobileOverflowGroups(List<_NavGroup> groups) => groups
    .map((g) => _NavGroup(
        label: g.label, items: g.items.where((i) => !i.mobilePrimary).toList()))
    .where((g) => g.items.isNotEmpty)
    .toList();

// ─────────────────────────────────────────────────────────
// AppShell
// ─────────────────────────────────────────────────────────

/// Écran de refus affiché à la place de toute page pour un profil sans accès
/// (la Réception hors de son écran d'accueil et de ses 5 sections). Ne montre
/// aucune donnée.
class _AccesNonDisponible extends StatelessWidget {
  const _AccesNonDisponible();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 40),
              SizedBox(height: 12),
              Text(
                'Accès non disponible pour ce profil.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const AppShell({
    required this.location,
    required this.child,
    super.key,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _expanded = true;

  /// Seule section ouverte du menu latéral (`null` : toutes fermées).
  String? _sectionOuverte;

  /// Dernière page vue : à chaque changement de page, sa section s'ouvre.
  String? _routeVue;

  void _basculerSection(String section) => setState(
      () => _sectionOuverte = _sectionOuverte == section ? null : section);

  void _suivrePageActive(
    String activeRoute,
    _NavItem dashboard,
    List<_NavGroup> groups,
  ) {
    if (activeRoute == _routeVue) return;
    _routeVue = activeRoute;
    final section = activeRoute == dashboard.route
        ? _kAccueil
        : groups
            .where((g) => g.label != null)
            .where((g) => g.items.any((i) => i.route == activeRoute))
            .map((g) => g.label)
            .firstOrNull;
    if (section != null) _sectionOuverte = section;
  }

  /// Route active — correspondance exacte d'abord, puis le préfixe le plus
  /// long suivi de '/' (évite le bug /resident vs /residents).
  String _computeActiveRoute(_NavItem dashboard, List<_NavGroup> groups) {
    final all = [dashboard, ..._allItems(groups)];
    String bestRoute = '';
    for (final item in all) {
      final r = item.route;
      if (widget.location == r) return r;
      if (r != '/' &&
          widget.location.startsWith('$r/') &&
          r.length > bestRoute.length) {
        bestRoute = r;
      }
    }
    return bestRoute;
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(employeeCourantProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    // Réception : elle n'a accès qu'à son écran d'accueil et à ses 5 sections.
    // Toute autre page n'est JAMAIS affichée (`widget.child`) : ceinture de
    // sécurité en plus du routeur.
    if (employee?.isReception == true && !estRouteReception(widget.location)) {
      return const _AccesNonDisponible();
    }

    // Switch EXHAUSTIF sur le profil : plus de repli implicite vers la
    // préposée pour un profil qui n'y a pas droit.
    final _NavItem dashboard;
    final List<_NavGroup> groups;
    switch (employee?.profil) {
      case ProfilAcces.resident:
        dashboard = _residentDashboard;
        groups = _residentGroups;
      case ProfilAcces.responsable:
        dashboard = _responsableDashboard;
        groups = _responsableGroups;
      case ProfilAcces.reception:
        dashboard = _receptionDashboard;
        groups = _receptionGroups;
      case ProfilAcces.preposee:
      case null:
        dashboard = _preposeeDashboard;
        groups = _preposeeGroups;
    }

    final activeRoute = _computeActiveRoute(dashboard, groups);
    _suivrePageActive(activeRoute, dashboard, groups);

    final notifBadge = ref.watch(badgeNotifResidentProvider);
    final badgeMap = notifBadge > 0
        ? <String, int>{'/resident/demandes': notifBadge}
        : const <String, int>{};

    void onLogout() {
      ref.read(authNotifierProvider.notifier).logout();
      context.go('/');
    }

    _Sidebar sidebar({required bool isExpanded}) => _Sidebar(
          dashboard: dashboard,
          groups: groups,
          activeRoute: activeRoute,
          employee: employee,
          onLogout: onLogout,
          isExpanded: isExpanded,
          badgeMap: badgeMap,
          sectionOuverte: _sectionOuverte,
          onBasculerSection: _basculerSection,
        );

    // La barre du haut occupe déjà la zone d'état (heure, batterie) : la page
    // ne doit pas la réserver une seconde fois.
    if (isDesktop) {
      // La page passe SOUS le pied de page en verre : on lui déclare sa
      // hauteur dans le padding du bas (lu par `plusBarre`).
      final mq = MediaQuery.of(context);
      final page = MediaQuery(
        data: mq.copyWith(
          padding: mq.padding.copyWith(top: 0, bottom: _kHauteurPied),
        ),
        child: widget.child,
      );
      final largeurSidebar = _expanded ? _kSidebarExpanded : _kSidebarCollapsed;
      return Scaffold(
        backgroundColor: AppColors.grisLight,
        body: Column(
          children: [
            AppTopBar(onMenu: () => setState(() => _expanded = !_expanded)),
            Expanded(
              child: Row(
                children: [
                  AnimatedContainer(
                    width: largeurSidebar,
                    duration: _kSidebarDuration,
                    curve: Curves.easeInOut,
                    // Dessinée à sa largeur finale et rognée pendant
                    // l'animation : les libellés ne débordent jamais.
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: largeurSidebar,
                        maxWidth: largeurSidebar,
                        child: sidebar(isExpanded: _expanded),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: page),
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _PiedDePage(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile ─────────────────────────────────────────────
    final mobilePrimary = _mobilePrimary(dashboard, groups);
    final overflowGroups = _mobileOverflowGroups(groups);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.grisLight,
      drawer: Drawer(
        width: _kSidebarExpanded + 16,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: sidebar(isExpanded: true)),
              // Sur mobile, le pied de page vit dans le tiroir : la barre du
              // bas occupe déjà le bas de l'écran.
              const _PiedDePage(compact: true),
            ],
          ),
        ),
      ),
      // La page passe SOUS la barre d'onglets en verre, qui la réfracte. Le
      // Scaffold déclare alors la hauteur de la barre dans le padding du bas
      // (lu par `plusBarre`) : d'où le Builder, pour lire CE MediaQuery-là.
      extendBody: true,
      body: Builder(
        builder: (context) => Column(
          children: [
            AppTopBar(onMenu: () => _scaffoldKey.currentState?.openDrawer()),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _MobileBottomBar(
          items: mobilePrimary,
          activeRoute: activeRoute,
          badgeMap: badgeMap,
          overflowGroups: overflowGroups,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Barre mobile flottante + tiroir "Plus"
// ─────────────────────────────────────────────────────────

/// Verre de la barre du bas : un blanc laiteux, lisible sur le fond gris.
final _verreBarre = LiquidGlassSettings(
  glassColor: Colors.white.withValues(alpha: 0.72),
  thickness: 22,
  blur: 8,
);

/// Barre d'onglets en verre liquide (style iOS 26) : l'indicateur de verre
/// glisse d'un onglet à l'autre ; « Plus » est le bouton de verre séparé.
class _MobileBottomBar extends StatelessWidget {
  final List<_NavItem> items;
  final String activeRoute;
  final Map<String, int> badgeMap;
  final List<_NavGroup> overflowGroups;

  const _MobileBottomBar({
    required this.items,
    required this.activeRoute,
    required this.overflowGroups,
    this.badgeMap = const {},
  });

  bool get _isOverflowActive =>
      overflowGroups.any((g) => g.items.any((i) => i.route == activeRoute));

  Widget _icone(IconData icone, int badge) {
    final widget = Icon(icone);
    if (badge == 0) return widget;
    return Badge(label: Text('$badge'), child: widget);
  }

  @override
  Widget build(BuildContext context) {
    final actif = items.indexWhere((i) => i.route == activeRoute);

    return GlassTabBar.bottom(
      tabs: [
        for (final item in items)
          GlassTab(
            icon: _icone(item.icon, badgeMap[item.route] ?? 0),
            activeIcon: _icone(item.activeIcon, badgeMap[item.route] ?? 0),
            label: item.shortLabel,
            semanticLabel: item.label,
          ),
      ],
      // Page du tiroir « Plus » : aucun onglet n'est en surbrillance.
      selectedIndex: actif < 0 ? 0 : actif,
      showIndicator: actif >= 0,
      onTabSelected: (i) => context.go(items[i].route),
      extraButton: overflowGroups.isEmpty
          ? null
          : GlassTabBarExtraButton(
              icon: const Icon(Icons.grid_view_rounded),
              label: 'Plus',
              size: 56,
              iconColor:
                  _isOverflowActive ? AppColors.rouge : AppColors.grisDark,
              onTap: () => _openPlusSheet(context),
            ),
      settings: _verreBarre,
      indicatorColor: AppColors.rouge.withValues(alpha: 0.12),
      selectedIconColor: AppColors.rouge,
      unselectedIconColor: AppColors.grisDark,
      selectedLabelColor: AppColors.rouge,
      unselectedLabelColor: AppColors.grisDark,
      horizontalPadding: 12,
      verticalPadding: 8,
      barHeight: 64,
      iconSize: 22,
      labelFontSize: 10.5,
    );
  }

  void _openPlusSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _PlusSheet(
        groups: overflowGroups,
        activeRoute: activeRoute,
        badgeMap: badgeMap,
        onSelect: (route) {
          Navigator.of(sheetContext).pop();
          context.go(route);
        },
      ),
    );
  }
}

// ── Tiroir "Plus" ──────────────────────────────────────────

class _PlusSheet extends StatelessWidget {
  final List<_NavGroup> groups;
  final String activeRoute;
  final Map<String, int> badgeMap;
  final ValueChanged<String> onSelect;

  const _PlusSheet({
    required this.groups,
    required this.activeRoute,
    required this.onSelect,
    this.badgeMap = const {},
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.grisMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Plus',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.noir,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final group in groups) ...[
                        if (group.label != null) ...[
                          Text(
                            group.label!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.grisText,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: AppSizes.sm),
                        ],
                        Wrap(
                          spacing: AppSizes.sm,
                          runSpacing: AppSizes.md,
                          children: group.items.map((item) {
                            final active = item.route == activeRoute;
                            final badge = badgeMap[item.route] ?? 0;
                            return SizedBox(
                              width: 76,
                              child: InkWell(
                                onTap: () => onSelect(item.route),
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusMd),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: active
                                            ? AppColors.rouge
                                                .withValues(alpha: 0.10)
                                            : AppColors.grisLight,
                                        borderRadius: BorderRadius.circular(
                                            AppSizes.radiusMd),
                                      ),
                                      child: Badge(
                                        isLabelVisible: badge > 0,
                                        label: Text('$badge'),
                                        child: Icon(
                                          active ? item.activeIcon : item.icon,
                                          color: active
                                              ? AppColors.rouge
                                              : AppColors.grisDark,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: active
                                            ? AppColors.rouge
                                            : AppColors.noir,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSizes.lg),
                      ],
                    ],
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

// ─────────────────────────────────────────────────────────
// Menu latéral (bureau, et tiroir sur mobile)
// ─────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final _NavItem dashboard;
  final List<_NavGroup> groups;
  final String activeRoute;
  final Employee? employee;
  final VoidCallback onLogout;
  final bool isExpanded;
  final Map<String, int> badgeMap;
  final String? sectionOuverte;
  final ValueChanged<String> onBasculerSection;

  const _Sidebar({
    required this.dashboard,
    required this.groups,
    required this.activeRoute,
    required this.employee,
    required this.onLogout,
    required this.isExpanded,
    required this.sectionOuverte,
    required this.onBasculerSection,
    this.badgeMap = const {},
  });

  bool get _enSections => groups.any((g) => g.label != null);

  _SidebarItem _item(_NavItem item) => _SidebarItem(
        item: item,
        isActive: item.route == activeRoute,
        isExpanded: isExpanded,
        badge: badgeMap[item.route] ?? 0,
      );

  _Section _section(String libelle, IconData icone, List<_NavItem> items) =>
      _Section(
        libelle: libelle,
        icone: icone,
        ouverte: sectionOuverte == libelle,
        onTap: () => onBasculerSection(libelle),
        items: [for (final i in items) _item(i)],
      );

  List<Widget> _deplie() {
    if (!_enSections) {
      return [
        _item(dashboard),
        for (final g in groups) ...g.items.map(_item),
      ];
    }
    return [
      _section(_kAccueil, Icons.home_rounded, [dashboard]),
      for (final g in groups)
        if (g.label != null)
          _section(g.label!, g.icon ?? Icons.folder_rounded, g.items)
        else
          ...g.items.map(_item),
    ];
  }

  // Menu replié : les icônes seules, groupe par groupe.
  List<Widget> _replie() => [
        _item(dashboard),
        for (final g in groups) ...[
          const Divider(height: 17, indent: 12, endIndent: 12),
          ...g.items.map(_item),
        ],
      ];

  @override
  Widget build(BuildContext context) {
    final aPlat = !isExpanded || !_enSections;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.grisMedium)),
      ),
      child: Column(
        children: [
          _SidebarProfil(employee: employee, isExpanded: isExpanded),
          Expanded(
            child: SingleChildScrollView(
              padding: aPlat
                  ? EdgeInsets.symmetric(
                      horizontal: isExpanded ? 12 : 8, vertical: 12)
                  : const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: isExpanded ? _deplie() : _replie(),
              ),
            ),
          ),
          _SidebarFooter(
            employee: employee,
            onLogout: onLogout,
            isExpanded: isExpanded,
          ),
        ],
      ),
    );
  }
}

// ── Bloc profil (haut du menu) ────────────────────────────
class _SidebarProfil extends StatelessWidget {
  final Employee? employee;
  final bool isExpanded;

  const _SidebarProfil({required this.employee, required this.isExpanded});

  @override
  Widget build(BuildContext context) {
    final e = employee;
    // La photo de la personne ; à défaut, une silhouette (comme le modèle).
    final avatar = AvatarProfil(
      proprietaire: e == null ? null : ProprietairePhoto.de(e),
      initiales: '',
      icone: Icons.person_rounded,
      rayon: isExpanded ? 24 : 18,
      couleurFond: Colors.transparent,
      couleurTexte: AppColors.noir,
    );

    if (!isExpanded) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.grisMedium)),
        ),
        child: Center(
          child: Tooltip(message: e?.nomComplet ?? '', child: avatar),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.grisMedium)),
      ),
      child: Column(
        children: [
          avatar,
          const SizedBox(height: 8),
          Text(
            e?.nomComplet ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.noir,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            (e?.role ?? RoleType.employe).intitule,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: AppColors.grisDark),
          ),
        ],
      ),
    );
  }
}

// ── Section repliable ─────────────────────────────────────
class _Section extends StatelessWidget {
  final String libelle;
  final IconData icone;
  final bool ouverte;
  final VoidCallback onTap;
  final List<Widget> items;

  const _Section({
    required this.libelle,
    required this.icone,
    required this.ouverte,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.grisMedium)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            hoverColor: AppColors.grisLight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              child: Row(
                children: [
                  Icon(icone, size: 19, color: AppColors.rouge),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      libelle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.noir,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: ouverte ? 0.5 : 0,
                    duration: _kSidebarDuration,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.grisDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: _kSidebarDuration,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: ouverte
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: items,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// ── Entrée du menu ────────────────────────────────────────
class _SidebarItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final bool isExpanded;
  final int badge;

  const _SidebarItem({
    required this.item,
    required this.isActive,
    required this.isExpanded,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = isActive ? Colors.white : AppColors.rouge;
    Widget icon = Icon(
      isActive ? item.activeIcon : item.icon,
      size: 18,
      color: couleur,
    );
    if (badge > 0) {
      icon = Badge(label: Text('$badge'), child: icon);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: isExpanded ? '' : item.label,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 300),
        child: Material(
          color: isActive ? AppColors.rouge : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          child: InkWell(
            onTap: () {
              // Sans effet sur bureau ; referme le tiroir sur mobile.
              Scaffold.maybeOf(context)?.closeDrawer();
              context.go(item.route);
            },
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            hoverColor: isActive ? null : AppColors.grisLight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isExpanded ? 16 : 0,
                vertical: 10,
              ),
              child: isExpanded
                  ? Row(
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isActive ? FontWeight.w700 : FontWeight.w500,
                              color: isActive ? Colors.white : AppColors.noir,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Zone de déconnexion (bas du menu) ─────────────────────
class _SidebarFooter extends StatelessWidget {
  final Employee? employee;
  final VoidCallback onLogout;
  final bool isExpanded;

  const _SidebarFooter({
    required this.employee,
    required this.onLogout,
    required this.isExpanded,
  });

  String get _initiales {
    final p = employee?.prenom ?? '';
    final n = employee?.nom ?? '';
    return '${p.isNotEmpty ? p[0] : ''}${n.isNotEmpty ? n[0] : ''}'
        .toUpperCase();
  }

  Widget _avatar() {
    final e = employee;
    return AvatarProfil(
      proprietaire: e == null ? null : ProprietairePhoto.de(e),
      initiales: _initiales,
      rayon: 16,
      couleurFond: AppColors.rouge.withValues(alpha: 0.12),
      couleurTexte: AppColors.rouge,
      tailleTexte: 12,
      poidsTexte: FontWeight.bold,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isExpanded ? 12 : 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.grisMedium)),
      ),
      child: isExpanded
          ? Row(
              children: [
                _avatar(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee?.nomComplet ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.noir,
                        ),
                      ),
                      Text(
                        (employee?.role ?? RoleType.employe).intitule,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.grisText,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Déconnexion',
                  child: InkWell(
                    onTap: onLogout,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: AppColors.grisText,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Tooltip(
                message: 'Déconnexion',
                preferBelow: false,
                child: InkWell(
                  onTap: onLogout,
                  borderRadius: BorderRadius.circular(20),
                  child: _avatar(),
                ),
              ),
            ),
    );
  }
}

// ── Pied de page ──────────────────────────────────────────
class _PiedDePage extends StatelessWidget {
  final bool compact;

  const _PiedDePage({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final annee = DateTime.now().year;
    const style = TextStyle(fontSize: 12, color: AppColors.grisText);

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.grisMedium)),
        ),
        child: Text(
          '© $annee CleanOpss',
          textAlign: TextAlign.center,
          style: style,
        ),
      );
    }

    // Verre : la page défile dessous et transparaît, floutée.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.grisMedium.withValues(alpha: 0.7)),
        ),
      ),
      child: GlassContainer(
        useOwnLayer: true,
        settings: _verrePied,
        shape: const LiquidRoundedSuperellipse(borderRadius: 0),
        width: double.infinity,
        height: _kHauteurPied,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        child: Text(
          '© $annee CleanOps. Tous droits réservés.',
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: style.copyWith(color: AppColors.grisDark),
        ),
      ),
    );
  }
}

/// Hauteur du pied de page (bureau). La page la réserve en bas de son
/// défilement pour que son dernier élément ne reste pas caché dessous.
const double _kHauteurPied = 44;

/// Verre du pied de page : blanc laiteux, assez opaque pour le texte.
final _verrePied = LiquidGlassSettings(
  glassColor: Colors.white.withValues(alpha: 0.65),
  thickness: 14,
  blur: 10,
);
