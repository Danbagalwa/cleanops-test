import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../features/auth/domain/entities/employee.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/notifications/presentation/widgets/notification_badge_widget.dart';
import '../constants/app_colors.dart';
import '../router/app_router.dart';

const double kAppTopBarHeight = 64;

/// Verre des boutons de la barre : une touche de bleu pour qu'ils se
/// détachent sur le fond blanc.
final _verre = LiquidGlassSettings(
  glassColor: AppColors.rouge.withValues(alpha: 0.08),
  thickness: 16,
  blur: 6,
);

/// Barre blanche en haut de toutes les pages : menu, logo, notifications et
/// compte. Le bouton menu replie la barre latérale (bureau) ou ouvre le tiroir
/// de navigation (mobile), selon [onMenu].
class AppTopBar extends ConsumerWidget {
  final VoidCallback onMenu;

  const AppTopBar({super.key, required this.onMenu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(employeeCourantProvider);
    final notifications = employee == null ? null : notificationsDe(employee);
    final compact = MediaQuery.sizeOf(context).width < 600;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.grisMedium)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kAppTopBarHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
            // Une seule couche de verre pour tous les boutons de la barre
            // (mode groupé recommandé par liquid_glass_widgets).
            child: AdaptiveLiquidGlassLayer(
              settings: _verre,
              child: Row(
                children: [
                  Tooltip(
                    message: 'Menu',
                    child: GlassIconButton(
                      size: 40,
                      semanticLabel: 'Menu',
                      onPressed: onMenu,
                      icon: const Icon(Icons.menu_rounded,
                          color: AppColors.rouge),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tout l'espace libre ; réduit seulement sur très petit écran.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Tooltip(
                          message: 'Accueil',
                          child: InkWell(
                            onTap: employee == null
                                ? null
                                : () => context.go(accueilDe(employee)),
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.fromLTRB(4, 4, 8, 4),
                              child: _Marque(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (notifications != null)
                    Tooltip(
                      message: 'Notifications',
                      child: GlassIconButton(
                        size: 40,
                        semanticLabel: 'Notifications',
                        onPressed: () => context.go(notifications),
                        icon: const NotificationBadgeIcon(),
                      ),
                    ),
                  if (notifications != null && employee != null)
                    Container(
                      width: 1,
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: AppColors.grisMedium,
                    ),
                  if (employee != null) _MenuCompte(employee: employee),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo + nom de l'app. Joué une seule fois, à l'ouverture : le logo apparaît
/// avec un léger rebond, le nom glisse en place puis un reflet le traverse.
class _Marque extends StatelessWidget {
  const _Marque();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Clean', style: TextStyle(color: AppColors.noir)),
              TextSpan(text: 'Ops', style: TextStyle(color: AppColors.rouge)),
            ],
          ),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        )
            .animate()
            .fadeIn(delay: 250.ms, duration: 450.ms)
            .slideX(begin: -0.15, end: 0, curve: Curves.easeOutCubic)
            .then(delay: 150.ms)
            .shimmer(
              duration: 1200.ms,
              color: AppColors.rougeLight.withValues(alpha: 0.55),
            ),
      ],
    );
  }
}

enum _ActionCompte { profil, deconnexion }

class _MenuCompte extends ConsumerStatefulWidget {
  final Employee employee;

  const _MenuCompte({required this.employee});

  @override
  ConsumerState<_MenuCompte> createState() => _MenuCompteState();
}

class _MenuCompteState extends ConsumerState<_MenuCompte> {
  // La pastille de verre capte le toucher : elle ouvre le menu elle-même.
  final _menu = GlobalKey<PopupMenuButtonState<_ActionCompte>>();

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    return PopupMenuButton<_ActionCompte>(
      key: _menu,
      tooltip: 'Mon compte',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (action) {
        switch (action) {
          case _ActionCompte.profil:
            context.go(profilDe(employee));
          case _ActionCompte.deconnexion:
            _deconnecter(context, ref);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<_ActionCompte>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.nomComplet,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.noir,
                ),
              ),
              Text(
                employee.role.intitule.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.4,
                  color: AppColors.rouge,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _ActionCompte.profil,
          child: _LigneMenu(
            icone: Icons.person_outline_rounded,
            libelle: 'Mon profil',
          ),
        ),
        const PopupMenuItem(
          value: _ActionCompte.deconnexion,
          child: _LigneMenu(
            icone: Icons.logout_rounded,
            libelle: 'Se déconnecter',
            couleur: Color(0xFF9F2D2D),
          ),
        ),
      ],
      child: GlassButton.custom(
        onTap: () => _menu.currentState?.showButtonMenu(),
        label: 'Mon compte',
        height: 40,
        width: 72,
        shape: const LiquidRoundedSuperellipse(borderRadius: 20),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_circle_rounded,
                color: AppColors.rouge, size: 26),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.rouge, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _deconnecter(BuildContext context, WidgetRef ref) async {
    final confirme = await showDialog<bool>(
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
    if (confirme != true || !context.mounted) return;
    await ref.read(authNotifierProvider.notifier).logout();
    if (context.mounted) context.go(AppRoutes.login);
  }
}

class _LigneMenu extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final Color couleur;

  const _LigneMenu({
    required this.icone,
    required this.libelle,
    this.couleur = AppColors.noir,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 20, color: couleur),
        const SizedBox(width: 12),
        Text(libelle, style: TextStyle(fontSize: 14, color: couleur)),
      ],
    );
  }
}
