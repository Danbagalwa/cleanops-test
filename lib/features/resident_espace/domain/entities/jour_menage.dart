import '../../../tache_jour/domain/entities/tache_jour.dart';

/// Ce que le résident voit d'un ménage dans son calendrier.
enum StatutMenageResident {
  /// À venir (planifié, ou projeté depuis le planning récurrent).
  prevu,

  /// Fait par la préposée.
  effectue,

  /// Nouvelle date acceptée par le résident après une demande.
  reprogramme,

  /// Annulé (à la demande du résident, ou par l'équipe).
  annule,

  /// Le résident a refusé le ménage.
  refuse,

  /// Le résident était absent sans avoir donné l'accès.
  absent,

  /// Autre cas, pour information (ex. ménage passé jamais confirmé).
  autre,
}

/// Un ménage de l'appartement, à une date (AM ou PM).
class JourMenage {
  final DateTime date;
  final PeriodeType periode;
  final StatutMenageResident statut;

  /// Ligne `taches_jour` (null pour une projection du planning récurrent).
  final String? tacheJourId;

  /// « Prénom Nom » de la préposée, si connue.
  final String? preposee;

  /// Annulé à la demande du résident (demande « Annuler » sur ce ménage).
  final bool annuleParResident;

  const JourMenage({
    required this.date,
    required this.periode,
    required this.statut,
    this.tacheJourId,
    this.preposee,
    this.annuleParResident = false,
  });

  String get periodeCourte => periode == PeriodeType.am ? 'AM' : 'PM';
}

/// Ménages d'une période, et le rythme du planning de l'appartement.
class CalendrierMenages {
  final List<JourMenage> jours;

  /// Nombre de semaines du cycle de 4 où l'appartement a un ménage.
  final int semainesParCycle;

  const CalendrierMenages(
      {required this.jours, required this.semainesParCycle});

  /// Ménages d'un jour, du matin à l'après-midi.
  List<JourMenage> du(DateTime date) => [
        for (final j in jours)
          if (j.date.year == date.year &&
              j.date.month == date.month &&
              j.date.day == date.day)
            j,
      ]..sort((a, b) => a.periode.index.compareTo(b.periode.index));

  /// « Chaque semaine », « Aux 2 semaines »… (planning sur 4 semaines).
  String get frequence => switch (semainesParCycle) {
        0 => 'Non planifiée',
        1 => 'Aux 4 semaines',
        2 => 'Aux 2 semaines',
        3 => '3 semaines sur 4',
        _ => 'Chaque semaine',
      };
}
