import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';
import 'package:cleanops/features/reception/domain/reception_models.dart';
import 'package:cleanops/features/reception/domain/reception_pin_models.dart';
import 'package:cleanops/features/reception/domain/reception_pin_repository.dart';
import 'package:cleanops/features/reception/domain/reception_residents_repository.dart';
import 'package:cleanops/features/reception/presentation/providers/reception_pin_provider.dart';
import 'package:cleanops/features/reception/presentation/providers/reception_residents_provider.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_residents_screen.dart';

const _reception = Employee(
  id: 'r1',
  nom: 'Dab',
  prenom: 'Receptioniste',
  slug: 'receptioniste',
  role: RoleType.reception,
  isActif: true,
);

class _Inscription {
  final String appartementId;
  final String auteurId;
  final String prenom;
  final String nom;
  final String demandeParId;
  final bool aApplication;

  _Inscription(this.appartementId, this.auteurId, this.prenom, this.nom,
      this.demandeParId, this.aApplication);
}

class _DepotResidents implements ReceptionResidentsRepository {
  List<AppartementLibre> libres;
  List<ResponsableDemandeur> responsablesListe;
  final List<ResidentLigne> lignes = [];
  Object? erreurInscription;
  Object? erreurLibres;
  int chargementsLibres = 0;
  int chargementsResidents = 0;
  final inscriptions = <_Inscription>[];

  _DepotResidents({required this.libres, required this.responsablesListe});

  @override
  Future<List<ResidentLigne>> residents() async {
    chargementsResidents++;
    return List.of(lignes);
  }

  @override
  Future<List<AppartementLibre>> appartementsLibres() async {
    chargementsLibres++;
    if (erreurLibres != null) throw erreurLibres!;
    return libres;
  }

  @override
  Future<List<ResponsableDemandeur>> responsables() async => responsablesListe;

  @override
  Future<ResidentInscrit> inscrireResident({
    required String appartementId,
    required String auteurId,
    required String prenom,
    required String nom,
    required String demandeParId,
    required bool aApplication,
  }) async {
    if (erreurInscription != null) throw erreurInscription!;
    inscriptions.add(_Inscription(
        appartementId, auteurId, prenom, nom, demandeParId, aApplication));
    final apt = libres.firstWhere((a) => a.id == appartementId);
    libres = libres.where((a) => a.id != appartementId).toList();
    lignes.add(ResidentLigne(
      residentId: 'nouveau',
      prenom: prenom,
      nom: nom,
      appartementId: appartementId,
      numero: apt.numero,
    ));
    return ResidentInscrit(
      residentId: 'nouveau',
      numero: apt.numero,
      dateArrivee: DateTime(2026, 9, 21),
    );
  }

  @override
  Future<FicheAppartement?> fiche(String appartementId) async => null;

  @override
  Future<void> envoyerMessage({
    required String appartementId,
    required String auteurId,
    required NatureDemande nature,
    required String message,
    required bool transmettreEmploye,
  }) async {}
}

class _DepotPin implements ReceptionPinRepository {
  Object? erreur;
  final generes = <String>[];

  @override
  Future<List<ResidentPin>> residents() async => const [];

  @override
  Future<PinGenere> genererPin({
    required String residentId,
    required String auteurId,
  }) async {
    if (erreur != null) throw erreur!;
    generes.add(residentId);
    return const PinGenere(pin: '4821', reinitialise: false);
  }
}

const _apt105 = AppartementLibre(id: 'a105', numero: '105', etage: 1);
const _apt210 = AppartementLibre(id: 'a210', numero: '210', etage: 2);
const _nadine = ResponsableDemandeur(id: 'u1', prenom: 'Nadine', nom: 'Sylvestre');
const _marc = ResponsableDemandeur(id: 'u2', prenom: 'Marc', nom: 'Roy');

_DepotResidents _depot() => _DepotResidents(
      libres: [_apt105, _apt210],
      responsablesListe: [_nadine, _marc],
    );

