import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cleanops/core/errors/failures.dart';
import 'package:cleanops/core/router/app_router.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/domain/repositories/auth_repository.dart';
import 'package:cleanops/features/auth/domain/usecases/login_with_pin.dart';
import 'package:cleanops/features/auth/domain/usecases/logout.dart';
import 'package:cleanops/features/auth/domain/usecases/valider_niveau_un.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';
import 'package:cleanops/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:cleanops/features/profile/presentation/screens/profile_screen.dart';
import 'package:cleanops/features/reception/presentation/reception_sections.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_dashboard_screen.dart';
import 'package:cleanops/core/widgets/app_shell.dart';
import 'package:cleanops/core/widgets/app_top_bar.dart';

const _reception = Employee(
  id: 'r1',
  nom: 'Dab',
  prenom: 'Receptioniste',
  slug: 'receptioniste',
  role: RoleType.reception,
  isActif: true,
);

const _admin = Employee(
  id: 'a1',
  nom: 'Sylvestre',
  prenom: 'Nadine',
  slug: 'nadine',
  role: RoleType.admin,
  isActif: true,
);

class _RepoAuth implements AuthRepository {
  int deconnexions = 0;

  @override
  Future<Either<Failure, void>> logout() async {
    deconnexions++;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthDeTest extends AuthNotifier {
  _AuthDeTest(Employee employe, _RepoAuth repo)
      : super(
          loginWithPin: LoginWithPin(repo),
          logout: Logout(repo),
          validerNiveauUn: ValiderNiveauUn(repo),
        ) {
    setEmployee(employe);
  }
}

/// Dernier routeur de test, pour vérifier l'adresse réellement atteinte.
late GoRouter _routeur;

String get _adresse => _routeur.routeInformationProvider.value.uri.path;

Future<_RepoAuth> _afficher(
  WidgetTester tester, {
  required String initiale,
  Employee employe = _reception,
  Size taille = const Size(1200, 1400),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = taille;
  addTearDown(tester.view.reset);

  final repo = _RepoAuth();
  final router = GoRouter(
    initialLocation: initiale,
    routes: [
      // L'accueil dans l'enveloppe de l'app : c'est elle qui porte la cloche
      // et le menu du compte.
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: receptionAccueilRoute,
            builder: (_, __) => const ReceptionDashboardScreen(),
          ),
        ],
      ),
      GoRoute(
        path: receptionProfilRoute,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.profil,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.employerDashboard,
        builder: (_, __) => const Scaffold(body: Text('ACCUEIL RESPONSABLE')),
      ),
      GoRoute(
        path: AppRoutes.employeeDashboard,
        builder: (_, __) => const Scaffold(body: Text('ACCUEIL PREPOSEE')),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const Scaffold(body: Text('PAGE DE CONNEXION')),
      ),
    ],
  );

  _routeur = router;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith((ref) => _AuthDeTest(employe, repo)),
        unreadNotificationsCountProvider.overrideWithValue(0),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('Libellé du rôle', () {
    test('la Réception s\'affiche avec son accent', () {
      expect(RoleType.reception.libelleAffiche, 'Réception');
    });

    test('la valeur « label » (utilisée en base) ne change pas', () {
      expect(RoleType.reception.label, 'Reception');
    });

    test('les autres rôles gardent leur libellé', () {
      for (final r in RoleType.values.where((r) => r != RoleType.reception)) {
        expect(r.libelleAffiche, r.label, reason: '$r');
      }
    });
  });

