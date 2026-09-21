import 'package:flutter_test/flutter_test.dart';
import 'package:cleanops/features/resident_espace/domain/menages_depuis_arrivee.dart';

Map<String, dynamic> _menage(String date, {String statut = 'Fait'}) =>
    {'id': 'm-$date', 'semaine_reelle': date, 'statut': statut};

void main() {
  group('Un nouveau résident ne voit jamais les ménages d\'avant son arrivée',
      () {
    final ancienOccupant = [_menage('2026-08-14')];

    test('un ménage de l\'ancien occupant est masqué', () {
      expect(menagesDepuisArrivee(ancienOccupant, '2026-09-21'), isEmpty);
    });

    test('un ménage fait depuis l\'arrivée reste visible', () {
      final apres = [_menage('2026-09-25')];
      expect(menagesDepuisArrivee(apres, '2026-09-21'), apres);
    });

    test('le jour d\'arrivée lui-même est inclus', () {
      final memeJour = [_menage('2026-09-21')];
      expect(menagesDepuisArrivee(memeJour, '2026-09-21'), memeJour);
    });

    test('la veille de l\'arrivée est masquée', () {
      expect(
        menagesDepuisArrivee([_menage('2026-09-20')], '2026-09-21'),
        isEmpty,
      );
    });

    test('on ne garde que ce qui suit l\'arrivée', () {
      final mixte = [
        _menage('2026-08-14'),
        _menage('2026-09-20'),
        _menage('2026-09-21'),
        _menage('2026-10-05'),
      ];
      final garde = menagesDepuisArrivee(mixte, '2026-09-21');
      expect(garde.map((m) => m['semaine_reelle']),
          ['2026-09-21', '2026-10-05']);
    });

    test('un résident existant (sans date d\'arrivée) ne perd rien', () {
      expect(menagesDepuisArrivee(ancienOccupant, null), ancienOccupant);
      expect(menagesDepuisArrivee(ancienOccupant, ''), ancienOccupant);
    });

    test('une date d\'arrivée accompagnée d\'une heure est comprise', () {
      expect(
        menagesDepuisArrivee(
            [_menage('2026-09-21'), _menage('2026-09-20')],
            '2026-09-21T00:00:00')
            .length,
        1,
      );
    });

    test('un ménage sans date est écarté quand il y a une restriction', () {
      final sansDate = [
        {'id': 'x', 'statut': 'Fait'},
      ];
      expect(menagesDepuisArrivee(sansDate, '2026-09-21'), isEmpty);
    });

    test('aucun ménage : liste vide', () {
      expect(menagesDepuisArrivee(const [], '2026-09-21'), isEmpty);
    });
  });
}
