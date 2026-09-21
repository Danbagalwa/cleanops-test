import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';
import 'package:cleanops/features/reception/domain/reception_pin_models.dart';
import 'package:cleanops/features/reception/domain/reception_pin_repository.dart';
import 'package:cleanops/features/reception/domain/reception_residents_repository.dart'
    show ReceptionErreur;
import 'package:cleanops/features/reception/presentation/providers/reception_pin_provider.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_pin_screen.dart';

const _reception = Employee(
  id: 'r1',
  nom: 'Dab',
  prenom: 'Receptioniste',
  slug: 'receptioniste',
  role: RoleType.reception,
  isActif: true,
);

class _Generation {
  final String residentId;
  final String auteurId;

  _Generation(this.residentId, this.auteurId);
}

class _DepotSimule implements ReceptionPinRepository {
  final List<ResidentPin> lignes;
  Object? erreurListe;
  Object? erreurGeneration;
  int chargements = 0;
  final generations = <_Generation>[];

  _DepotSimule(this.lignes);

  @override
  Future<List<ResidentPin>> residents() async {
    chargements++;
    if (erreurListe != null) throw erreurListe!;
    return lignes;
  }

  @override
  Future<PinGenere> genererPin({
    required String residentId,
    required String auteurId,
  }) async {
    if (erreurGeneration != null) throw erreurGeneration!;
    generations.add(_Generation(residentId, auteurId));
    final avait = lignes.firstWhere((l) => l.residentId == residentId).aPin;
    return PinGenere(pin: '4821', reinitialise: avait);
  }
}

ResidentPin _res(
  String id,
  String prenom,
  String nom,
  String numero, {
  bool app = true,
  bool pin = false,
}) =>
    ResidentPin(
      residentId: id,
      prenom: prenom,
      nom: nom,
      appartementId: 'a$numero',
      numero: numero,
      aApplication: app,
      aPin: pin,
    );

List<ResidentPin> _jeu() => [
      _res('r1', 'Jeanne', 'Tremblay', '101', app: true, pin: false),
      _res('r2', 'Paul', 'Gagnon', '202', app: true, pin: true),
      _res('r3', 'Marie', 'Roy', '303', app: false, pin: false),
    ];

