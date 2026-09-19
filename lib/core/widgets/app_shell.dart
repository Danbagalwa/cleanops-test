import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../../features/auth/domain/entities/employee.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/resident_espace/presentation/providers/resident_espace_provider.dart';

// ── Dimensions sidebar ────────────────────────────────────
const double _kSidebarExpanded = 264;
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
class _NavGroup {
  final String? label;
  final List<_NavItem> items;
  final bool startOpen;

  const _NavGroup({this.label, required this.items, this.startOpen = true});
}

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
  _NavGroup(label: 'Mon travail', items: [
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
  _NavGroup(label: 'Équipe', items: [
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
  _NavGroup(label: 'Opérations', items: [
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
  _NavGroup(label: 'Équipe', items: [
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
  _NavGroup(label: 'Résidence', startOpen: false, items: [
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
        label: g.label,
        items: g.items.where((i) => !i.mobilePrimary).toList()))
    .where((g) => g.items.isNotEmpty)
    .toList();

// ─────────────────────────────────────────────────────────
// AppShell
// ─────────────────────────────────────────────────────────

/// Écran de refus affiché à la place de toute page pour un profil sans accès
/// (Réception, tant que sa destination n'existe pas). Ne montre aucune donnée.
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
  bool _expanded = true;
  final Set<String> _closedGroups = {};

  bool _groupOpen(_NavGroup group) {
    if (group.label == null) return true;
    return !_closedGroups.contains(group.label);
  }

  void _toggleGroup(_NavGroup group) {
    if (group.label == null) return;
    setState(() {
      if (_closedGroups.contains(group.label)) {
        _closedGroups.remove(group.label);
      } else {
        _closedGroups.add(group.label!);
      }
    });
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

    // Réception : aucun écran n'existe encore et elle n'hérite d'aucun droit.
    // On n'affiche JAMAIS la page demandée (`widget.child`) : ceinture de
    // sécurité en plus du routeur.
    if (employee?.isReception == true) {
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
        return const _AccesNonDisponible();
      case ProfilAcces.preposee:
      case null:
        dashboard = _preposeeDashboard;
        groups = _preposeeGroups;
    }

    final activeRoute = _computeActiveRoute(dashboard, groups);

    final notifBadge = ref.watch(badgeNotifResidentProvider);
    final badgeMap = notifBadge > 0
        ? <String, int>{'/resident/demandes': notifBadge}
        : const <String, int>{};

    void onLogout() {
      ref.read(authNotifierProvider.notifier).logout();
      context.go('/');
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.grisLight,
        body: Row(
          children: [
            AnimatedContainer(
              width: _expanded ? _kSidebarExpanded : _kSidebarCollapsed,
              duration: _kSidebarDuration,
              curve: Curves.easeInOut,
              child: ClipRect(
                child: _Sidebar(
                  dashboard: dashboard,
                  groups: groups,
                  activeRoute: activeRoute,
                  employee: employee,
                  onLogout: onLogout,
                  isExpanded: _expanded,
                  onToggle: () => setState(() => _expanded = !_expanded),
                  badgeMap: badgeMap,
                  groupOpen: _groupOpen,
                  onToggleGroup: _toggleGroup,
                ),
              ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    // ── Mobile ─────────────────────────────────────────────
    final mobilePrimary = _mobilePrimary(dashboard, groups);
    final overflowGroups = _mobileOverflowGroups(groups);

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      body: widget.child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: _MobileBottomBar(
            items: mobilePrimary,
            activeRoute: activeRoute,
            badgeMap: badgeMap,
            overflowGroups: overflowGroups,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Barre mobile flottante + tiroir "Plus"
// ─────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _BarButton(
                icon: item.route == activeRoute ? item.activeIcon : item.icon,
                label: item.shortLabel,
                active: item.route == activeRoute,
                badge: badgeMap[item.route] ?? 0,
                onTap: () => context.go(item.route),
              ),
            ),
          if (overflowGroups.isNotEmpty)
            Expanded(
              child: _BarButton(
                icon: Icons.grid_view_rounded,
                label: 'Plus',
                active: _isOverflowActive,
                onTap: () => _openPlusSheet(context),
              ),
            ),
        ],
      ),
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

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  const _BarButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(
      icon,
      size: 24,
      color: active ? AppColors.rouge : AppColors.grisDark,
    );
    if (badge > 0) {
      iconWidget = Badge(label: Text('$badge'), child: iconWidget);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.rouge.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? AppColors.rouge : AppColors.grisDark,
                ),
              ),
            ],
          ),
        ),
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
                                          active
                                              ? item.activeIcon
                                              : item.icon,
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
// Sidebar (desktop)
// ─────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final _NavItem dashboard;
  final List<_NavGroup> groups;
  final String activeRoute;
  final Employee? employee;
  final VoidCallback onLogout;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Map<String, int> badgeMap;
  final bool Function(_NavGroup) groupOpen;
  final void Function(_NavGroup) onToggleGroup;

  const _Sidebar({
    required this.dashboard,
    required this.groups,
    required this.activeRoute,
    required this.employee,
    required this.onLogout,
    required this.isExpanded,
    required this.onToggle,
    required this.groupOpen,
    required this.onToggleGroup,
    this.badgeMap = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.grisMedium)),
      ),
      child: Column(
        children: [
          _SidebarHeader(isExpanded: isExpanded, onToggle: onToggle),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isExpanded ? 12 : 8,
                vertical: 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SidebarItem(
                    item: dashboard,
                    isActive: dashboard.route == activeRoute,
                    isExpanded: isExpanded,
                    badge: badgeMap[dashboard.route] ?? 0,
                  ),
                  for (final group in groups) ...[
                    const SizedBox(height: 4),
                    if (group.label != null)
                      _GroupHeader(
                        label: group.label!,
                        isExpanded: isExpanded,
                        open: groupOpen(group),
                        onTap: () => onToggleGroup(group),
                      ),
                    AnimatedSize(
                      duration: _kSidebarDuration,
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: (!isExpanded || groupOpen(group))
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: group.items
                                  .map((item) => _SidebarItem(
                                        item: item,
                                        isActive: item.route == activeRoute,
                                        isExpanded: isExpanded,
                                        badge: badgeMap[item.route] ?? 0,
                                      ))
                                  .toList(),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ],
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

// ── En-tête de groupe (dépliable) ─────────────────────────
class _GroupHeader extends StatelessWidget {
  final String label;
  final bool isExpanded;
  final bool open;
  final VoidCallback onTap;

  const _GroupHeader({
    required this.label,
    required this.isExpanded,
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isExpanded ? 1.0 : 0.0,
      duration: _kSidebarDuration,
      child: IgnorePointer(
        ignoring: !isExpanded,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.grisText,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: _kSidebarDuration,
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.grisText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Header sidebar ────────────────────────────────────────
class _SidebarHeader extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;

  const _SidebarHeader({required this.isExpanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.grisMedium)),
      ),
      child: isExpanded ? _buildExpanded() : _buildCollapsed(),
    );
  }

  Widget _buildExpanded() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.rouge.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: AppColors.rouge,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CleanOps',
                  style: TextStyle(
                    color: AppColors.noir,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Résidence',
                  style: TextStyle(color: AppColors.grisText, fontSize: 11),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Réduire le menu',
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.grisText,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsed() {
    return Center(
      child: Tooltip(
        message: 'Développer le menu',
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.chevron_right_rounded,
              color: AppColors.grisText,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Item de navigation sidebar ────────────────────────────
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
    Widget icon = Icon(
      isActive ? item.activeIcon : item.icon,
      size: 19,
      color: isActive ? AppColors.rouge : AppColors.grisDark,
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
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          child: InkWell(
            onTap: () => context.go(item.route),
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            hoverColor: AppColors.grisLight,
            child: AnimatedContainer(
              duration: _kSidebarDuration,
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: isExpanded ? 14 : 0,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.rouge.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              ),
              child: isExpanded
                  ? Row(
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  isActive ? FontWeight.w700 : FontWeight.w500,
                              color:
                                  isActive ? AppColors.rouge : AppColors.noir,
                            ),
                            overflow: TextOverflow.ellipsis,
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

// ── Footer sidebar ────────────────────────────────────────
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

  String get _roleLabel {
    switch (employee?.role) {
      case RoleType.superviseurMenage:
        return 'Superviseur';
      case RoleType.direction:
        return 'Direction';
      case RoleType.reception:
        return 'Réception';
      case RoleType.admin:
        return 'Admin';
      case RoleType.resident:
        return 'Résident';
      default:
        return 'Préposée';
    }
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.rouge.withValues(alpha: 0.12),
      child: Text(
        _initiales,
        style: const TextStyle(
          color: AppColors.rouge,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isExpanded ? AppSizes.md : 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.grisMedium)),
      ),
      child: isExpanded ? _buildExpanded() : _buildCollapsed(),
    );
  }

  Widget _buildExpanded() {
    return Row(
      children: [
        _buildAvatar(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${employee?.prenom ?? ''} ${employee?.nom ?? ''}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.noir,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _roleLabel,
                style: const TextStyle(
                  fontSize: 11,
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
    );
  }

  Widget _buildCollapsed() {
    return Center(
      child: Tooltip(
        message: 'Déconnexion',
        preferBelow: false,
        child: InkWell(
          onTap: onLogout,
          borderRadius: BorderRadius.circular(20),
          child: _buildAvatar(),
        ),
      ),
    );
  }
}
