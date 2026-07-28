import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/domain/entities/employee.dart';

// Libellé UI par rôle
String roleDisplay(RoleType role) {
  switch (role) {
    case RoleType.employe:
      return 'Préposée';
    case RoleType.superviseurMenage:
      return 'Superviseur ménage';
    case RoleType.direction:
      return 'Direction';
    case RoleType.reception:
      return 'Réception';
    case RoleType.admin:
      return 'Admin';
    case RoleType.resident:
      return 'Résident';
  }
}

Color roleColor(RoleType role) {
  switch (role) {
    case RoleType.employe:
      return AppColors.jourVert;
    case RoleType.superviseurMenage:
      return AppColors.absent;
    case RoleType.direction:
      return AppColors.rouge;
    case RoleType.reception:
      return AppColors.aVerifier;
    case RoleType.admin:
      return AppColors.grisDark;
    case RoleType.resident:
      return AppColors.grisDark;
  }
}

class EmployeListItem extends StatelessWidget {
  final Employee employe;
  final VoidCallback onEdit;
  final VoidCallback onToggleActif;

  const EmployeListItem({
    super.key,
    required this.employe,
    required this.onEdit,
    required this.onToggleActif,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return isDesktop ? _buildRow(context) : _buildCard(context);
  }

  // ── Desktop : ligne fine type tableau ────────────────────
  Widget _buildRow(BuildContext context) {
    final color = roleColor(employe.role);
    final initials = _initials(employe.prenom, employe.nom);

    return Opacity(
      opacity: employe.isActif ? 1.0 : 0.55,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onEdit,
          hoverColor: AppColors.rouge.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Text(
                        employe.nomComplet,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.noir,
                        ),
                      ),
                      if (!employe.isActif) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.grisMedium,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Inactif',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.grisDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _RoleBadge(role: employe.role),
                ),
                Expanded(
                  child: employe.numeroPointeuse != null
                      ? Row(
                          children: [
                            const Icon(
                              Icons.fingerprint_rounded,
                              size: 13,
                              color: AppColors.grisText,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              employe.numeroPointeuse!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.grisText,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          '—',
                          style: TextStyle(
                            color: AppColors.grisMedium,
                            fontSize: 13,
                          ),
                        ),
                ),
                SizedBox(
                  width: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _IconBtn(
                        icon: Icons.edit_outlined,
                        tooltip: 'Modifier',
                        color: AppColors.absent,
                        onTap: onEdit,
                      ),
                      _IconBtn(
                        icon: employe.isActif
                            ? Icons.person_off_outlined
                            : Icons.person_outlined,
                        tooltip: employe.isActif ? 'Désactiver' : 'Activer',
                        color: employe.isActif
                            ? AppColors.refus
                            : AppColors.jourVert,
                        onTap: onToggleActif,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mobile : carte ───────────────────────────────────────
  Widget _buildCard(BuildContext context) {
    final color = roleColor(employe.role);
    final initials = _initials(employe.prenom, employe.nom);

    return Opacity(
      opacity: employe.isActif ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: 10,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            employe.nomComplet,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.noir,
                            ),
                          ),
                          if (!employe.isActif) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.grisMedium,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Inactif',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.grisDark,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _RoleBadge(role: employe.role),
                          if (employe.numeroPointeuse != null) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.fingerprint_rounded,
                              size: 12,
                              color: AppColors.grisText,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              employe.numeroPointeuse!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.grisText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.absent,
                  onPressed: onEdit,
                  tooltip: 'Modifier',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(
                    employe.isActif
                        ? Icons.person_off_outlined
                        : Icons.person_outlined,
                    size: 18,
                  ),
                  color:
                      employe.isActif ? AppColors.refus : AppColors.jourVert,
                  onPressed: onToggleActif,
                  tooltip: employe.isActif ? 'Désactiver' : 'Activer',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String prenom, String nom) {
    final p = prenom.isNotEmpty ? prenom[0].toUpperCase() : '';
    final n = nom.isNotEmpty ? nom[0].toUpperCase() : '';
    return '$p$n';
  }
}

class _RoleBadge extends StatelessWidget {
  final RoleType role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        roleDisplay(role),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
