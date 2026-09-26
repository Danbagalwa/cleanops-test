import 'package:cleanops/features/resident_espace/domain/construire_calendrier.dart';
import 'package:cleanops/features/resident_espace/domain/entities/jour_menage.dart';
import 'package:cleanops/features/tache_jour/domain/entities/tache_jour.dart';
import 'package:flutter_test/flutter_test.dart';

// Aujourd'hui : mercredi 20 mai 2026 ; calendrier de mai 2026.
final _auj = DateTime(2026, 5, 20);
final _debut = DateTime(2026, 5, 1);
final _fin = DateTime(2026, 5, 31);

Map<String, dynamic> _tache(String id, String date, String statut,
        {String periode = 'AM'}) =>
    {
      'id': id,
      'semaine_reelle': date,
      'jour': 'Lundi',
      'periode': periode,
      'statut': statut,
      'employees!taches_jour_employee_id_fkey': {
        'prenom': 'Marie-Andrée',
        'nom': 'Beaulieu',
      },
    };

CalendrierMenages _calendrier({
  List<Map<String, dynamic>> taches = const [],
  List<Map<String, dynamic>> templates = const [],
  List<Map<String, dynamic>> demandes = const [],
}) =>
    construireCalendrier(
      taches: taches,
      templates: templates,
      demandes: demandes,
      debut: _debut,
      fin: _fin,
      aujourdhui: _auj,
      // Toutes les semaines sont la semaine 1 du cycle.
      semainePourDate: (_) => 1,
    );

JourMenage _seul(CalendrierMenages c, DateTime d) => c.du(d).single;

void main() {
  test('statuts des ménages réels', () {
    final c = _calendrier(taches: [
      _tache('a', '2026-05-13', 'Fait', periode: 'PM'),
      _tache('b', '2026-05-08', 'Absent'),
      _tache('c', '2026-05-11', 'Refus'),
      _tache('d', '2026-05-06', 'NonCommencé'),
      _tache('e', '2026-05-29', 'NonCommencé'),
    ]);

    final fait = _seul(c, DateTime(2026, 5, 13));
    expect(fait.statut, StatutMenageResident.effectue);
    expect(fait.periode, PeriodeType.pm);
    expect(fait.preposee, 'Marie-Andrée Beaulieu');
    expect(_seul(c, DateTime(2026, 5, 8)).statut, StatutMenageResident.absent);
    expect(_seul(c, DateTime(2026, 5, 11)).statut, StatutMenageResident.refuse);
    expect(_seul(c, DateTime(2026, 5, 6)).statut, StatutMenageResident.autre,
        reason: 'passé et jamais confirmé');
    expect(_seul(c, DateTime(2026, 5, 29)).statut, StatutMenageResident.prevu);
  });

  test('annulé à la demande du résident, ou par l’équipe', () {
    final c = _calendrier(
      taches: [
        _tache('a', '2026-05-21', 'Annulé', periode: 'PM'),
        _tache('b', '2026-05-22', 'Annulé'),
      ],
      demandes: [
        {'type': 'Annuler', 'tache_jour_id': 'a'},
      ],
    );

    final parResident = _seul(c, DateTime(2026, 5, 21));
    expect(parResident.statut, StatutMenageResident.annule);
    expect(parResident.annuleParResident, isTrue);
    expect(parResident.tacheJourId, 'a');
    expect(_seul(c, DateTime(2026, 5, 22)).annuleParResident, isFalse);
  });

  test('le planning récurrent est projeté sur les jours à venir seulement', () {
    final c = _calendrier(
      taches: [_tache('x', '2026-05-25', 'NonCommencé')],
      templates: [
        {
          'id': 't1',
          'numero_semaine': 1,
          'jour': 'Lundi',
          'periode': 'AM',
        },
      ],
    );

    // Lundis de mai : 4, 11, 18 (passés, pas projetés), 25 (tâche réelle).
    expect(c.du(DateTime(2026, 5, 18)), isEmpty);
    expect(c.du(DateTime(2026, 5, 25)).single.tacheJourId, 'x',
        reason: 'pas de doublon avec la tâche réelle');
    expect(c.jours.where((j) => j.tacheJourId == null), isEmpty);
  });

  test('une date reprogrammée acceptée apparaît comme reprogrammée', () {
    final c = _calendrier(demandes: [
      {
        'type': 'Reprogrammer',
        'resident_accepte': true,
        'proposition_date': '2026-05-27',
        'proposition_periode': 'PM',
      },
      {
        'type': 'Reprogrammer',
        'resident_accepte': null,
        'proposition_date': '2026-05-28',
      },
    ]);

    final r = _seul(c, DateTime(2026, 5, 27));
    expect(r.statut, StatutMenageResident.reprogramme);
    expect(r.periode, PeriodeType.pm);
    expect(c.du(DateTime(2026, 5, 28)), isEmpty,
        reason: 'proposition pas encore acceptée');
  });

  test('fréquence selon les semaines du cycle', () {
    CalendrierMenages avec(List<int> semaines) => _calendrier(templates: [
          for (final s in semaines)
            {'id': '$s', 'numero_semaine': s, 'jour': 'Mardi', 'periode': 'AM'},
        ]);
    expect(avec([]).frequence, 'Non planifiée');
    expect(avec([2]).frequence, 'Aux 4 semaines');
    expect(avec([1, 3]).frequence, 'Aux 2 semaines');
    expect(avec([1, 2, 3, 4]).frequence, 'Chaque semaine');
  });
}
