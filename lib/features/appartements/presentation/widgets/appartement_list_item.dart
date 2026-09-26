import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../domain/entities/appartement.dart';

const taillesAppartement = ['2 1/2', '3 1/2', '4 1/2', '5 1/2'];

/// Couleur associée à une taille (la même partout : planning, listes).
Color couleurTaille(String taille) => switch (taille) {
      '2 1/2' => AppColors.jourVert,
      '3 1/2' => AppColors.absent,
      '4 1/2' => AppColors.rouge,
      '5 1/2' => AppColors.aVerifier,
      _ => AppColors.grisDark,
    };

/// « 3 1/2 » → « 3½ ».
String tailleCourte(String taille) => taille.replaceAll(' 1/2', '½');

/// Tri naturel des numéros : « 2 » avant « 10 », « 101 » avant « 1001 ».
int comparerNumeros(String a, String b) {
  final chiffres = RegExp(r'\d+');
  final na = chiffres.firstMatch(a);
  final nb = chiffres.firstMatch(b);
  if (na != null && nb != null) {
    final c = int.parse(na[0]!).compareTo(int.parse(nb[0]!));
    if (c != 0) return c;
  }
  return a.toLowerCase().compareTo(b.toLowerCase());
}

/// Carte d'un appartement (vue grille de la page Appartements).
class AppartementListItem extends StatelessWidget {
  final Appartement appartement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Conservé pour compatibilité (ancienne liste à lignes alternées).
  final bool isAlternate;

  const AppartementListItem({
    super.key,
    required this.appartement,
    required this.onEdit,
    required this.onDelete,
    this.isAlternate = false,
  });

  @override
  Widget build(BuildContext context) {
    final a = appartement;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconeAppartement(taille: a.taille, dimension: 44),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appartement ${a.numero}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.noir,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          BadgeTaille(taille: a.taille),
                          DureeAppartement(minutes: a.minutesBase),
                          if (a.hasAnimal) AnimalAppartement(appartement: a),
                        ],
                      ),
                      if (a.notes != null && a.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.sticky_note_2_outlined,
                                size: 14, color: AppColors.grisText),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                a.notes!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: AppColors.grisDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                MenuAppartement(onEdit: onEdit, onDelete: onDelete),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class IconeAppartement extends StatelessWidget {
  final String taille;
  final double dimension;
  const IconeAppartement(
      {super.key, required this.taille, this.dimension = 32});

  @override
  Widget build(BuildContext context) {
    final couleur = couleurTaille(taille);
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(dimension * 0.28),
      ),
      child:
          Icon(Icons.apartment_rounded, color: couleur, size: dimension * 0.55),
    );
  }
}

class BadgeTaille extends StatelessWidget {
  final String taille;
  const BadgeTaille({super.key, required this.taille});

  @override
  Widget build(BuildContext context) {
    final couleur = couleurTaille(taille);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tailleCourte(taille),
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: couleur),
      ),
    );
  }
}

class DureeAppartement extends StatelessWidget {
  final int minutes;
  const DureeAppartement({super.key, required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.schedule_rounded, size: 14, color: AppColors.grisText),
        const SizedBox(width: 3),
        Text(
          DateHelper.minutesEnHeures(minutes),
          style: const TextStyle(fontSize: 12.5, color: AppColors.grisDark),
        ),
      ],
    );
  }
}

class AnimalAppartement extends StatelessWidget {
  final Appartement appartement;
  const AnimalAppartement({super.key, required this.appartement});

  @override
  Widget build(BuildContext context) {
    final type = appartement.typeAnimal?.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.aVerifier.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pets_rounded, size: 13, color: AppColors.aVerifier),
          const SizedBox(width: 4),
          Text(
            type == null || type.isEmpty ? 'Animal' : type,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.aVerifier,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ActionAppartement { modifier, supprimer }

/// Actions d'un appartement (⋮) : modifier, supprimer.
class MenuAppartement extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MenuAppartement(
      {super.key, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<_ActionAppartement> item(
            _ActionAppartement a, IconData icone, String texte, Color c) =>
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

    return PopupMenuButton<_ActionAppartement>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.rouge),
      onSelected: (a) => switch (a) {
        _ActionAppartement.modifier => onEdit(),
        _ActionAppartement.supprimer => onDelete(),
      },
      itemBuilder: (_) => [
        item(_ActionAppartement.modifier, Icons.edit_outlined, 'Modifier',
            AppColors.absent),
        item(_ActionAppartement.supprimer, Icons.delete_outline_rounded,
            'Supprimer', AppColors.refus),
      ],
    );
  }
}
