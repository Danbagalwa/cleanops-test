import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../../features/auth/domain/entities/employee.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/resident_espace/presentation/providers/resident_espace_provider.dart';

// ── Dimensions sidebar ────────────────────────────────────
const double _kSidebarExpanded = 260;
const double _kSidebarCollapsed = 64;
const Duration _kSidebarDuration = Duration(milliseconds: 240);

// ─────────────────────────────────────────────────────────
// Modèles
// ─────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String shortLabel;
  final String route;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.shortLabel,
    required this.route,
  });
}

/// Groupe de liens avec un titre de section affiché dans la sidebar.
class _NavSection {
  final String label; // vide → pas d'en-tête
  final List<_NavItem> items;
  const _NavSection({required this.label, required this.items});
}

// ─────────────────────────────────────────────────────────
// Items préposée
// ─────────────────────────────────────────────────────────

const List<_NavItem> _preposeeItems = [
  _NavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Tableau de bord',
    shortLabel: 'Accueil',
    route: '/dashboard',
  ),
  _NavItem(
    icon: Icons.today_outlined,
    activeIcon: Icons.today_rounded,
    label: 'Ma Journée',
    shortLabel: 'Journée',
    route: '/journee',
  ),
  _NavItem(
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month_rounded,
    label: 'Planning',
    shortLabel: 'Planning',
    route: '/planning',
  ),
  _NavItem(
    icon: Icons.sticky_note_2_outlined,
    activeIcon: Icons.sticky_note_2_rounded,
    label: 'Mémo',
    shortLabel: 'Mémo',
    route: '/memo',
  ),
  _NavItem(
    icon: Icons.chat_bubble_outline_rounded,
    activeIcon: Icons.chat_bubble_rounded,
    label: 'Chat Équipe',
    shortLabel: 'Chat',
    route: '/chat',
  ),
];

const List<_NavSection> _preposeeSections = [
  _NavSection(label: 'NAVIGATION', items: _preposeeItems),
];

// ─────────────────────────────────────────────────────────
// Items responsable
// ─────────────────────────────────────────────────────────

/// 5 items affichés dans la barre de navigation mobile.
const List<_NavItem> _responsableMobileItems = [
  _NavItem(
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
    label: 'Tableau de bord',
    shortLabel: 'Accueil',
    route: '/employeur',
  ),
  _NavItem(
    icon: Icons.group_outlined,
    activeIcon: Icons.group_rounded,
    label: 'Employés',
    shortLabel: 'Équipe',
    route: '/employes',
  ),
  _NavItem(
    icon: Icons.apartment_outlined,
    activeIcon: Icons.apartment_rounded,
    label: 'Appartements',
    shortLabel: 'Appts',
    route: '/appartements',
  ),
  _NavItem(
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month_rounded,
    label: 'Planning',
    shortLabel: 'Planning',
    route: '/planning',
  ),
  _NavItem(
    icon: Icons.chat_bubble_outline_rounded,
    activeIcon: Icons.chat_bubble_rounded,
    label: 'Chat Équipe',
    shortLabel: 'Chat',
    route: '/chat',
  ),
];

/// Sidebar organisée en 3 sections.
const List<_NavSection> _responsableSections = [
  // ── Section 1 : navigation principale ─────────────────
  _NavSection(label: 'PRINCIPAL', items: [
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Tableau de bord',
      shortLabel: 'Accueil',
      route: '/employeur',
    ),
    _NavItem(
      icon: Icons.group_outlined,
      activeIcon: Icons.group_rounded,
      label: 'Employés',
      shortLabel: 'Équipe',
      route: '/employes',
    ),
    _NavItem(
      icon: Icons.apartment_outlined,
      activeIcon: Icons.apartment_rounded,
      label: 'Appartements',
      shortLabel: 'Appts',
      route: '/appartements',
    ),
    _NavItem(
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Planning',
      shortLabel: 'Planning',
      route: '/planning',
    ),
    _NavItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Chat Équipe',
      shortLabel: 'Chat',
      route: '/chat',
    ),
  ]),

  // ── Section 2 : opérations quotidiennes ───────────────
  _NavSection(label: 'OPÉRATIONS', items: [
    _NavItem(
      icon: Icons.checklist_rounded,
      activeIcon: Icons.checklist_rounded,
      label: 'Progression du jour',
      shortLabel: 'Jour',
      route: '/progression-jour',
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
    _NavItem(
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign_rounded,
      label: 'Messages semaine',
      shortLabel: 'Messages',
      route: '/messages-semaine',
    ),
  ]),

  // ── Section 3 : analyse & gestion ─────────────────────
  _NavSection(label: 'ANALYSE', items: [
    _NavItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'Statistiques',
      shortLabel: 'Stats',
      route: '/statistiques',
    ),
    _NavItem(
      icon: Icons.sticky_note_2_outlined,
      activeIcon: Icons.sticky_note_2_rounded,
      label: 'Mémo',
      shortLabel: 'Mémo',
      route: '/memo',
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
      shortLabel: 'Demandes',
      route: '/demandes/residents',
    ),
  ]),
];

