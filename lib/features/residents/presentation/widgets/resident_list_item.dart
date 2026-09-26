import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';
import '../../domain/entities/resident.dart';

/// Carte d'un résident (vue grille de la page Résidents).
class ResidentListItem extends StatelessWidget {
  final Resident resident;
  final VoidCallback onPin;
  final VoidCallback onDesactiver;
  final VoidCallback onActiver;

  /// Bascule « Inscrit à l'app » / « Sans app » (facultatif).
  final VoidCallback? onBasculerApplication;

  /// Conservé pour compatibilité (ancienne liste à lignes alternées).
  final bool isAlternate;

  const ResidentListItem({
    super.key,
    required this.resident,
    required this.onPin,
    required this.onDesactiver,
    required this.onActiver,
    this.onBasculerApplication,
    this.isAlternate = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = resident;
    return Container(
      decoration: BoxDecoration(
        color: r.isActif ? Colors.white : AppColors.grisLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grisMedium),
      ),
      padding: const EdgeInsets.fromLTRB(AppSizes.md, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarResident(resident: r, rayon: 22),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.nomComplet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: r.isActif ? AppColors.noir : AppColors.grisDark,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.apartment_rounded,
                        size: 14, color: AppColors.grisText),
                    const SizedBox(width: 4),
                    Text(
                      r.numeroAppartement != null
                          ? 'Apt ${r.numeroAppartement}'
                              '${r.tailleAppartement != null ? ' · ${r.tailleAppartement}' : ''}'
                          : 'Sans appartement',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.grisDark),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    BadgeApplicationResident(resident: r),
                    BadgePinResident(resident: r),
                  ],
                ),
              ],
            ),
          ),
          MenuResident(
            resident: r,
            onPin: onPin,
            onDesactiver: onDesactiver,
            onActiver: onActiver,
            onBasculerApplication: onBasculerApplication,
          ),
        ],
      ),
    );
  }
}

// ── Éléments partagés (grille et tableau) ──────────────────

class AvatarResident extends StatelessWidget {
  final Resident resident;
  final double rayon;
  const AvatarResident({super.key, required this.resident, this.rayon = 16});

  @override
  Widget build(BuildContext context) {
    final couleur = resident.isActif ? AppColors.rouge : AppColors.grisDark;
    return AvatarProfil(
      proprietaire:
          ProprietairePhoto(TypeProprietairePhoto.resident, resident.id),
      initiales: resident.initiales,
      rayon: rayon,
      couleurFond: couleur.withValues(alpha: 0.12),
      couleurTexte: couleur,
      tailleTexte: rayon * 0.7,
      poidsTexte: FontWeight.bold,
    );
  }
}

/// Inscrit à l'application / Sans app / Inactif.
class BadgeApplicationResident extends StatelessWidget {
  final Resident resident;
  const BadgeApplicationResident({super.key, required this.resident});

  @override
  Widget build(BuildContext context) {
    final r = resident;
    final (couleur, icone, texte) = !r.isActif
        ? (AppColors.grisDark, Icons.block_rounded, 'Inactif')
        : r.aApplication
            ? (AppColors.fait, Icons.phone_iphone_rounded, 'Inscrit')
            : (AppColors.aVerifier, Icons.phonelink_erase_rounded, 'Sans app');
    return Container(
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
}

/// PIN attribué ou non (seulement utile pour un résident inscrit à l'app).
class BadgePinResident extends StatelessWidget {
  final Resident resident;
  const BadgePinResident({super.key, required this.resident});

  @override
  Widget build(BuildContext context) {
    final a = resident.aPin;
    final couleur = a
        ? AppColors.fait
        : (resident.isActif && resident.aApplication
            ? AppColors.refus
            : AppColors.grisText);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(a ? Icons.key_rounded : Icons.key_off_rounded,
              size: 13, color: couleur),
          const SizedBox(width: 4),
          Text(
            a ? 'PIN attribué' : 'Sans PIN',
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: couleur),
          ),
        ],
      ),
    );
  }
}

enum _ActionResident { pin, application, desactiver, activer }

/// Actions d'un résident (⋮) : PIN, accès à l'application, (dés)activation.
class MenuResident extends StatelessWidget {
  final Resident resident;
  final VoidCallback onPin;
  final VoidCallback onDesactiver;
  final VoidCallback onActiver;
  final VoidCallback? onBasculerApplication;

  const MenuResident({
    super.key,
    required this.resident,
    required this.onPin,
    required this.onDesactiver,
    required this.onActiver,
    this.onBasculerApplication,
  });

  @override
  Widget build(BuildContext context) {
    final r = resident;
    PopupMenuItem<_ActionResident> item(
            _ActionResident a, IconData icone, String texte, Color c) =>
        PopupMenuItem(
          value: a,
          child: Row(
            children: [
              Icon(icone, size: 18, color: c),
              const SizedBox(width: 10),
              Text(texte),
            ],
          ),
        );

    return PopupMenuButton<_ActionResident>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.rouge),
      onSelected: (a) => switch (a) {
        _ActionResident.pin => onPin(),
        _ActionResident.application => onBasculerApplication?.call(),
        _ActionResident.desactiver => onDesactiver(),
        _ActionResident.activer => onActiver(),
      },
      itemBuilder: (_) => [
        if (r.isActif) ...[
          item(
              _ActionResident.pin,
              Icons.key_rounded,
              r.aPin ? 'Modifier le PIN' : 'Attribuer un PIN',
              AppColors.aVerifier),
          if (onBasculerApplication != null)
            r.aApplication
                ? item(
                    _ActionResident.application,
                    Icons.phonelink_erase_rounded,
                    'Passer en « Sans app »',
                    AppColors.grisDark)
                : item(_ActionResident.application, Icons.phone_iphone_rounded,
                    'Marquer inscrit à l’app', AppColors.fait),
          item(_ActionResident.desactiver, Icons.block_rounded, 'Désactiver',
              AppColors.refus),
        ] else
          item(_ActionResident.activer, Icons.check_circle_outline_rounded,
              'Réactiver', AppColors.fait),
      ],
    );
  }
}
