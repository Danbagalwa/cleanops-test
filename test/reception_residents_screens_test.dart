import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';
import 'package:cleanops/features/reception/domain/reception_models.dart';
import 'package:cleanops/features/reception/domain/reception_residents_repository.dart';
import 'package:cleanops/features/reception/presentation/providers/reception_residents_provider.dart';
import 'package:cleanops/features/reception/presentation/reception_sections.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_fiche_screen.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_residents_screen.dart';

const _reception = Employee(
  id: 'r1',
  nom: 'Dab',
  prenom: 'Receptioniste',
  slug: 'receptioniste',
  role: RoleType.reception,
  isActif: true,
);

class _EnvoiRecu {
  final String appartementId;
  final String auteurId;
  final String message;
  final bool transmettre;

  _EnvoiRecu(this.appartementId, this.auteurId, this.message, this.transmettre);
}

class _DepotSimule implements ReceptionResidentsRepository {
  final List<AppartementResultat> resultats;
  FicheAppartement? ficheRenvoyee;
  Object? erreurEnvoi;
  final recherches = <String>[];
  final envois = <_EnvoiRecu>[];

  _DepotSimule({this.resultats = const [], this.ficheRenvoyee});

  @override
  Future<List<AppartementResultat>> rechercher(String recherche) async {
    recherches.add(recherche);
    return resultats;
  }

  @override
  Future<FicheAppartement?> fiche(String appartementId) async => ficheRenvoyee;

  @override
  Future<void> envoyerMessage({
    required String appartementId,
    required String auteurId,
    required String message,
    required bool transmettreEmploye,
  }) async {
    if (erreurEnvoi != null) throw erreurEnvoi!;
    envois.add(_EnvoiRecu(appartementId, auteurId, message, transmettreEmploye));
  }
}

FicheAppartement _fiche({
  StatutDuJour statut = const StatutDuJour(
    etat: EtatStatut.prevu,
    periode: 'AM',
    employePrenom: 'Essie',
  ),
  List<ProchaineDate>? dates,
  EmployeConcerne? concerne = const EmployeConcerne(id: 'e1', prenom: 'Essie'),
}) =>
    FicheAppartement(
      id: 'a1',
      numero: '101',
      etage: 1,
      taille: '4 1/2',
      residents: const ['Jeanne Tremblay'],
      statut: statut,
      prochainesDates: dates ??
          [
            ProchaineDate(
              date: DateTime(2026, 9, 22),
              jour: 'Mardi',
              periode: 'AM',
              employePrenom: 'Essie',
            ),
            ProchaineDate(
              date: DateTime(2026, 9, 29),
              jour: 'Mardi',
              periode: 'AM',
            ),
          ],
      employeConcerne: concerne,
    );

