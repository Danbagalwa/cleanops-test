import '../../tache_jour/domain/entities/tache_jour.dart';
import 'entities/jour_menage.dart';

const _joursPlanning = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

String? _nomComplet(Object? employe) {
  if (employe is! Map) return null;
  final nom = [employe['prenom'], employe['nom']]
      .whereType<String>()
      .where((p) => p.trim().isNotEmpty)
      .join(' ')
      .trim();
  return nom.isEmpty ? null : nom;
}

/// Calendrier des ménages d'un appartement du [debut] au [fin] inclus, à
/// partir des lignes brutes de la base :
/// - [taches] : `taches_jour` (id, semaine_reelle = date RÉELLE, periode,
///   statut, employees(prenom, nom)) ;
/// - [templates] : planning récurrent (numero_semaine, jour, periode,
///   employees(prenom, nom)), projeté sur les jours à venir pas encore
///   générés en tâches ;
/// - [demandes] : demandes du résident (type, tache_jour_id,
///   resident_accepte, proposition_date, proposition_periode), pour
///   reconnaître une annulation à sa demande et une date reprogrammée.
///
/// [semainePourDate] donne la semaine du cycle (1 à 4) d'une date.
CalendrierMenages construireCalendrier({
  required List<Map<String, dynamic>> taches,
  required List<Map<String, dynamic>> templates,
  required List<Map<String, dynamic>> demandes,
  required DateTime debut,
  required DateTime fin,
  required DateTime aujourdhui,
  required int Function(DateTime) semainePourDate,
}) {
  final auj = _jour(aujourdhui);

  final annulesParResident = {
    for (final d in demandes)
      if (d['type'] == 'Annuler' && d['tache_jour_id'] is String)
        d['tache_jour_id'] as String,
  };
  // Nouvelles dates acceptées par le résident : date → période.
  final reprogrammes = <String, String?>{
    for (final d in demandes)
      if (d['type'] == 'Reprogrammer' &&
          d['resident_accepte'] == true &&
          d['proposition_date'] is String)
        (d['proposition_date'] as String).substring(0, 10):
            d['proposition_periode'] as String?,
  };

  final jours = <JourMenage>[];
  final datesAvecTache = <String>{};

  for (final t in taches) {
    final date = _jour(DateTime.parse(t['semaine_reelle'] as String));
    final iso = _iso(date);
    datesAvecTache.add(iso);
    final id = t['id'] as String?;
    final statut = switch (t['statut']) {
      'Fait' => StatutMenageResident.effectue,
      'Annulé' => StatutMenageResident.annule,
      'Refus' => StatutMenageResident.refuse,
      'Absent' => StatutMenageResident.absent,
      // Non commencé : à venir, ou jamais confirmé s'il est passé.
      _ => date.isBefore(auj)
          ? StatutMenageResident.autre
          : reprogrammes.containsKey(iso)
              ? StatutMenageResident.reprogramme
              : StatutMenageResident.prevu,
    };
    jours.add(JourMenage(
      date: date,
      periode: PeriodeTypeExtension.fromString(t['periode'] as String? ?? 'AM'),
      statut: statut,
      tacheJourId: id,
      preposee: _nomComplet(
          t['employees!taches_jour_employee_id_fkey'] ?? t['employees']),
      annuleParResident: statut == StatutMenageResident.annule &&
          annulesParResident.contains(id),
    ));
  }

  // Jours à venir pas encore générés : projection du planning récurrent.
  final debutProjection = debut.isAfter(auj) ? _jour(debut) : auj;
  for (var date = debutProjection;
      !date.isAfter(fin);
      date = DateTime(date.year, date.month, date.day + 1)) {
    final iso = _iso(date);
    if (datesAvecTache.contains(iso)) continue;
    final nomJour = _joursPlanning[date.weekday - 1];
    for (final tpl in templates) {
      if (tpl['numero_semaine'] == semainePourDate(date) &&
          tpl['jour'] == nomJour) {
        jours.add(JourMenage(
          date: date,
          periode: PeriodeTypeExtension.fromString(
              tpl['periode'] as String? ?? 'AM'),
          statut: reprogrammes.containsKey(iso)
              ? StatutMenageResident.reprogramme
              : StatutMenageResident.prevu,
          preposee: _nomComplet(
              tpl['employees!planning_templates_employee_id_fkey'] ??
                  tpl['employees']),
        ));
      }
    }
  }

  // Date reprogrammée sans ménage encore planifié ce jour-là.
  for (final e in reprogrammes.entries) {
    final date = DateTime.parse(e.key);
    if (date.isBefore(_jour(debut)) || date.isAfter(fin)) continue;
    if (jours.any((j) => _iso(j.date) == e.key)) continue;
    jours.add(JourMenage(
      date: date,
      periode: PeriodeTypeExtension.fromString(e.value ?? 'AM'),
      statut: StatutMenageResident.reprogramme,
    ));
  }

  jours.sort((a, b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : a.periode.index.compareTo(b.periode.index);
  });

  return CalendrierMenages(
    jours: jours,
    semainesParCycle: {for (final t in templates) t['numero_semaine']}.length,
  );
}
