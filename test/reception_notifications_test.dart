import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cleanops/core/errors/failures.dart';
import 'package:cleanops/core/router/app_router.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';
import 'package:cleanops/features/messages_reception_responsable/domain/messages_reception_responsable_repository.dart';
import 'package:cleanops/features/messages_reception_responsable/presentation/providers/messages_reception_responsable_provider.dart';
import 'package:cleanops/features/notifications/domain/entities/notification.dart';
import 'package:cleanops/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:cleanops/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:cleanops/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:cleanops/features/reception/domain/reception_messages_models.dart';
import 'package:cleanops/features/reception/domain/reception_models.dart'
    show NatureDemande;
import 'package:cleanops/features/reception/presentation/reception_sections.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_dashboard_screen.dart';
import 'package:cleanops/features/resident_espace/domain/entities/demande_resident.dart';
import 'package:cleanops/features/resident_espace/domain/repositories/resident_espace_repository.dart';
import 'package:cleanops/features/resident_espace/presentation/providers/resident_espace_provider.dart';
import 'package:cleanops/features/resident_espace/presentation/screens/demandes_residents_responsable_screen.dart';

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

const _preposee = Employee(
  id: 'p1',
  nom: 'France',
  prenom: 'Essie',
  slug: 'essie',
  role: RoleType.employe,
  isActif: true,
);

AppNotification _notif(
  String id,
  String type,
  String message, {
  bool lue = false,
}) =>
    AppNotification(
      id: id,
      recipientId: 'x',
      type: type,
      category: NotificationCategory.fromValue(type),
      message: message,
      isRead: lue,
      sentAt: DateTime(2026, 9, 21, 15, 0),
      entityId: 'a1',
      entityType: 'Appartement',
    );

const _reponse = 'Réponse du responsable — Apt 101 : nous passons demain.';
const _resolue = "Demande résolue — Apt 202 : l'horaire a été modifié.";

List<AppNotification> _jeu() => [
      _notif('n1', 'MessageReception', _reponse),
      _notif('n2', 'MessageReception', _resolue),
      _notif('n3', 'MessageReception', 'Ancienne réponse', lue: true),
    ];

class _RepoNotifs implements NotificationsRepository {
  final List<AppNotification> items;
  final lus = <String>[];

  _RepoNotifs(this.items);

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications(
          String recipientId) async =>
      Right(items);

  @override
  Stream<List<AppNotification>> watchNotifications(String recipientId) =>
      const Stream.empty();

  @override
  Future<Either<Failure, Unit>> markAsRead(String notificationId) async {
    lus.add(notificationId);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> markAllAsRead(String recipientId) async =>
      const Right(unit);
}

class _MessagesVides implements MessagesReceptionResponsableRepository {
  @override
  Future<List<MessageTransmis>> messages() async => [
        MessageTransmis(
          id: 'm1',
          appartementId: 'a101',
          numero: '101',
          message: 'Annuler jeudi',
          auteurPrenom: 'Receptioniste',
          statut: StatutMessage.enAttente,
          nature: NatureDemande.annulation,
          dateCreation: DateTime(2026, 9, 21, 9, 5),
        ),
      ];

  @override
  Future<void> repondre({
    required String messageId,
    required String auteurId,
    required String reponse,
  }) async {}