// ─────────────────────────────────────────────────────────
// Items résident
// ─────────────────────────────────────────────────────────

const List<_NavItem> _residentItems = [
  _NavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Mon espace',
    shortLabel: 'Accueil',
    route: '/resident',
  ),
  _NavItem(
    icon: Icons.inbox_outlined,
    activeIcon: Icons.inbox_rounded,
    label: 'Mes demandes',
    shortLabel: 'Demandes',
    route: '/resident/demandes',
  ),
  _NavItem(
    icon: Icons.person_outlined,
    activeIcon: Icons.person_rounded,
    label: 'Mon profil',
    shortLabel: 'Profil',
    route: '/resident/profil',
  ),
];

const List<_NavSection> _residentSections = [
  _NavSection(label: 'MON ESPACE', items: _residentItems),
];

// ─────────────────────────────────────────────────────────
// AppShell
// ─────────────────────────────────────────────────────────

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

  /// Route active parmi toutes les sections — correspondance exacte d'abord,
  /// puis le préfixe le plus long suivi de '/' (évite le bug /resident vs /residents).
  String _computeActiveRoute(List<_NavSection> sections) {
    String bestRoute = '';
    for (final section in sections) {
      for (final item in section.items) {
        final r = item.route;
        if (widget.location == r) return r;
        if (r != '/' &&
            widget.location.startsWith('$r/') &&
            r.length > bestRoute.length) {
          bestRoute = r;
        }
      }
    }
    return bestRoute;
  }

  /// Index actif dans la liste mobile (préfixe /route/).
  int _mobileActiveIndex(List<_NavItem> items) {
    for (int i = 0; i < items.length; i++) {
      final r = items[i].route;
      if (widget.location == r) return i;
      if (r != '/' && widget.location.startsWith('$r/')) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(employeeCourantProvider);
    final isResponsable = ref.watch(isResponsableProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    // Sections sidebar selon le rôle
    final sections = employee?.isResident == true
        ? _residentSections
        : (isResponsable ? _responsableSections : _preposeeSections);

    // Items pour la barre mobile (5 max)
    final mobileItems = (employee?.isResident == true
            ? _residentItems
            : (isResponsable ? _responsableMobileItems : _preposeeItems))
        .take(5)
        .toList();

    final activeRoute = _computeActiveRoute(sections);
    final mobileIndex =
        _mobileActiveIndex(mobileItems).clamp(0, mobileItems.length - 1);

    final notifBadge = ref.watch(badgeNotifResidentProvider);
    final badgeMap = notifBadge > 0
        ? <String, int>{'/resident/demandes': notifBadge}
        : const <String, int>{};

    final profileRoute =
        employee?.isResident == true ? '/resident/profil' : '/profil';

    Future<void> onLogout() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.logout_rounded, color: AppColors.rouge),
          title: const Text('Se déconnecter ?'),
          content: const Text(
            'Vous devrez vous identifier à nouveau pour accéder à votre espace.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Rester connecté'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Se déconnecter'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await ref.read(authNotifierProvider.notifier).logout();
      if (context.mounted) context.go('/');
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.grisLight,
        body: Row(
          children: [
            // ── Sidebar animée ───────────────────────────
            AnimatedContainer(
              width: _expanded ? _kSidebarExpanded : _kSidebarCollapsed,
              duration: _kSidebarDuration,
              curve: Curves.easeInOut,
              child: ClipRect(
                child: _Sidebar(
                  sections: sections,
                  activeRoute: activeRoute,
                  employee: employee,
                  onLogout: onLogout,
                  onProfile: () => context.go(profileRoute),
                  isExpanded: _expanded,
                  onToggle: () => setState(() => _expanded = !_expanded),
                  badgeMap: badgeMap,
                ),
              ),
            ),
            // ── Contenu principal ────────────────────────
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    // ── Mobile : barre de navigation en bas ───────────────
    return Scaffold(
      backgroundColor: AppColors.grisLight,
      body: widget.child,
      bottomNavigationBar: _BottomNav(
        items: mobileItems,
        activeIndex: mobileIndex,
        badgeMap: badgeMap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Bottom Navigation (mobile — inchangé)
// ─────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final List<_NavItem> items;
  final int activeIndex;
  final Map<String, int> badgeMap;

  const _BottomNav({
    required this.items,
    required this.activeIndex,
    this.badgeMap = const {},
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: activeIndex,
      onDestinationSelected: (i) => context.go(items[i].route),
      backgroundColor: Colors.white,
      indicatorColor: AppColors.rouge.withValues(alpha: 0.12),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: AppSizes.bottomNavHeight,
      destinations: items.map((item) {
        final badge = badgeMap[item.route] ?? 0;
        Widget icon = Icon(item.icon, color: AppColors.grisDark);
        Widget selectedIcon = Icon(item.activeIcon, color: AppColors.rouge);
        if (badge > 0) {
          icon = Badge(label: Text('$badge'), child: icon);
          selectedIcon = Badge(label: Text('$badge'), child: selectedIcon);
        }
        return NavigationDestination(
          icon: icon,
          selectedIcon: selectedIcon,
          label: item.shortLabel,
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final List<_NavSection> sections;
  final String activeRoute;
  final Employee? employee;
  final VoidCallback onLogout;
  final VoidCallback onProfile;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Map<String, int> badgeMap;

  const _Sidebar({
    required this.sections,
    required this.activeRoute,
    required this.employee,
    required this.onLogout,
    required this.onProfile,
    required this.isExpanded,
    required this.onToggle,
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
          // ── Header ──────────────────────────────────
          _SidebarHeader(isExpanded: isExpanded, onToggle: onToggle),

          // ── Navigation par sections ──────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isExpanded ? 12 : 8,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int si = 0; si < sections.length; si++) ...[
                    // Séparateur inter-sections
                    if (si > 0) _SectionDivider(isExpanded: isExpanded),

                    // En-tête de section
                    _SectionHeader(
                      label: sections[si].label,
                      isExpanded: isExpanded,
                      isFirst: si == 0,
                    ),

                    // Items de la section
                    ...sections[si].items.map(
                          (item) => _SidebarItem(
                            item: item,
                            isActive: item.route == activeRoute,
                            isExpanded: isExpanded,
                            badge: badgeMap[item.route] ?? 0,
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),

          // ── Footer ──────────────────────────────────
          _SidebarFooter(
            employee: employee,
            onLogout: onLogout,
            onProfile: onProfile,
            isExpanded: isExpanded,
          ),
        ],
      ),
    );
  }
}

// ── Séparateur entre sections ─────────────────────────────
class _SectionDivider extends StatelessWidget {
  final bool isExpanded;
  const _SectionDivider({required this.isExpanded});

  @override
  Widget build(BuildContext context) {
    if (isExpanded) {
      // En mode étendu : simple espace vertical
      return const SizedBox(height: 4);
    }
    // En mode réduit : ligne de séparation subtile
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Divider(height: 1, thickness: 1, color: AppColors.grisMedium),
    );
  }
}

// ── En-tête de section ────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isExpanded;
  final bool isFirst;

  const _SectionHeader({
    required this.label,
    required this.isExpanded,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: isExpanded ? 1.0 : 0.0,
      duration: _kSidebarDuration,
      child: Padding(
        padding: EdgeInsets.only(
          left: 8,
          bottom: 4,
          top: isFirst ? 2 : 8,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.grisText,
            letterSpacing: 1.5,
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
      color: AppColors.rouge,
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
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Colors.white,
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
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Résidence',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Réduire le menu',
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
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
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.8),
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
      size: 20,
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
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: InkWell(
            onTap: () => context.go(item.route),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            hoverColor: AppColors.grisLight,
            child: AnimatedContainer(
              duration: _kSidebarDuration,
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: isExpanded ? 12 : 0,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.rouge.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
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
                              fontSize: 14,
                              fontWeight:
                                  isActive ? FontWeight.w600 : FontWeight.w400,
                              color:
                                  isActive ? AppColors.rouge : AppColors.noir,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Indicateur actif discret
                        if (isActive)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.rouge,
                              shape: BoxShape.circle,
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
  final VoidCallback onProfile;
  final bool isExpanded;

  const _SidebarFooter({
    required this.employee,
    required this.onLogout,
    required this.onProfile,
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
    return _buildAccountMenu(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: const Color(0xFFE7E9F2)),
        ),
        child: Row(
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
                      fontSize: 13,
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
            const SizedBox(width: 6),
            const Icon(
              Icons.unfold_more_rounded,
              size: 18,
              color: AppColors.grisText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsed() {
    return Tooltip(
      message: 'Ouvrir le menu du compte',
      child: _buildAccountMenu(child: _buildAvatar()),
    );
  }

  Widget _buildAccountMenu({required Widget child}) {
    return PopupMenuButton<String>(
      tooltip: 'Menu du compte',
      position: PopupMenuPosition.over,
      offset: const Offset(0, -116),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      elevation: 8,
      onSelected: (value) {
        if (value == 'profile') {
          onProfile();
        } else if (value == 'logout') {
          onLogout();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.manage_accounts_outlined, size: 20),
              SizedBox(width: 12),
              Text('Mon profil'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: Color(0xFF9F2D2D)),
              SizedBox(width: 12),
              Text(
                'Se déconnecter',
                style: TextStyle(color: Color(0xFF9F2D2D)),
              ),
            ],
          ),
        ),
      ],
      child: child,
    );
  }
}
