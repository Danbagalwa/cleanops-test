import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../providers/statistiques_provider.dart';
import '../widgets/stat_semaine_tab.dart';
import '../widgets/stat_preposee_tab.dart';
import '../widgets/stat_appartement_tab.dart';

class StatistiquesScreen extends ConsumerStatefulWidget {
  const StatistiquesScreen({super.key});

  @override
  ConsumerState<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends ConsumerState<StatistiquesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(statistiquesNotifierProvider.notifier).loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statistiquesNotifierProvider);
    final isResponsable = ref.watch(isResponsableProvider);

    if (!isResponsable) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Accès réservé au responsable.',
            style: TextStyle(color: AppColors.grisText),
          ),
        ),
      );
    }

    final content = state.error != null && !state.isLoading
        ? _ErreurMessage(
            message: state.error!,
            onRetry: () =>
                ref.read(statistiquesNotifierProvider.notifier).loadAll(),
          )
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            child: switch (state.selectedTab) {
              0 => StatSemaineTab(
                  key: const ValueKey(0), stats: state.statSemaine),
              1 => const StatPreposeeTab(key: ValueKey(1)),
              2 => StatAppartementTab(
                  key: const ValueKey(2), stats: state.topAppartements),
              _ => const SizedBox.shrink(),
            },
          );

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.backOrHome(AppRoutes.employerDashboard),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistiques',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              _labelPeriode(state.selectedTab),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Rafraîchir',
              onPressed: () =>
                  ref.read(statistiquesNotifierProvider.notifier).loadAll(),
            ),
        ],
      ),
      body: Row(
        children: [
          // ── Contenu principal (gauche) ─────────────────────
          Expanded(child: content),
          // ── Rail de navigation (droite) ────────────────────
          _RightNav(
            selectedIndex: state.selectedTab,
            onSelect: (i) =>
                ref.read(statistiquesNotifierProvider.notifier).selectTab(i),
          ),
        ],
      ),
    );
  }

  String _labelPeriode(int tab) {
    if (tab == 0) return 'Semaine courante';
    final now = DateTime.now();
    const mois = [
      '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${mois[now.month]} ${now.year}';
  }
}

// ── Rail de navigation droit ───────────────────────────────

class _RightNav extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onSelect;

  const _RightNav({required this.selectedIndex, required this.onSelect});

  static const _items = [
    _NavItemData(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
      label: 'Semaine',
    ),
    _NavItemData(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Préposées',
    ),
    _NavItemData(
      icon: Icons.apartment_outlined,
      activeIcon: Icons.apartment_rounded,
      label: 'Appts',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 640;
    final width = compact ? 62.0 : 172.0;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          // ombre principale vers la gauche
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            spreadRadius: -2,
            offset: Offset(-8, 0),
          ),
          // liseré subtil en haut
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            const SizedBox(height: AppSizes.lg),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.md, 0, AppSizes.md, AppSizes.xs),
              child: Text(
                'ANALYSES',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grisText.withValues(alpha: 0.7),
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.xs),
          ] else
            const SizedBox(height: AppSizes.lg),
          for (int i = 0; i < _items.length; i++)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : AppSizes.sm,
                vertical: 2,
              ),
              child: _NavItem(
                data: _items[i],
                isSelected: selectedIndex == i,
                compact: compact,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Données d'un item ──────────────────────────────────────

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ── Item avec état hover ───────────────────────────────────

class _NavItem extends StatefulWidget {
  final _NavItemData data;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;

  const _NavItem({
    required this.data,
    required this.isSelected,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  Color get _bgColor {
    if (widget.isSelected) {
      return _hovered
          ? AppColors.rouge.withValues(alpha: 0.14)
          : AppColors.rouge.withValues(alpha: 0.09);
    }
    return _hovered
        ? AppColors.rouge.withValues(alpha: 0.05)
        : Colors.transparent;
  }

  Color get _iconColor {
    if (widget.isSelected) return AppColors.rouge;
    return _hovered ? AppColors.rouge.withValues(alpha: 0.7) : AppColors.grisText;
  }

  Color get _labelColor {
    if (widget.isSelected) return AppColors.rouge;
    return _hovered ? AppColors.grisDark : AppColors.grisText;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.radiusMd);

    final inner = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: widget.compact
          ? const EdgeInsets.symmetric(vertical: 13)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: radius,
      ),
      child: widget.compact
          ? Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  key: ValueKey(widget.isSelected),
                  widget.isSelected ? widget.data.activeIcon : widget.data.icon,
                  size: 22,
                  color: _iconColor,
                ),
              ),
            )
          : Row(
              children: [
                // Accent bar gauche pour l'item sélectionné
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 3,
                  height: widget.isSelected ? 18 : 0,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.rouge,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  widget.isSelected
                      ? widget.data.activeIcon
                      : widget.data.icon,
                  size: 18,
                  color: _iconColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.data.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: _labelColor,
                    ),
                  ),
                ),
              ],
            ),
    );

    return Tooltip(
      message: widget.compact ? widget.data.label : '',
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: ClipRRect(borderRadius: radius, child: inner),
        ),
      ),
    );
  }
}

// ── Erreur ─────────────────────────────────────────────────

class _ErreurMessage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErreurMessage({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.rouge),
            const SizedBox(height: AppSizes.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grisDark, fontSize: 14),
            ),
            const SizedBox(height: AppSizes.md),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