  @override
  Future<void> resoudre({
    required String messageId,
    required String auteurId,
  }) async {}
}

class _DemandesVides implements ResidentEspaceRepository {
  @override
  Future<Either<Failure, List<DemandeResident>>> getAllDemandes() async =>
      const Right([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late GoRouter _routeur;

String get _adresse => _routeur.routeInformationProvider.value.uri.toString();

Future<_RepoNotifs> _afficher(
  WidgetTester tester, {
  required String initiale,
  Employee employe = _reception,
  List<AppNotification>? notifications,
  Size taille = const Size(1200, 1600),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = taille;
  addTearDown(tester.view.reset);

  final repo = _RepoNotifs(notifications ?? _jeu());
  _routeur = GoRouter(
    initialLocation: initiale,
    routes: [
      GoRoute(
        path: receptionAccueilRoute,
        builder: (_, __) => const ReceptionDashboardScreen(),
      ),
      GoRoute(
        path: receptionNotificationsRoute,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: receptionMessagesRoute,
        builder: (_, __) => const Scaffold(body: Text('PAGE MESSAGES TRANSMIS')),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.demandesResidents,
        builder: (_, state) => DemandesResidentsResponsableScreen(
          ouvrirMessages: state.uri.queryParameters['onglet'] ==
              AppRoutes.ongletMessagesReception,
        ),
      ),
      GoRoute(
        path: AppRoutes.memo,
        builder: (_, __) => const Scaffold(body: Text('PAGE MEMO')),
      ),
      GoRoute(
        path: AppRoutes.presences,
        builder: (_, __) => const Scaffold(body: Text('PAGE PRESENCES')),
      ),
      GoRoute(
        path: AppRoutes.employerDashboard,
        builder: (_, __) => const Scaffold(body: Text('ACCUEIL RESPONSABLE')),
      ),
      GoRoute(
        path: AppRoutes.employeeDashboard,
        builder: (_, __) => const Scaffold(body: Text('ACCUEIL PREPOSEE')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        employeeCourantProvider.overrideWithValue(employe),
        notificationsRepositoryProvider.overrideWithValue(repo),
        messagesReceptionResponsableRepositoryProvider
            .overrideWithValue(_MessagesVides()),
        residentEspaceRepositoryProvider.overrideWithValue(_DemandesVides()),
      ],
      child: MaterialApp.router(routerConfig: _routeur),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('Accès de la Réception à ses notifications', () {
    test('la route est dans son périmètre', () {
      expect(receptionNotificationsRoute, '/reception/notifications');
      expect(estRouteReception(receptionNotificationsRoute), isTrue);
      expect(
        redirectionSelonAcces(
            employee: _reception, location: receptionNotificationsRoute),
        isNull,
      );
    });

    test('ce n\'est pas une section', () {
      expect(
        receptionSections.any((s) => s.route == receptionNotificationsRoute),
        isFalse,
      );
      expect(receptionSections, hasLength(5));
    });

    test('l\'écran des notifications des autres reste fermé à la Réception',
        () {
      expect(
        redirectionSelonAcces(
            employee: _reception, location: AppRoutes.notifications),
        AppRoutes.reception,
      );
    });

    test('un responsable ne peut pas ouvrir celui de la Réception', () {
      expect(
        redirectionSelonAcces(
            employee: _admin, location: receptionNotificationsRoute),
        AppRoutes.employerDashboard,
      );
    });
  });

  group('Accueil de retour selon le profil (partagé profil / notifications)',
      () {
    test('un accueil par profil', () {
      expect(accueilDe(_reception), receptionAccueilRoute);
      expect(accueilDe(_admin), AppRoutes.employerDashboard);
      expect(accueilDe(_preposee), AppRoutes.employeeDashboard);
      const resident = Employee(
        id: 'z',
        nom: 'A',
        prenom: 'B',
        slug: 'z',
        role: RoleType.resident,
        isActif: true,
      );
      expect(accueilDe(resident), AppRoutes.residentDashboard);
    });
  });

  group('Cloche de la Réception', () {
    testWidgets('elle affiche le nombre de notifications non lues',
        (tester) async {
      await _afficher(tester, initiale: receptionAccueilRoute);

      expect(find.byTooltip('Notifications'), findsOneWidget);
      // 2 non lues sur 3.
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('sans notification non lue, pas de pastille', (tester) async {
      await _afficher(tester,
          initiale: receptionAccueilRoute,
          notifications: [_notif('n3', 'MessageReception', 'Lue', lue: true)]);

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('elle mène aux notifications de la Réception', (tester) async {
      await _afficher(tester, initiale: receptionAccueilRoute);

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(_adresse, receptionNotificationsRoute);
      expect(find.text(_reponse), findsOneWidget);
    });
  });

  group('Écran des notifications, côté Réception', () {
    testWidgets('liste les réponses et résolutions du responsable',
        (tester) async {
      await _afficher(tester, initiale: receptionNotificationsRoute);

      expect(find.text('Notifications'), findsWidgets);
      expect(find.text(_reponse), findsOneWidget);
      expect(find.text(_resolue), findsOneWidget);
      expect(find.text('Ancienne réponse'), findsOneWidget);
    });

    testWidgets('« Retour » ramène à l\'accueil de la Réception',
        (tester) async {
      await _afficher(tester, initiale: receptionNotificationsRoute);

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('Que souhaitez-vous faire ?'), findsOneWidget);
      expect(_adresse, receptionAccueilRoute);
    });

    testWidgets('une notification de message ouvre « Messages transmis »',
        (tester) async {
      final repo =
          await _afficher(tester, initiale: receptionNotificationsRoute);

      await tester.tap(find.text(_reponse));
      await tester.pumpAndSettle();

      expect(repo.lus, ['n1'], reason: 'la notification est marquée lue');
      expect(_adresse, receptionMessagesRoute);
      expect(find.text('PAGE MESSAGES TRANSMIS'), findsOneWidget);
    });

    testWidgets('une notification d\'un autre type n\'emmène nulle part',
        (tester) async {
      await _afficher(
        tester,
        initiale: receptionNotificationsRoute,
        notifications: [_notif('n9', 'AbsenceValidee', 'Une absence')],
      );

      await tester.tap(find.text('Une absence'));
      await tester.pumpAndSettle();

      expect(_adresse, receptionNotificationsRoute,
          reason: 'les autres écrans sont fermés à la Réception');
    });

    testWidgets('sur mobile aussi', (tester) async {
      await _afficher(tester,
          initiale: receptionNotificationsRoute, taille: const Size(420, 900));

      expect(find.text(_reponse), findsOneWidget);
    });
  });

  group('Correction : notification de message pour les autres profils', () {
    testWidgets(
        'le responsable arrive sur l\'onglet « Messages de la réception »',
        (tester) async {
      await _afficher(
        tester,
        initiale: AppRoutes.notifications,
        employe: _admin,
        notifications: [
          _notif('n1', 'MessageReception',
              'Message de la réception — Apt 101 · annulation : Annuler jeudi'),
        ],
      );

      await tester.tap(find.textContaining('Message de la réception'));
      await tester.pumpAndSettle();

      expect(_adresse, AppRoutes.demandesResidentsMessages);
      expect(_adresse, contains('onglet=messages'));
      expect(find.text('Apt 101 · Annulation'), findsOneWidget);
      expect(find.text('Tous types'), findsNothing,
          reason: 'l\'onglet des messages est ouvert, pas celui des demandes');
    });

    testWidgets('le responsable n\'est plus envoyé vers le mémo',
        (tester) async {
      await _afficher(
        tester,
        initiale: AppRoutes.notifications,
        employe: _admin,
        notifications: [_notif('n1', 'MessageReception', 'Un message')],
      );

      await tester.tap(find.text('Un message'));
      await tester.pumpAndSettle();

      expect(find.text('PAGE MEMO'), findsNothing);
    });

    testWidgets('les autres notifications du responsable vont où elles allaient',
        (tester) async {
      await _afficher(
        tester,
        initiale: AppRoutes.notifications,
        employe: _admin,
        notifications: [_notif('n1', 'NouveauMemo', 'Nouveau mémo')],
      );

      await tester.tap(find.text('Nouveau mémo'));
      await tester.pumpAndSettle();

      expect(_adresse, AppRoutes.memo);
    });

    testWidgets('une notification d\'absence du responsable : inchangée',
        (tester) async {
      await _afficher(
        tester,
        initiale: AppRoutes.notifications,
        employe: _admin,
        notifications: [_notif('n1', 'AbsenceValidee', 'Absence validée')],
      );

      await tester.tap(find.text('Absence validée'));
      await tester.pumpAndSettle();

      expect(_adresse, AppRoutes.presences);
    });

    testWidgets('« Retour » d\'un responsable : son tableau de bord',
        (tester) async {
      await _afficher(tester,
          initiale: AppRoutes.notifications, employe: _admin);

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('ACCUEIL RESPONSABLE'), findsOneWidget);
    });

    testWidgets('« Retour » d\'une préposée : son tableau de bord',
        (tester) async {
      await _afficher(tester,
          initiale: AppRoutes.notifications, employe: _preposee);

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('ACCUEIL PREPOSEE'), findsOneWidget);
    });

    testWidgets('une préposée ne va nulle part avec un message de la Réception',
        (tester) async {
      await _afficher(
        tester,
        initiale: AppRoutes.notifications,
        employe: _preposee,
        notifications: [_notif('n1', 'MessageReception', 'Un message')],
      );

      await tester.tap(find.text('Un message'));
      await tester.pumpAndSettle();

      expect(_adresse, AppRoutes.notifications);
    });
  });
}
