import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/jour_menage.dart';

/// Couleur, icône et libellés d'un statut de ménage côté résident (pastilles
/// du calendrier, légende, carte du détail).
extension StatutMenageVisuel on StatutMenageResident {
  Color get couleur => switch (this) {
        StatutMenageResident.prevu => AppColors.fait,
        StatutMenageResident.effectue => AppColors.fait,
        StatutMenageResident.reprogramme => const Color(0xFF1E6FD9),
        StatutMenageResident.annule => AppColors.nonAutorise,
        StatutMenageResident.refuse => AppColors.refus,
        StatutMenageResident.absent => AppColors.aVerifier,
        StatutMenageResident.autre => AppColors.nonCommence,
      };

  /// Fond léger de la carte du détail.
  Color get fond => switch (this) {
        StatutMenageResident.prevu ||
        StatutMenageResident.effectue =>
          AppColors.faitBg,
        StatutMenageResident.reprogramme => const Color(0xFFE8F1FC),
        StatutMenageResident.annule => const Color(0xFFFDECEE),
        StatutMenageResident.refuse => AppColors.refusBg,
        StatutMenageResident.absent => const Color(0xFFFFF8E1),
        StatutMenageResident.autre => AppColors.grisLight,
      };

  IconData get icone => switch (this) {
        StatutMenageResident.prevu => Icons.calendar_month_rounded,
        StatutMenageResident.effectue => Icons.check_rounded,
        StatutMenageResident.reprogramme => Icons.sync_rounded,
        StatutMenageResident.annule => Icons.close_rounded,
        StatutMenageResident.refuse => Icons.remove_rounded,
        StatutMenageResident.absent => Icons.priority_high_rounded,
        StatutMenageResident.autre => Icons.info_outline_rounded,
      };

  /// Libellé de la légende du calendrier.
  String get legende => switch (this) {
        StatutMenageResident.prevu => 'Ménage prévu',
        StatutMenageResident.effectue => 'Ménage effectué',
        StatutMenageResident.reprogramme => 'Reprogrammé',
        StatutMenageResident.annule => 'Annulé (à votre demande)',
        StatutMenageResident.refuse => 'Refusé',
        StatutMenageResident.absent => 'Absent (non autorisé)',
        StatutMenageResident.autre => 'Autre / information',
      };
}

extension JourMenageVisuel on JourMenage {
  /// Titre de la carte du détail : « Ménage prévu », « Ménage annulé »…
  String get titre => switch (statut) {
        StatutMenageResident.prevu => 'Ménage prévu',
        StatutMenageResident.effectue => 'Ménage effectué',
        StatutMenageResident.reprogramme => 'Ménage reprogrammé',
        StatutMenageResident.annule => 'Ménage annulé',
        StatutMenageResident.refuse => 'Ménage refusé',
        StatutMenageResident.absent => 'Absent (non autorisé)',
        StatutMenageResident.autre => 'Ménage non confirmé',
      };

  /// Précision sous le titre (« À votre demande »).
  String? get precision => statut == StatutMenageResident.annule
      ? (annuleParResident ? 'À votre demande' : 'Par l’équipe')
      : null;

  /// Explication affichée sous les informations.
  String get explication => switch (statut) {
        StatutMenageResident.prevu => 'Votre ménage est prévu à cette date.',
        StatutMenageResident.effectue =>
          'Votre ménage a été effectué à cette date.',
        StatutMenageResident.reprogramme =>
          'Votre ménage a été reprogrammé à cette date, comme convenu.',
        StatutMenageResident.annule => annuleParResident
            ? 'Ce ménage a été annulé à votre demande. Vous pouvez faire une '
                'demande pour reprendre ce ménage.'
            : 'Ce ménage a été annulé. Vous pouvez faire une demande pour le '
                'reprendre.',
        StatutMenageResident.refuse =>
          'Le ménage n’a pas été fait : il a été refusé à cette date.',
        StatutMenageResident.absent =>
          'La préposée n’a pas pu entrer : vous étiez absent et l’accès '
              'n’était pas autorisé.',
        StatutMenageResident.autre =>
          'Ce ménage n’a pas été confirmé par l’équipe.',
      };
}

/// « Vendredi 29 mai 2026 ».
String dateLongue(DateTime d) {
  final t = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(d);
  return '${t[0].toUpperCase()}${t.substring(1)}';
}

/// Pastille d'un jour du calendrier : numéro du jour, coloré selon le
/// statut de son ménage (ou neutre sans ménage).
class PastilleJour extends StatelessWidget {
  final int jour;
  final StatutMenageResident? statut;
  final bool aujourdhui;
  final double taille;

  const PastilleJour({
    super.key,
    required this.jour,
    required this.statut,
    this.aujourdhui = false,
    this.taille = 36,
  });

  @override
  Widget build(BuildContext context) {
    final s = statut;
    final texte = Text(
      '$jour',
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: s == null ? FontWeight.w500 : FontWeight.w700,
        color: s == null
            ? AppColors.noir
            : s == StatutMenageResident.absent ||
                    s == StatutMenageResident.autre
                ? AppColors.noir
                : Colors.white,
      ),
    );

    final Widget contenu = switch (s) {
      null => texte,
      // Icône à la place du numéro, comme sur la maquette.
      StatutMenageResident.reprogramme ||
      StatutMenageResident.annule ||
      StatutMenageResident.refuse =>
        Icon(s.icone, size: taille * 0.55, color: Colors.white),
      StatutMenageResident.effectue => Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: taille * 0.18),
              child: texte,
            ),
            Positioned(
              bottom: taille * 0.08,
              child: Icon(Icons.check_rounded,
                  size: taille * 0.34, color: Colors.white),
            ),
          ],
        ),
      _ => texte,
    };

    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: s?.couleur,
        border: s == null && aujourdhui
            ? Border.all(color: AppColors.rouge, width: 1.6)
            : null,
      ),
      child: contenu,
    );
  }
}

/// Légende du calendrier (tous les statuts).
class LegendeCalendrier extends StatelessWidget {
  const LegendeCalendrier({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Légende',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.noir,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            for (final s in StatutMenageResident.values)
              SizedBox(
                width: 220,
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                          color: s.couleur, shape: BoxShape.circle),
                      child: s == StatutMenageResident.prevu
                          ? null
                          : Icon(s.icone,
                              size: 13,
                              color: s == StatutMenageResident.absent ||
                                      s == StatutMenageResident.autre
                                  ? AppColors.noir
                                  : Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.legende,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.noir),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