  group('Accès à « Mon profil » de la Réception', () {
    test('la route est dans le périmètre de la Réception', () {
      expect(receptionProfilRoute, '/reception/profil');
      expect(estRouteReception(receptionProfilRoute), isTrue);
      expect(
        redirectionSelonAcces(
            employee: _reception, location: receptionProfilRoute),
        isNull,
      );
    });

    test('ce n\'est pas une section : ni menu, ni tableau de bord', () {
      expect(
        receptionSections.any((s) => s.route == receptionProfilRoute),
        isFalse,
      );
      expect(receptionSections, hasLength(5));
    });

    test('la Réception ne peut toujours pas ouvrir le profil des autres', () {
      expect(
        redirectionSelonAcces(employee: _reception, location: AppRoutes.profil),
        AppRoutes.reception,
      );
    });

    test('un responsable ne peut pas ouvrir celui de la Réception', () {
      expect(
        redirectionSelonAcces(employee: _admin, location: receptionProfilRoute),
        AppRoutes.employerDashboard,
      );
    });

    test('sans session, la route mène à la connexion', () {
      expect(
        redirectionSelonAcces(employee: null, location: receptionProfilRoute),
        AppRoutes.login,
      );
    });
  });

  group('Tableau de bord : profil et déconnexion', () {
    Future<void> ouvrirMenuCompte(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Mon compte'));
      await tester.pumpAndSettle();
    }

    testWidgets('notifications, profil et déconnexion', (tester) async {
      await _afficher(tester, initiale: receptionAccueilRoute);

      expect(find.byTooltip('Notifications'), findsOneWidget);
      await ouvrirMenuCompte(tester);
      expect(find.text('Mon profil'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
    });

    testWidgets('« Mon Profil » de l\'en-tête ouvre « Mon profil »',
        (tester) async {
      await _afficher(tester, initiale: receptionAccueilRoute);

      await tester.tap(find.text('Mon Profil'));
      await tester.pumpAndSettle();

      expect(find.text('Informations personnelles'), findsOneWidget);
      expect(_adresse, receptionProfilRoute,
          reason: 'le profil de la Réception, pas celui des autres');
    });

    testWidgets('le menu du compte ouvre aussi « Mon profil »', (tester) async {
      await _afficher(tester, initiale: receptionAccueilRoute);

      await ouvrirMenuCompte(tester);
      await tester.tap(find.text('Mon profil'));
      await tester.pumpAndSettle();

      expect(_adresse, receptionProfilRoute);
    });

    testWidgets('se déconnecter depuis l\'accueil', (tester) async {
      final repo = await _afficher(tester, initiale: receptionAccueilRoute);

      await ouvrirMenuCompte(tester);
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(find.text('Se déconnecter ?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Se déconnecter'));
      await tester.pumpAndSettle();

      expect(repo.deconnexions, 1);
      expect(find.text('PAGE DE CONNEXION'), findsOneWidget);
    });

    testWidgets('rester connecté ne déconnecte pas', (tester) async {
      final repo = await _afficher(tester, initiale: receptionAccueilRoute);

      await ouvrirMenuCompte(tester);
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rester connecté'));
      await tester.pumpAndSettle();

      expect(repo.deconnexions, 0);
      expect(find.text('PAGE DE CONNEXION'), findsNothing);
    });

    testWidgets('les 5 sections sont toujours là', (tester) async {
      await _afficher(tester, initiale: receptionAccueilRoute);
      for (final s in receptionSections) {
        expect(find.text(s.titre), findsWidgets, reason: s.titre);
      }
    });
  });

  group('Écran « Mon profil » de la Réception', () {
    testWidgets('affiche le prénom, le nom et le rôle', (tester) async {
      await _afficher(tester, initiale: receptionProfilRoute);

      expect(find.text('MON PROFIL'), findsOneWidget);
      expect(
          find.widgetWithText(TextFormField, 'Receptioniste'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Dab'), findsOneWidget);
      expect(find.text('Réception'), findsWidgets);
      expect(find.text('Reception'), findsNothing,
          reason: 'le rôle s\'affiche avec son accent');
      expect(find.text('Numéro de pointeuse'), findsNothing);
    });

    testWidgets('le rôle n\'est pas modifiable', (tester) async {
      await _afficher(tester, initiale: receptionProfilRoute);

      // Seuls le prénom et le nom sont des champs de saisie.
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byTooltip('Ce champ ne peut pas être modifié ici'),
          findsOneWidget);
    });

    testWidgets('« Retour » ramène à l\'accueil de la Réception',
        (tester) async {
      await _afficher(tester, initiale: receptionProfilRoute);

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('Que souhaitez-vous faire ?'), findsOneWidget);
    });

    testWidgets('rien à enregistrer si rien n\'a changé', (tester) async {
      await _afficher(tester, initiale: receptionProfilRoute);

      await tester.ensureVisible(find.text('Enregistrer les modifications'));
      await tester.tap(find.text('Enregistrer les modifications'));
      await tester.pumpAndSettle();

      expect(find.text('Aucune modification à enregistrer.'), findsOneWidget);
    });

    testWidgets('un prénom vide est refusé', (tester) async {
      await _afficher(tester, initiale: receptionProfilRoute);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Receptioniste'), '  ');
      await tester.ensureVisible(find.text('Enregistrer les modifications'));
      await tester.tap(find.text('Enregistrer les modifications'));
      await tester.pumpAndSettle();

      expect(find.text('Prénom requis'), findsOneWidget);
      expect(find.text('Votre profil a bien été mis à jour.'), findsNothing);
    });

    testWidgets('un nom trop court est refusé', (tester) async {
      await _afficher(tester, initiale: receptionProfilRoute);

      await tester.enterText(find.widgetWithText(TextFormField, 'Dab'), 'D');
      await tester.ensureVisible(find.text('Enregistrer les modifications'));
      await tester.tap(find.text('Enregistrer les modifications'));
      await tester.pumpAndSettle();

      expect(find.text('Nom trop court'), findsOneWidget);
    });

    testWidgets('se déconnecter depuis le profil', (tester) async {
      final repo = await _afficher(tester, initiale: receptionProfilRoute);

      await tester
          .ensureVisible(find.widgetWithText(OutlinedButton, 'Se déconnecter'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Se déconnecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Se déconnecter'));
      await tester.pumpAndSettle();

      expect(repo.deconnexions, 1);
      expect(find.text('PAGE DE CONNEXION'), findsOneWidget);
    });

    testWidgets('sur mobile aussi', (tester) async {
      await _afficher(tester,
          initiale: receptionProfilRoute, taille: const Size(420, 900));

      expect(find.text('MON PROFIL'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Réception'), findsWidgets);
    });
  });

  group('Les autres profils ne changent pas', () {
    testWidgets('un responsable garde son libellé de rôle', (tester) async {
      await _afficher(tester, initiale: AppRoutes.profil, employe: _admin);

      expect(find.text('Admin'), findsWidgets);
      expect(find.text('Réception'), findsNothing);
    });

    testWidgets('« Retour » d\'un responsable : son tableau de bord',
        (tester) async {
      await _afficher(tester, initiale: AppRoutes.profil, employe: _admin);

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('ACCUEIL RESPONSABLE'), findsOneWidget);
    });

    testWidgets('« Retour » d\'une préposée : son tableau de bord',
        (tester) async {
      const preposee = Employee(
        id: 'p1',
        nom: 'France',
        prenom: 'Essie',
        slug: 'essie',
        role: RoleType.employe,
        isActif: true,
      );
      await _afficher(tester, initiale: AppRoutes.profil, employe: preposee);

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('ACCUEIL PREPOSEE'), findsOneWidget);
    });

    testWidgets('la barre du haut d\'un responsable : cloche et compte',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeeCourantProvider.overrideWithValue(_admin),
            unreadNotificationsCountProvider.overrideWithValue(0),
          ],
          child: MaterialApp(
            home: Scaffold(body: AppTopBar(onMenu: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Menu'), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.byTooltip('Mon compte'), findsOneWidget);
    });
  });
}
