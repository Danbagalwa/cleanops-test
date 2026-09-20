import 'package:flutter_test/flutter_test.dart';
import 'package:cleanops/features/reception/domain/reception_models.dart';

StatutDuJour _statut(Map<String, dynamic> json) => StatutDuJour.fromJson(json);

void main() {
  group('Libellés du statut du jour (les 7 états, mot pour mot)', () {
    test('aucun, avec prochaine date', () {
      final s = _statut({
        'etat': 'aucun',
        'prochaine': {'date': '2026-09-21', 'jour': 'Lundi', 'periode': 'AM'},
      });
      expect(
        s.libelle,
        "Pas de ménage prévu aujourd'hui — prochain : 21/09/2026 AM",
      );
    });

    test('aucun, sans aucune date connue', () {
      expect(
        _statut({'etat': 'aucun'}).libelle,
        "Pas de ménage prévu aujourd'hui — aucun prochain ménage planifié",
      );
    });

    test('prévu', () {
      expect(
        _statut({'etat': 'prevu', 'periode': 'AM', 'employe_prenom': 'Essie'})
            .libelle,
        "Prévu aujourd'hui AM — Essie",
      );
    });

    test('confirmé', () {
      expect(
        _statut({'etat': 'confirme', 'periode': 'PM', 'employe_prenom': 'Essie'})
            .libelle,
        "Confirmé pour aujourd'hui PM — Essie",
      );
    });

    test('transféré : le nom est celui du nouvel employé', () {
      expect(
        _statut({'etat': 'transfere', 'periode': 'PM', 'employe_prenom': 'Bea'})
            .libelle,
        "Aujourd'hui PM — Bea",
      );
    });

    test('libéré : en attente d\'attribution, sans nom', () {
      expect(
        _statut({'etat': 'libere', 'periode': 'AM', 'employe_prenom': 'Essie'})
            .libelle,
        "Aujourd'hui AM — en attente d'attribution",
      );
    });

    test('réalisé, avec l\'heure', () {
      expect(
        _statut({'etat': 'realise', 'employe_prenom': 'Essie', 'heure': '10:42'})
            .libelle,
        "Effectué aujourd'hui à 10:42 — Essie",
      );
    });

    test('non effectué : aucun nom, aucune période, aucun motif', () {
      expect(
        _statut({'etat': 'non_realise'}).libelle,
        "Non effectué aujourd'hui",
      );
    });

    test('un état inconnu est refusé plutôt qu\'affiché de travers', () {
      expect(() => _statut({'etat': 'nimportequoi'}), throwsFormatException);
    });
  });

  group('Motif d\'un non-réalisé', () {
    test('un motif éventuellement présent dans le JSON n\'atteint pas l\'écran',
        () {
      final s = _statut({
        'etat': 'non_realise',
        'periode': 'AM',
        'employe_prenom': 'Essie',
        'motif': 'MOTIF-SECRET Refus',
        'motif_absent': 'MOTIF-SECRET Absent',
        'commentaire': 'MOTIF-SECRET Autre',
      });
      expect(s.libelle, isNot(contains('MOTIF-SECRET')));
      expect(s.libelle, isNot(contains('Essie')));
      expect(s.toString(), isNot(contains('MOTIF-SECRET')));
    });
  });

  group('Analyse du JSON', () {
    test('fiche complète', () {
      final f = FicheAppartement.fromJson({
        'appartement': {'id': 'a1', 'numero': '101', 'etage': 1, 'taille': '4 1/2'},
        'residents': [
          {'prenom': 'Jeanne', 'nom': 'Tremblay'},
          {'prenom': 'Paul', 'nom': 'Tremblay'},
        ],
        'statut_du_jour': {'etat': 'prevu', 'periode': 'AM', 'employe_prenom': 'Essie'},
        'prochaines_dates': [
          {'date': '2026-09-22', 'jour': 'Mardi', 'periode': 'AM', 'employe_prenom': 'Essie'},
          {'date': '2026-09-29', 'jour': 'Mardi', 'periode': 'AM'},
        ],
        'employe_concerne': {'id': 'e1', 'prenom': 'Essie'},
      });

      expect(f.id, 'a1');
      expect(f.numero, '101');
      expect(f.etage, 1);
      expect(f.taille, '4 1/2');
      expect(f.residents, ['Jeanne Tremblay', 'Paul Tremblay']);
      expect(f.statut.etat, EtatStatut.prevu);
      expect(f.prochainesDates, hasLength(2));
      expect(f.prochainesDates.first.dateCourte, '22/09/2026');
      expect(f.prochainesDates.last.employePrenom, isNull);
      expect(f.employeConcerne?.prenom, 'Essie');
    });

    test('fiche minimale : pas de résident, pas de date, pas d\'employé', () {
      final f = FicheAppartement.fromJson({
        'appartement': {'id': 'a2', 'numero': '102'},
        'statut_du_jour': {'etat': 'aucun'},
        'employe_concerne': null,
      });

      expect(f.residents, isEmpty);
      expect(f.prochainesDates, isEmpty);
      expect(f.employeConcerne, isNull);
      expect(f.etage, isNull);
    });

    test('ligne du tableau des résidents', () {
      final r = ResidentLigne.fromJson({
        'resident_id': 'r1',
        'prenom': 'Jeanne',
        'nom': 'Tremblay',
        'appartement_id': 'a1',
        'numero': '101',
        'etage': 1,
      });
      expect(r.residentId, 'r1');
      expect(r.appartementId, 'a1');
      expect(r.numero, '101');
      expect(r.etage, 1);
      expect(r.nomComplet, 'Jeanne Tremblay');
      expect(r.initiales, 'JT');
    });

    test('ligne sans étage', () {
      final r = ResidentLigne.fromJson({
        'resident_id': 'r1',
        'prenom': 'dan',
        'nom': 'bagalwa',
        'appartement_id': 'a1',
        'numero': '101',
        'etage': null,
      });
      expect(r.etage, isNull);
      expect(r.initiales, 'DB');
    });
  });
}
