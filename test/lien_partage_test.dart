import 'package:cleanops/core/router/app_router.dart';
import 'package:cleanops/features/demandes_equipe/data/transfert_document_demande.dart';
import 'package:flutter_test/flutter_test.dart';

const _attendu = 'https://danbagalwa.github.io/cleanops-test/#/partage/abc';

void main() {
  group('Lien de la page de partage (GitHub Pages)', () {
    test('adresse du dépôt, avec ou sans « / » final', () {
      for (final base in [
        'https://danbagalwa.github.io/cleanops-test/',
        'https://danbagalwa.github.io/cleanops-test',
      ]) {
        expect(adresseDansApp(Uri.parse(base), '/partage/abc'), _attendu,
            reason: base);
      }
    });

    test('depuis une page de l\'app : la route en cours est remplacée', () {
      expect(
        adresseDansApp(
          Uri.parse(
              'https://danbagalwa.github.io/cleanops-test/#/demandes/equipe'),
          '/partage/abc',
        ),
        _attendu,
      );
    });

    test('index.html et requête ne sont pas gardés', () {
      expect(
        adresseDansApp(
          Uri.parse(
              'https://danbagalwa.github.io/cleanops-test/index.html?v=2#/'),
          '/partage/abc',
        ),
        _attendu,
      );
    });

    test('app servie à la racine (développement local)', () {
      expect(
        adresseDansApp(Uri.parse('http://localhost:5000/#/'), '/partage/abc'),
        'http://localhost:5000/#/partage/abc',
      );
    });

    test('pas d\'adresse web : pas de lien', () {
      expect(adresseDansApp(null, '/partage/abc'), isNull);
      expect(adresseDansApp(Uri.parse('file:///app/'), '/partage/abc'), isNull);
      expect(adresseDansApp(Uri.parse(''), '/partage/abc'), isNull);
    });
  });

  group('Route contenue dans un lien reçu', () {
    test('lien GitHub Pages ouvert par l\'app mobile', () {
      expect(routeDepuisLien(_attendu), '/partage/abc');
    });

    test('accueil de l\'app web : pas pris pour un identifiant', () {
      expect(
          routeDepuisLien('https://danbagalwa.github.io/cleanops-test/'), '/');
      expect(
          routeDepuisLien('https://danbagalwa.github.io/cleanops-test'), '/');
      expect(sansDossierWeb('/naomie'), '/naomie');
      expect(sansDossierWeb('/cleanops-testeur'), '/cleanops-testeur');
    });

    test('lien d\'application', () {
      expect(routeDepuisLien('cleanops://app/partage/abc'), '/partage/abc');
    });
  });
}
