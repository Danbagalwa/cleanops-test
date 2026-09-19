import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleanops/core/widgets/app_shell.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';

Employee _avec(RoleType role) => Employee(
      id: 'id',
      nom: 'N',
      prenom: 'P',
      slug: 's',
      role: role,
      isActif: true,
    );

const _contenu = 'DONNÉES DE LA PAGE DEMANDÉE';

Future<void> _afficher(
  WidgetTester tester,
  RoleType role, {
  String location = '/planning',
  Size taille = const Size(1200, 900),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = taille;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        employeeCourantProvider.overrideWithValue(_avec(role)),
      ],
      child: MaterialApp(
        home: AppShell(location: location, child: const Text(_contenu)),
      ),
    ),
  );
  await tester.pump();
}

/// Entrées de menu du responsable et de la préposée : jamais pour la Réception.
const _menusInterdits = [
  'Planning',
  'Employé(e)s',
  'Chat Équipe',
  'Mémo',
  'Statistiques',
  'Demandes équipe',
  'Absences',
  'Progression du jour',
  'Ma Journée',
  'Appartements',
  'Aires communes',
  'Messages semaine',
];

void main() {
  group('Réception hors de sa vue : refus', () {
    testWidgets('la page demandée n\'est JAMAIS affichée, seulement un refus',
        (tester) async {
      await _afficher(tester, RoleType.reception, location: '/planning');

      expect(find.text(_contenu), findsNothing);
      expect(find.text('Accès non disponible pour ce profil.'), findsOneWidget);
    });

    testWidgets('aucun menu du responsable ni de la préposée', (tester) async {
      await _afficher(tester, RoleType.reception, location: '/planning');

      for (final entree in _menusInterdits) {
        expect(find.text(entree), findsNothing, reason: entree);
      }
    });

    testWidgets('un chemin qui ressemble à /reception est refusé',
        (tester) async {
      for (final piege in ['/receptionniste', '/reception-x']) {
        await _afficher(tester, RoleType.reception, location: piege);
        expect(find.text(_contenu), findsNothing, reason: piege);
      }
    });
  });

  group('Réception dans sa vue : menu à 5 sections', () {
    testWidgets('bureau : accueil + 5 sections dans la barre latérale',
        (tester) async {
      await _afficher(tester, RoleType.reception, location: '/reception');

      expect(find.text(_contenu), findsOneWidget);
      expect(find.text('Accès non disponible pour ce profil.'), findsNothing);
      for (final entree in [
        'Tableau de bord',
        'Résidents',
        'Équipe',
        'À aviser',
        'PIN',
        'Messages transmis',
      ]) {
        expect(find.text(entree), findsWidgets, reason: entree);
      }
    });

    testWidgets('bureau : aucune entrée du responsable ni de la préposée',
        (tester) async {
      await _afficher(tester, RoleType.reception, location: '/reception');

      for (final entree in _menusInterdits) {
        expect(find.text(entree), findsNothing, reason: entree);
      }
    });

    testWidgets('mobile : la barre du bas montre les 6 entrées sans débordement',
        (tester) async {
      await _afficher(
        tester,
        RoleType.reception,
        location: '/reception',
        taille: const Size(390, 800),
      );

      expect(tester.takeException(), isNull);
      for (final entree in [
        'Accueil',
        'Résidents',
        'Équipe',
        'À aviser',
        'PIN',
        'Messages',
      ]) {
        expect(find.text(entree), findsOneWidget, reason: entree);
      }
      // Toutes les sections sont directement accessibles : pas de tiroir « Plus ».
      expect(find.text('Plus'), findsNothing);
    });

    testWidgets('mobile : aucune entrée du responsable ni de la préposée',
        (tester) async {
      await _afficher(
        tester,
        RoleType.reception,
        location: '/reception/residents',
        taille: const Size(390, 800),
      );

      for (final entree in _menusInterdits) {
        expect(find.text(entree), findsNothing, reason: entree);
      }
    });

    testWidgets('chaque section est accessible depuis le menu', (tester) async {
      for (final route in [
        '/reception/residents',
        '/reception/equipe',
        '/reception/a-aviser',
        '/reception/pin',
        '/reception/messages',
      ]) {
        await _afficher(tester, RoleType.reception, location: route);
        expect(find.text(_contenu), findsOneWidget, reason: route);
      }
    });
  });

  testWidgets('Contrôle : un Admin voit toujours la page et son menu',
      (tester) async {
    await _afficher(tester, RoleType.admin);

    expect(find.text(_contenu), findsOneWidget);
    expect(find.text('Accès non disponible pour ce profil.'), findsNothing);
    expect(find.text('Employé(e)s'), findsWidgets);
  });
}
