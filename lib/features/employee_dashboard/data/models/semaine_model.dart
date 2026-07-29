import '../../domain/entities/semaine.dart';

class JourSemaineModel extends JourSemaine {
  const JourSemaineModel({
    required super.date,
    required super.nom,
    required super.numeroTaches,
    required super.tachesConfirmees,
    required super.totalMinutes,
    required super.statut,
  });

  factory JourSemaineModel.fromTaches({
    required DateTime date,
    required String nom,
    required List<Map<String, dynamic>> taches,
  }) {
    final total = taches.length;
    final confirmees = taches.where((t) => t['statut'] != 'NonCommencé').length;
    final minutes = taches.fold<int>(0, (sum, t) {
      final appartement = t['appartements'] as Map<String, dynamic>?;
      final minutesBase = appartement?['minutes_base'] as int? ?? 0;
      return sum + ((t['minutes_finales'] as int?) ?? minutesBase);
    });

    StatutJour statut;
    if (total == 0 || confirmees == 0) {
      statut = StatutJour.nonCommence;
    } else if (confirmees == total) {
      statut = StatutJour.complete;
    } else {
      statut = StatutJour.enCours;
    }

    return JourSemaineModel(
      date: date,
      nom: nom,
      numeroTaches: total,
      tachesConfirmees: confirmees,
      totalMinutes: minutes,
      statut: statut,
    );
  }
}

class SemaineModel extends Semaine {
  const SemaineModel({
    required super.numeroSemaine,
    required super.lundiDate,
    required super.jours,
    super.messageSemaine,
  });
}