Future<void> _afficher(
  WidgetTester tester,
  _DepotResidents depot,
  _DepotPin pin, {
  Size taille = const Size(1200, 1400),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = taille;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        employeeCourantProvider.overrideWithValue(_reception),
        receptionResidentsRepositoryProvider.overrideWithValue(depot),
        receptionPinRepositoryProvider.overrideWithValue(pin),
      ],
      child: const MaterialApp(home: ReceptionResidentsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ouvrir(WidgetTester tester) async {
  await tester.tap(find.text('Inscrire un résident'));
  await tester.pumpAndSettle();
}

Future<void> _choisir<T>(WidgetTester tester, String libelle) async {
  await tester.tap(find.byType(DropdownButtonFormField<T>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(libelle).last);
  await tester.pumpAndSettle();
}

Finder _champ(String label) =>
    find.widgetWithText(TextField, label);

Future<void> _remplir(
  WidgetTester tester, {
  bool apt = true,
  bool demandeur = true,
  String prenom = 'Jeanne',
  String nom = 'Tremblay',
}) async {
  if (apt) await _choisir<AppartementLibre>(tester, 'Apt 105 · Étage 1');
  if (prenom.isNotEmpty) await tester.enterText(_champ('Prénom'), prenom);
  if (nom.isNotEmpty) await tester.enterText(_champ('Nom'), nom);
  if (demandeur) {
    await _choisir<ResponsableDemandeur>(tester, 'Nadine Sylvestre');
  }
  await tester.pump();
}

FilledButton _inscrire(WidgetTester tester) => tester
    .widget<FilledButton>(find.widgetWithText(FilledButton, 'Inscrire'));

void main() {
  group('Modèles', () {
    test('appartement libre', () {
      final a = AppartementLibre.fromJson(
          {'appartement_id': 'a1', 'numero': '105', 'etage': 1});
      expect(a.libelle, 'Apt 105 · Étage 1');
      expect(
        AppartementLibre.fromJson(
                {'appartement_id': 'a2', 'numero': '3010', 'etage': null})
            .libelle,
        'Apt 3010',
      );
    });

    test('la sélection survit au rechargement (égalité par identifiant)', () {
      const a = AppartementLibre(id: 'a1', numero: '105');
      const b = AppartementLibre(id: 'a1', numero: '105');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(const ResponsableDemandeur(id: 'u', prenom: 'A', nom: 'B'),
          const ResponsableDemandeur(id: 'u', prenom: 'X', nom: 'Y'));
      expect(a == const AppartementLibre(id: 'a2', numero: '105'), isFalse);
    });

    test('responsable et résultat d\'inscription', () {
      final r = ResponsableDemandeur.fromJson(
          {'id': 'u1', 'prenom': 'Nadine', 'nom': 'Sylvestre'});
      expect(r.nomComplet, 'Nadine Sylvestre');

      final i = ResidentInscrit.fromJson({
        'resident_id': 'r9',
        'numero': '105',
        'date_arrivee': '2026-09-21',
      });
      expect(i.residentId, 'r9');
      expect(i.dateArriveeCourte, '21/09/2026');
    });
  });

  group('Inscrire un résident', () {
    testWidgets('bouton sur grand écran, bouton flottant sur mobile',
        (tester) async {
      await _afficher(tester, _depot(), _DepotPin());
      expect(find.text('Inscrire un résident'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await _afficher(tester, _depot(), _DepotPin(),
          taille: const Size(420, 900));
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byTooltip('Inscrire un résident'), findsOneWidget);
    });

    testWidgets('le formulaire demande le nom et le responsable demandeur',
        (tester) async {
      await _afficher(tester, _depot(), _DepotPin());
      await _ouvrir(tester);

      expect(find.text('Inscrire un résident'), findsWidgets);
      expect(find.text('Appartement'), findsWidgets);
      expect(find.text('Prénom'), findsWidgets);
      expect(find.text('Nom'), findsWidgets);
      expect(find.text('À la demande de (responsable)'), findsWidgets);
      expect(
        find.textContaining("À faire à la demande du responsable"),
        findsOneWidget,
      );
    });

    testWidgets('« Inscrire » reste désactivé tant que tout n\'est pas rempli',
        (tester) async {
      await _afficher(tester, _depot(), _DepotPin());
      await _ouvrir(tester);
      expect(_inscrire(tester).onPressed, isNull);

      // Tout sauf l'appartement.
      await _remplir(tester, apt: false);
      expect(_inscrire(tester).onPressed, isNull, reason: 'appartement');
    });

    testWidgets('le responsable demandeur est OBLIGATOIRE', (tester) async {
      await _afficher(tester, _depot(), _DepotPin());
      await _ouvrir(tester);

      await _remplir(tester, demandeur: false);
      expect(_inscrire(tester).onPressed, isNull,
          reason: 'sans « à la demande de », pas d\'inscription');
    });

    testWidgets('le prénom et le nom sont obligatoires', (tester) async {
      await _afficher(tester, _depot(), _DepotPin());
      await _ouvrir(tester);
      await _remplir(tester, prenom: '   ');
      expect(_inscrire(tester).onPressed, isNull, reason: 'prénom vide');

      await tester.enterText(_champ('Prénom'), 'Jeanne');
      await tester.enterText(_champ('Nom'), '  ');
      await tester.pump();
      expect(_inscrire(tester).onPressed, isNull, reason: 'nom vide');

      await tester.enterText(_champ('Nom'), 'Tremblay');
      await tester.pump();
      expect(_inscrire(tester).onPressed, isNotNull);
    });

    testWidgets('inscription : les données partent au serveur', (tester) async {
      final depot = _depot();
      await _afficher(tester, depot, _DepotPin());
      await _ouvrir(tester);
      await _remplir(tester, prenom: '  Jeanne ', nom: ' Tremblay  ');

      await tester.tap(find.widgetWithText(FilledButton, 'Inscrire'));
      await tester.pumpAndSettle();

      expect(depot.inscriptions, hasLength(1));
      final i = depot.inscriptions.single;
      expect(i.appartementId, 'a105');
      expect(i.auteurId, 'r1');
      expect(i.prenom, 'Jeanne');
      expect(i.nom, 'Tremblay');
      expect(i.demandeParId, 'u1');
      expect(i.aApplication, isTrue);
    });

    testWidgets('résultat : date d\'arrivée et rappel que rien n\'est planifié',
        (tester) async {
      await _afficher(tester, _depot(), _DepotPin());
      await _ouvrir(tester);
      await _remplir(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Inscrire'));
      await tester.pumpAndSettle();

      expect(find.text('Résident inscrit'), findsOneWidget);
      expect(find.text('Jeanne Tremblay · Apt 105'), findsOneWidget);
      expect(find.text("Date d'arrivée : 21/09/2026"), findsOneWidget);
      expect(
        find.textContaining("Aucun ménage n'est encore planifié"),
        findsOneWidget,
      );
    });

    testWidgets('la liste des résidents se met à jour', (tester) async {
      final depot = _depot();
      await _afficher(tester, depot, _DepotPin());
      expect(find.text('Jeanne Tremblay'), findsNothing);
      final avant = depot.chargementsResidents;

      await _ouvrir(tester);
      await _remplir(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Inscrire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminé'));
      await tester.pumpAndSettle();

      expect(depot.chargementsResidents, greaterThan(avant));
      expect(find.text('Jeanne Tremblay'), findsOneWidget);
    });

    testWidgets('générer le PIN : affiché une seule fois', (tester) async {
      final pin = _DepotPin();
      await _afficher(tester, _depot(), pin);
      await _ouvrir(tester);
      await _remplir(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Inscrire'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Générer le PIN'));
      await tester.pumpAndSettle();

      expect(pin.generes, ['nouveau']);
      expect(find.text('PIN généré'), findsWidgets);
      expect(find.text('4821'), findsOneWidget);
      expect(find.text('Jeanne Tremblay · Apt 105'), findsWidgets);

      // Fermer la fenêtre du PIN : il disparaît, et ne peut pas être régénéré
      // par erreur depuis ce résultat.
      await tester.tap(find.text('Terminé').last);
      await tester.pumpAndSettle();
      expect(find.text('4821'), findsNothing);

      final bouton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'PIN généré'));
      expect(bouton.onPressed, isNull);
    });

    testWidgets('sans application : pas de PIN proposé', (tester) async {
      final pin = _DepotPin();
      final depot = _depot();
      await _afficher(tester, depot, pin);
      await _ouvrir(tester);
      await _remplir(tester);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Inscrire'));
      await tester.pumpAndSettle();

      expect(depot.inscriptions.single.aApplication, isFalse);
      expect(find.text('Résident inscrit'), findsOneWidget);
      expect(find.text('Générer le PIN'), findsNothing);
    });

    testWidgets('une erreur de PIN s\'affiche', (tester) async {
      final pin = _DepotPin()
        ..erreur = const ReceptionErreur("Le PIN n'a pas pu être généré.");
      await _afficher(tester, _depot(), pin);
      await _ouvrir(tester);
      await _remplir(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Inscrire'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Générer le PIN'));
      await tester.pumpAndSettle();

      expect(find.text("Le PIN n'a pas pu être généré."), findsOneWidget);
      expect(find.text('4821'), findsNothing);
    });

    testWidgets('une erreur du serveur s\'affiche et le formulaire reste',
        (tester) async {
      final depot = _depot()
        ..erreurInscription =
            const ReceptionErreur('Cet appartement a déjà un occupant.');
      await _afficher(tester, depot, _DepotPin());
      await _ouvrir(tester);
      await _remplir(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Inscrire'));
      await tester.pumpAndSettle();

      expect(find.text('Cet appartement a déjà un occupant.'), findsOneWidget);
      expect(find.text('Résident inscrit'), findsNothing);
      expect(_inscrire(tester).onPressed, isNotNull, reason: 'on peut réessayer');
    });

    testWidgets('aucun appartement libre', (tester) async {
      final depot = _DepotResidents(libres: const [], responsablesListe: [_nadine]);
      await _afficher(tester, depot, _DepotPin());
      await _ouvrir(tester);

      expect(find.textContaining('Aucun appartement sans occupant'),
          findsOneWidget);
    });

    testWidgets('une erreur de chargement des appartements propose de réessayer',
        (tester) async {
      final depot = _depot()
        ..erreurLibres = const ReceptionErreur('Réseau indisponible.');
      await _afficher(tester, depot, _DepotPin());
      await _ouvrir(tester);

      expect(find.text('Réseau indisponible.'), findsOneWidget);

      depot.erreurLibres = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<AppartementLibre>),
          findsOneWidget);
    });

    testWidgets('la Réception n\'assigne aucun ménage', (tester) async {
      await _afficher(tester, _depot(), _DepotPin());
      await _ouvrir(tester);

      expect(
        find.textContaining("La Réception n'assigne aucun ménage"),
        findsOneWidget,
      );
      for (final mot in [
        'Fréquence',
        'Préposée',
        'Employé assigné',
        'Jour',
        'Période',
      ]) {
        expect(find.text(mot), findsNothing, reason: mot);
        expect(find.widgetWithText(TextField, mot), findsNothing, reason: mot);
      }
    });

    testWidgets('la fenêtre ne se ferme pas par un clic à côté',
        (tester) async {
      await _afficher(tester, _depot(), _DepotPin());
      await _ouvrir(tester);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('Inscrire un résident'), findsWidgets);
      expect(find.byType(Dialog), findsOneWidget);
    });
  });
}
