import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';

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

String initialesEmploye(Employee e) {
  final p = e.prenom.isNotEmpty ? e.prenom[0].toUpperCase() : '';
  final n = e.nom.isNotEmpty ? e.nom[0].toUpperCase() : '';
  return '$p$n';
}

/// Carte d'un employé (vue grille de la page Employés).
class EmployeListItem extends StatelessWidget {
  final Employee employe;
  final VoidCallback onEdit;
  final VoidCallback onToggleActif;

  /// Ouvre le planning (préposées uniquement).
  final VoidCallback? onPlanning;

  const EmployeListItem({
    super.key,
    required this.employe,
    required this.onEdit,
    required this.onToggleActif,
    this.onPlanning,
  });

  @override
  Widget build(BuildContext context) {
    final e = employe;
    final couleur = roleColor(e.role);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grisMedium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.md, 12, 4, 12),
            child: Row(
              children: [
                Opacity(
                  opacity: e.isActif ? 1 : 0.5,
                  child: AvatarProfil(
                    proprietaire: ProprietairePhoto.de(e),
                    initiales: initialesEmploye(e),
                    rayon: 22,
                    couleurFond: couleur.withValues(alpha: 0.15),
                    couleurTexte: couleur,
                    tailleTexte: 15,
                    poidsTexte: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.nomComplet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color:
                              e.isActif ? AppColors.noir : AppColors.grisDark,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          BadgeRole(role: e.role),
                          BadgeStatutEmploye(actif: e.isActif),
                          if (e.numeroPointeuse != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fingerprint_rounded,
                                    size: 13, color: AppColors.grisText),
                                const SizedBox(width: 2),
                                Text(
                                  e.numeroPointeuse!,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.grisText),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                MenuEmploye(
                  employe: e,
                  onEdit: onEdit,
                  onToggleActif: onToggleActif,
                  onPlanning: onPlanning,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BadgeRole extends StatelessWidget {
  final RoleType role;
  const BadgeRole({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final couleur = roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        roleDisplay(role),
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w600, color: couleur),
      ),
    );
  }
}

class BadgeStatutEmploye extends StatelessWidget {
  final bool actif;
  const BadgeStatutEmploye({super.key, required this.actif});

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? AppColors.fait : AppColors.grisDark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          actif ? 'Actif' : 'Inactif',
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w600, color: couleur),
        ),
      ],
    );
  }
}

enum _ActionEmploye { modifier, planning, statut }

/// Actions d'un employé (⋮) : modifier, voir son planning, (dés)activer.
class MenuEmploye extends StatelessWidget {
  final Employee employe;
  final VoidCallback onEdit;
  final VoidCallback onToggleActif;
  final VoidCallback? onPlanning;

  const MenuEmploye({
    super.key,
    required this.employe,
    required this.onEdit,
    required this.onToggleActif,
    this.onPlanning,
  });

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<_ActionEmploye> item(
            _ActionEmploye a, IconData icone, String texte, Color couleur) =>
        PopupMenuItem(
          value: a,
          child: Row(
            children: [
              Icon(icone, size: 18, color: couleur),
              const SizedBox(width: 10),
              Text(texte),
            ],
          ),
        );

    return PopupMenuButton<_ActionEmploye>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.rouge),
      onSelected: (a) => switch (a) {
        _ActionEmploye.modifier => onEdit(),
        _ActionEmploye.planning => onPlanning?.call(),
        _ActionEmploye.statut => onToggleActif(),
      },
      itemBuilder: (_) => [
        item(_ActionEmploye.modifier, Icons.edit_outlined, 'Modifier',
            AppColors.absent),
        if (onPlanning != null)
          item(_ActionEmploye.planning, Icons.calendar_month_rounded,
              'Voir son planning', AppColors.rouge),
        employe.isActif
            ? item(_ActionEmploye.statut, Icons.person_off_outlined,
                'Désactiver', AppColors.refus)
            : item(_ActionEmploye.statut, Icons.person_outlined, 'Activer',
                AppColors.jourVert),
      ],
    );
  }
}
