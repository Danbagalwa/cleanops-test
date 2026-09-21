import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';
import 'package:cleanops/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:cleanops/features/reception/presentation/reception_sections.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_dashboard_screen.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_section_screen.dart';

const _reception = Employee(
  id: 'r1',
  nom: 'Dab',
  prenom: 'Receptioniste',
  slug: 'receptioniste',
  role: RoleType.reception,
  isActif: true,
);

Future<void> _afficher(WidgetTester tester, {Size taille = const Size(1000, 900)}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = taille;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: receptionAccueilRoute,
    routes: [
      GoRoute(
        path: receptionAccueilRoute,
        builder: (_, __) => const ReceptionDashboardScreen(),
      ),
      for (final s in receptionSections)
        GoRoute(
          path: s.route,
          builder: (_, __) => ReceptionSectionScreen(section: s),
        ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        employeeCourantProvider.overrideWithValue(_reception),
        unreadNotificationsCountProvider.overrideWithValue(0),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('Tableau de bord Réception', () {
    testWidgets('accueille la personne connectée', (tester) async {
      await _afficher(tester);

      expect(find.text('Bonjour Receptioniste'), findsOneWidget);
      expect(find.text('Que souhaitez-vous faire ?'), findsOneWidget);
    });

    testWidgets('propose exactement les 5 sections de la vue Réception',
        (tester) async {
      await _afficher(tester);

      for (final section in receptionSections) {
        expect(find.text(section.titre), findsOneWidget, reason: section.titre);
        expect(find.text(section.description), findsOneWidget,
            reason: section.titre);
      }
      expect(receptionSections.map((s) => s.titre).toList(), [
        'Résidents',
        'Équipe',
        'À aviser',
        'PIN',
        'Messages transmis',
      ]);
    });

    testWidgets('mobile : aucune erreur d\'affichage', (tester) async {
      await _afficher(tester, taille: const Size(390, 800));

      expect(tester.takeException(), isNull);
      expect(find.text('Résidents'), findsOneWidget);
    });

    testWidgets('n\'affiche AUCUNE donnée : ni compteur, ni progression, ni liste',
        (tester) async {
      await _afficher(tester);

      expect(find.byType(ListView), findsNothing);
      for (final interdit in [
        'Progression',
        'non confirmée',
        'tâche',
        'Statistiques',
        'Planning',
        '%',
      ]) {
        expect(find.textContaining(interdit), findsNothing, reason: interdit);
      }
    });

    for (final section in receptionSections) {
      testWidgets('toucher « ${section.titre} » ouvre ${section.route}',
          (tester) async {
        await _afficher(tester);

        await tester.tap(find.text(section.titre));
        await tester.pumpAndSettle();

        expect(find.text('Section en construction'), findsOneWidget);
        expect(find.text(section.description), findsOneWidget);
        expect(find.text('Bonjour Receptioniste'), findsNothing);
      });
    }
  });

  group('Page provisoire d\'une section', () {
    testWidgets('annonce la section et ce qu\'elle permettra de faire',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReceptionSectionScreen(section: receptionSections[3]),
        ),
      );

      expect(find.text('PIN'), findsOneWidget);
      expect(find.text('Section en construction'), findsOneWidget);
      expect(find.textContaining('PIN d\'un résident'), findsOneWidget);
    });
  });

  group('estRouteReception', () {
    test('accepte l\'accueil et les sections', () {
      expect(estRouteReception('/reception'), isTrue);
      for (final s in receptionSections) {
        expect(estRouteReception(s.route), isTrue, reason: s.route);
      }
      expect(estRouteReception('/reception/residents/abc'), isTrue);
    });

    test('refuse tout le reste, y compris les chemins qui y ressemblent', () {
      for (final chemin in [
        '/',
        '/planning',
        '/employeur',
        '/receptionniste',
        '/reception-x',
        '/receptio',
        '',
      ]) {
        expect(estRouteReception(chemin), isFalse, reason: chemin);
      }
    });
  });
}