Future<void> _afficher(
  WidgetTester tester,
  _DepotSimule depot, {
  Size taille = const Size(1200, 1400),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = taille;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        employeeCourantProvider.overrideWithValue(_reception),
        receptionPinRepositoryProvider.overrideWithValue(depot),
      ],
      child: const MaterialApp(home: ReceptionPinScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Modèles', () {
    test('analyse du JSON du serveur', () {
      final r = ResidentPin.fromJson({
        'resident_id': 'r1',
        'prenom': 'Jeanne',
        'nom': 'Tremblay',
        'appartement_id': 'a1',
        'numero': '101',
        'a_application': true,
        'a_pin': true,
      });
      expect(r.nomComplet, 'Jeanne Tremblay');
      expect(r.initiales, 'JT');
      expect(r.aApplication, isTrue);
      expect(r.aPin, isTrue);
    });

    test('sans indicateurs : ni application ni PIN', () {
      final r = ResidentPin.fromJson({
        'resident_id': 'r1',
        'prenom': 'A',
        'nom': 'B',
        'appartement_id': 'a1',
        'numero': '1',
      });
      expect(r.aApplication, isFalse);
      expect(r.aPin, isFalse);
    });

    test('un hachage éventuel dans le JSON n\'atteint jamais le modèle', () {
      final r = ResidentPin.fromJson({
        'resident_id': 'r1',
        'prenom': 'A',
        'nom': 'B',
        'appartement_id': 'a1',
        'numero': '1',
        'pin_hash': r'$2a$12$SECRETHASH',
      });
      expect(r.toString(), isNot(contains('SECRETHASH')));
    });

    test('le PIN généré ne se retrouve pas dans un journal', () {
      final p = PinGenere.fromJson({'pin': '4821', 'reinitialise': true});
      expect(p.pin, '4821');
      expect(p.reinitialise, isTrue);
      expect(p.toString(), isNot(contains('4821')));
    });
  });

  group('Tableau des PIN', () {
    testWidgets('s\'ouvre directement sur le tableau', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      for (final t in ['NOM', 'APPARTEMENT', 'STATUT', 'PIN', 'ACTIONS']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('PIN  (3)'), findsOneWidget);
      expect(find.text('Jeanne Tremblay'), findsOneWidget);
      expect(find.text('Paul Gagnon'), findsOneWidget);
      expect(find.text('Marie Roy'), findsOneWidget);
    });

    testWidgets('statut d\'inscription et état du PIN', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      expect(find.text('Inscrit'), findsNWidgets(2));
      expect(find.text('Sans app'), findsOneWidget);
      expect(find.text('Défini'), findsOneWidget);
      expect(find.text('Non défini'), findsNWidgets(2));
    });

    testWidgets('l\'action dépend de l\'existence d\'un PIN', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      expect(find.byTooltip('Générer le PIN'), findsNWidgets(2));
      expect(find.byTooltip('Réinitialiser le PIN'), findsOneWidget);
    });

    testWidgets('filtre « Sans PIN »', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.tap(find.text('Sans PIN'));
      await tester.pump();

      expect(find.text('Jeanne Tremblay'), findsOneWidget);
      expect(find.text('Marie Roy'), findsOneWidget);
      expect(find.text('Paul Gagnon'), findsNothing);
    });

    testWidgets('filtre « PIN défini »', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.tap(find.text('PIN défini'));
      await tester.pump();

      expect(find.text('Paul Gagnon'), findsOneWidget);
      expect(find.text('Jeanne Tremblay'), findsNothing);
    });

    testWidgets('recherche par nom et par appartement', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.enterText(find.byType(TextField), 'gagn');
      await tester.pump();
      expect(find.text('Paul Gagnon'), findsOneWidget);
      expect(find.text('Jeanne Tremblay'), findsNothing);

      await tester.enterText(find.byType(TextField), '303');
      await tester.pump();
      expect(find.text('Marie Roy'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Aucun résultat'), findsOneWidget);

      await tester.tap(find.text('Effacer les filtres'));
      await tester.pump();
      expect(find.text('Jeanne Tremblay'), findsOneWidget);
    });

    testWidgets('aucun résident actif', (tester) async {
      await _afficher(tester, _DepotSimule(const []));
      expect(find.text('Aucun résident'), findsOneWidget);
    });

    testWidgets('une erreur de chargement propose de réessayer',
        (tester) async {
      final depot = _DepotSimule(_jeu())
        ..erreurListe = const ReceptionErreur('Réseau indisponible.');
      await _afficher(tester, depot);

      expect(find.text('Réessayer'), findsOneWidget);

      depot.erreurListe = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Jeanne Tremblay'), findsOneWidget);
    });

    testWidgets('pagination : 10 résidents par page', (tester) async {
      final liste = [
        for (var i = 1; i <= 12; i++) _res('r$i', 'Prénom$i', 'Nom', '${100 + i}'),
      ];
      await _afficher(tester, _DepotSimule(liste));

      expect(find.text('Prénom10 Nom'), findsOneWidget);
      expect(find.text('Prénom11 Nom'), findsNothing);
      expect(find.text('1–10 sur 12'), findsOneWidget);
    });

    testWidgets('sur mobile : cartes avec la même action', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()),
          taille: const Size(420, 900));

      expect(find.text('NOM'), findsNothing);
      expect(find.text('PIN défini'), findsWidgets);
      expect(find.text('PIN non défini'), findsNWidgets(2));
      expect(find.byTooltip('Générer le PIN'), findsNWidgets(2));
      expect(find.byTooltip('Réinitialiser le PIN'), findsOneWidget);
    });
  });

  group('Générer ou réinitialiser un PIN', () {
    testWidgets('générer : confirmation, puis PIN affiché une seule fois',
        (tester) async {
      final depot = _DepotSimule(_jeu());
      await _afficher(tester, depot);

      await tester.tap(find.byTooltip('Générer le PIN').first);
      await tester.pumpAndSettle();

      expect(find.text('Générer le PIN'), findsOneWidget);
      expect(find.text('Jeanne Tremblay · Apt 101'), findsOneWidget);
      expect(find.text('Un PIN de 4 chiffres sera généré pour ce résident.'),
          findsOneWidget);
      expect(depot.generations, isEmpty, reason: 'rien avant la confirmation');

      await tester.tap(find.text('Générer'));
      await tester.pumpAndSettle();

      expect(depot.generations, hasLength(1));
      expect(depot.generations.single.residentId, 'r1');
      expect(depot.generations.single.auteurId, 'r1');
      expect(find.text('PIN généré'), findsOneWidget);
      expect(find.text('4821'), findsOneWidget);
      expect(find.text('Communiquez ce PIN au résident maintenant.'),
          findsOneWidget);

      await tester.tap(find.text('Terminé'));
      await tester.pumpAndSettle();

      expect(find.text('4821'), findsNothing, reason: 'jamais réaffiché');
      expect(depot.chargements, 2, reason: 'la liste est rechargée');
    });

    testWidgets('réinitialiser : avertit que l\'ancien PIN cesse de marcher',
        (tester) async {
      final depot = _DepotSimule(_jeu());
      await _afficher(tester, depot);

      await tester.tap(find.byTooltip('Réinitialiser le PIN'));
      await tester.pumpAndSettle();

      expect(find.text('Réinitialiser le PIN'), findsOneWidget);
      expect(
        find.textContaining("L'ancien PIN ne fonctionnera plus."),
        findsOneWidget,
      );

      await tester.tap(find.text('Réinitialiser'));
      await tester.pumpAndSettle();

      expect(depot.generations.single.residentId, 'r2');
      expect(find.text('PIN réinitialisé'), findsOneWidget);
      expect(find.textContaining("L'ancien PIN ne fonctionne plus."),
          findsOneWidget);
    });

    testWidgets('annuler : aucun PIN n\'est généré', (tester) async {
      final depot = _DepotSimule(_jeu());
      await _afficher(tester, depot);

      await tester.tap(find.byTooltip('Générer le PIN').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(depot.generations, isEmpty);
      expect(find.text('PIN généré'), findsNothing);
      expect(depot.chargements, 1);
    });

    testWidgets('une erreur du serveur s\'affiche, aucun PIN n\'apparaît',
        (tester) async {
      final depot = _DepotSimule(_jeu())
        ..erreurGeneration = const ReceptionErreur('Auteur invalide ou inactif.');
      await _afficher(tester, depot);

      await tester.tap(find.byTooltip('Générer le PIN').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Générer'));
      await tester.pumpAndSettle();

      expect(find.text('Auteur invalide ou inactif.'), findsOneWidget);
      expect(find.text('PIN généré'), findsNothing);
      expect(find.text('4821'), findsNothing);
    });

    testWidgets('« Copier » place le PIN dans le presse-papiers',
        (tester) async {
      String? copie;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copie = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await _afficher(tester, _DepotSimule(_jeu()));
      await tester.tap(find.byTooltip('Générer le PIN').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Générer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copier'));
      await tester.pumpAndSettle();

      expect(copie, '4821');
      expect(find.text('PIN copié.'), findsOneWidget);
    });

    testWidgets('la fenêtre du PIN ne se ferme pas par un clic à côté',
        (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));
      await tester.tap(find.byTooltip('Générer le PIN').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Générer'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('4821'), findsOneWidget);
    });

    testWidgets('le PIN n\'apparaît nulle part dans le tableau', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));
      await tester.tap(find.byTooltip('Générer le PIN').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Générer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminé'));
      await tester.pumpAndSettle();

      expect(find.textContaining('4821'), findsNothing);
    });
  });
}
