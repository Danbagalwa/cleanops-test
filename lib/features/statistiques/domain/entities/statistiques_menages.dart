import '../../../tache_jour/domain/entities/tache_jour.dart' show StatutTache;

/// Un ménage planifié sur la période (une ligne de `taches_jour`).
class MenageStat {
  final DateTime date;

  /// `AM` ou `PM`.
  final String periode;
  final StatutTache statut;
  final String? employeId;
  final String employeNom;
  final String appartementId;
  final String numero;
  final String taille;

  /// Ajouté à la main au planning (hors planning récurrent).
  final bool ajoute;

  const MenageStat({
    required this.date,
    required this.periode,
    required this.statut,
    required this.employeId,
    required this.employeNom,
    required this.appartementId,
    required this.numero,
    required this.taille,
    required this.ajoute,
  });
}

/// Effectifs d'un regroupement (jour, préposée, appartement).
class Comptes {
  int total = 0;
  int fait = 0;
  int nonCommence = 0;
  int absent = 0;
  int refus = 0;
  int annule = 0;

  void ajouter(StatutTache s) {
    total++;
    switch (s) {
      case StatutTache.fait:
        fait++;
      case StatutTache.nonCommence:
        nonCommence++;
      case StatutTache.absent:
        absent++;
      case StatutTache.refus:
        refus++;
      case StatutTache.annule:
        annule++;
    }
  }

  int de(StatutTache s) => switch (s) {
        StatutTache.fait => fait,
        StatutTache.nonCommence => nonCommence,
        StatutTache.absent => absent,
        StatutTache.refus => refus,
        StatutTache.annule => annule,
      };

  /// Ménages non effectués (tout sauf « Fait »).
  int get nonRealises => total - fait;

  /// Absences et refus : ce qui empêche le ménage côté résident.
  int get problemes => absent + refus;

  /// Part des ménages faits, sur ceux qui n'ont pas été annulés.
  double get taux {
    final base = total - annule;
    return base <= 0 ? 0 : fait * 100 / base;
  }
}

class StatJour {
  final DateTime date;
  final Comptes comptes;
  const StatJour(this.date, this.comptes);
}

class StatPreposee {
  final String? id;
  final String nom;
  final Comptes comptes;
  const StatPreposee(this.id, this.nom, this.comptes);
}

class StatAppartement {
  final String id;
  final String numero;
  final String taille;
  final Comptes comptes;
  const StatAppartement(this.id, this.numero, this.taille, this.comptes);
}

/// Chiffres clés des ménages sur une période, calculés à partir des ménages
/// planifiés.
class StatistiquesMenages {
  final DateTime dateDebut;
  final DateTime dateFin;
  final List<MenageStat> menages;

  StatistiquesMenages({
    required this.dateDebut,
    required this.dateFin,
    required this.menages,
  });

  /// Nombre de jours de la période, bornes comprises.
  int get nbJours => dateFin.difference(dateDebut).inDays + 1;

  /// Même période, limitée aux ménages d'une préposée (`null` : toutes).
  StatistiquesMenages pour(String? employeId) => employeId == null
      ? this
      : StatistiquesMenages(
          dateDebut: dateDebut,
          dateFin: dateFin,
          menages: [
            for (final m in menages)
              if (m.employeId == employeId) m,
          ],
        );

  late final Comptes comptes = () {
    final c = Comptes();
    for (final m in menages) {
      c.ajouter(m.statut);
    }
    return c;
  }();

  /// Réalisés le matin et l'après-midi.
  late final ({int matin, int apresMidi}) faitsParPeriode = (
    matin: menages
        .where((m) => m.statut == StatutTache.fait && m.periode == 'AM')
        .length,
    apresMidi: menages
        .where((m) => m.statut == StatutTache.fait && m.periode != 'AM')
        .length,
  );

  int get ajoutes => menages.where((m) => m.ajoute).length;

  /// Un point par jour de la période qui a des ménages, dans l'ordre.
  late final List<StatJour> parJour = () {
    final acc = <DateTime, Comptes>{};
    for (final m in menages) {
      acc.putIfAbsent(m.date, Comptes.new).ajouter(m.statut);
    }
    final jours = acc.keys.toList()..sort();
    return [for (final j in jours) StatJour(j, acc[j]!)];
  }();

  /// Préposées, de la meilleure réalisation à la plus faible.
  late final List<StatPreposee> parPreposee = () {
    final acc = <String?, Comptes>{};
    final noms = <String?, String>{};
    for (final m in menages) {
      acc.putIfAbsent(m.employeId, Comptes.new).ajouter(m.statut);
      noms[m.employeId] = m.employeNom;
    }
    return [
      for (final e in acc.entries) StatPreposee(e.key, noms[e.key]!, e.value),
    ]..sort((a, b) {
        final t = b.comptes.taux.compareTo(a.comptes.taux);
        return t != 0 ? t : b.comptes.total.compareTo(a.comptes.total);
      });
  }();

  /// Appartements qui ont eu au moins une absence ou un refus, les plus
  /// touchés d'abord.
  late final List<StatAppartement> appartementsASurveiller = () {
    final acc = <String, Comptes>{};
    final infos = <String, MenageStat>{};
    for (final m in menages) {
      acc.putIfAbsent(m.appartementId, Comptes.new).ajouter(m.statut);
      infos[m.appartementId] = m;
    }
    return [
      for (final e in acc.entries)
        if (e.value.problemes > 0)
          StatAppartement(
              e.key, infos[e.key]!.numero, infos[e.key]!.taille, e.value),
    ]..sort((a, b) {
        final p = b.comptes.problemes.compareTo(a.comptes.problemes);
        return p != 0 ? p : a.numero.compareTo(b.numero);
      });
  }();

  /// Préposées présentes sur la période (pour le filtre), par nom.
  late final List<({String id, String nom})> preposees = () {
    final vus = <String, String>{};
    for (final m in menages) {
      if (m.employeId != null) vus[m.employeId!] = m.employeNom;
    }
    return [
      for (final e in vus.entries) (id: e.key, nom: e.value),
    ]..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
  }();
}