Future<void> _afficher(
  WidgetTester tester,
  _DepotSimule depot, {
  String initiale = receptionResidentsRoute,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1000, 1400);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: initiale,
    routes: [
      GoRoute(
        path: receptionResidentsRoute,
        builder: (_, __) => const ReceptionResidentsScreen(),
      ),
      GoRoute(
        path: receptionFichePattern,
        builder: (_, state) => ReceptionFicheScreen(
          appartementId: state.pathParameters['appartementId']!,
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        employeeCourantProvider.overrideWithValue(_reception),
        receptionResidentsRepositoryProvider.overrideWithValue(depot),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _taper(WidgetTester tester, Finder champ, String texte) async {
  await tester.enterText(champ, texte);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('Recherche', () {
    testWidgets('invite à chercher, sans interroger le serveur', (tester) async {
      final depot = _DepotSimule();
      await _afficher(tester, depot);

      expect(find.text('Recherchez un appartement pour consulter sa fiche.'),
          findsOneWidget);
      expect(depot.recherches, isEmpty);
    });

    testWidgets('affiche les résultats et ouvre la fiche au toucher',
        (tester) async {
      final depot = _DepotSimule(
        resultats: const [
          AppartementResultat(
              id: 'a1', numero: '101', etage: 1, residents: ['Jeanne Tremblay']),
        ],
        ficheRenvoyee: _fiche(),
      );
      await _afficher(tester, depot);

      await _taper(tester, find.byType(TextField), '101');

      expect(depot.recherches, ['101']);
      expect(find.text('Appartement 101 · Étage 1'), findsOneWidget);
      expect(find.text('Jeanne Tremblay'), findsOneWidget);

      await tester.tap(find.text('Appartement 101 · Étage 1'));
      await tester.pumpAndSettle();

      expect(find.text('Statut du jour'), findsOneWidget);
    });

    testWidgets('aucun résultat', (tester) async {
      await _afficher(tester, _DepotSimule());
      await _taper(tester, find.byType(TextField), 'zzz');

      expect(find.text('Aucun appartement ne correspond à cette recherche.'),
          findsOneWidget);
    });

    testWidgets('n\'interroge le serveur qu\'après la pause de saisie',
        (tester) async {
      final depot = _DepotSimule();
      await _afficher(tester, depot);

      await tester.enterText(find.byType(TextField), '1');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), '10');
      await tester.pump(const Duration(milliseconds: 100));
      expect(depot.recherches, isEmpty);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(depot.recherches, ['10']);
    });
  });

  group('Fiche', () {
    testWidgets('affiche l\'appartement, les résidents et le statut',
        (tester) async {
      await _afficher(tester, _DepotSimule(ficheRenvoyee: _fiche()),
          initiale: receptionFicheRoute('a1'));

      expect(find.text('Appartement 101'), findsWidgets);
      expect(find.text('Étage 1 · 4 1/2'), findsOneWidget);
      expect(find.text('Jeanne Tremblay'), findsOneWidget);
      expect(find.text("Prévu aujourd'hui AM — Essie"), findsOneWidget);
    });

    testWidgets('appartement introuvable', (tester) async {
      await _afficher(tester, _DepotSimule(),
          initiale: receptionFicheRoute('inconnu'));

      expect(find.text('Cet appartement est introuvable.'), findsOneWidget);
    });

    testWidgets('liste plusieurs dates et propose l\'impression sans accord',
        (tester) async {
      await _afficher(tester, _DepotSimule(ficheRenvoyee: _fiche()),
          initiale: receptionFicheRoute('a1'));

      expect(find.text('Mardi 22/09/2026 — AM — Essie'), findsOneWidget);
      expect(find.text('Mardi 29/09/2026 — AM'), findsOneWidget);

      final bouton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Imprimer le calendrier'),
      );
      expect(bouton.onPressed, isNotNull);
    });

    testWidgets('sans date : message et impression désactivée', (tester) async {
      await _afficher(
          tester, _DepotSimule(ficheRenvoyee: _fiche(dates: const [])),
          initiale: receptionFicheRoute('a1'));

      expect(find.text('Aucune date planifiée.'), findsOneWidget);
      final bouton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Imprimer le calendrier'),
      );
      expect(bouton.onPressed, isNull);
    });

    testWidgets('non effectué : aucun motif ni nom à l\'écran', (tester) async {
      await _afficher(
        tester,
        _DepotSimule(
          ficheRenvoyee: _fiche(
            statut: const StatutDuJour(etat: EtatStatut.nonRealise),
          ),
        ),
        initiale: receptionFicheRoute('a1'),
      );

      expect(find.text("Non effectué aujourd'hui"), findsOneWidget);
      for (final mot in ['Absent', 'Refus', 'vacant', 'Motif', 'motif']) {
        expect(find.textContaining(mot), findsNothing, reason: mot);
      }
    });
  });

  group('Formulaire de message', () {
    Finder champMessage() => find.descendant(
          of: find.byType(Card),
          matching: find.byType(TextField),
        );

    testWidgets('« Envoyer » est désactivé tant que le message est vide',
        (tester) async {
      await _afficher(tester, _DepotSimule(ficheRenvoyee: _fiche()),
          initiale: receptionFicheRoute('a1'));

      FilledButton envoyer() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Envoyer'));
      expect(envoyer().onPressed, isNull);

      await tester.enterText(champMessage(), '   ');
      await tester.pump();
      expect(envoyer().onPressed, isNull);

      await tester.enterText(champMessage(), 'Bonjour');
      await tester.pump();
      expect(envoyer().onPressed, isNotNull);
    });

    testWidgets('envoi simple : la case reste décochée', (tester) async {
      final depot = _DepotSimule(ficheRenvoyee: _fiche());
      await _afficher(tester, depot, initiale: receptionFicheRoute('a1'));

      await tester.enterText(champMessage(), '  Fuite dans la salle de bain  ');
      await tester.pump();
      await tester.ensureVisible(find.text('Envoyer'));
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(depot.envois, hasLength(1));
      expect(depot.envois.single.appartementId, 'a1');
      expect(depot.envois.single.auteurId, 'r1');
      expect(depot.envois.single.message, 'Fuite dans la salle de bain');
      expect(depot.envois.single.transmettre, isFalse);
      expect(find.text('Message transmis à l\'administration.'), findsOneWidget);
    });

    testWidgets('transmission à l\'employé quand la case est cochée',
        (tester) async {
      final depot = _DepotSimule(ficheRenvoyee: _fiche());
      await _afficher(tester, depot, initiale: receptionFicheRoute('a1'));

      expect(find.text('Employé concerné : Essie'), findsOneWidget);

      await tester.enterText(champMessage(), 'Merci de passer plus tôt');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(depot.envois.single.transmettre, isTrue);
    });

    testWidgets('sans employé concerné, la case est désactivée', (tester) async {
      final depot = _DepotSimule(ficheRenvoyee: _fiche(concerne: null));
      await _afficher(tester, depot, initiale: receptionFicheRoute('a1'));

      final case_ = tester.widget<CheckboxListTile>(
          find.byType(CheckboxListTile));
      expect(case_.onChanged, isNull);
      expect(find.text('Aucun employé n\'est concerné par cet appartement.'),
          findsOneWidget);
    });

    testWidgets('une erreur du serveur s\'affiche et le texte est conservé',
        (tester) async {
      final depot = _DepotSimule(ficheRenvoyee: _fiche())
        ..erreurEnvoi = const ReceptionErreur('Auteur invalide ou inactif.');
      await _afficher(tester, depot, initiale: receptionFicheRoute('a1'));

      await tester.enterText(champMessage(), 'Bonjour');
      await tester.pump();
      await tester.ensureVisible(find.text('Envoyer'));
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(find.text('Auteur invalide ou inactif.'), findsOneWidget);
      expect(find.text('Bonjour'), findsOneWidget);
      expect(find.text('Message transmis à l\'administration.'), findsNothing);
    });
  });
}
