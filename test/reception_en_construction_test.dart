import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_en_construction_screen.dart';

void main() {
  const reception = Employee(
    id: 'r1',
    nom: 'Tremblay',
    prenom: 'Marie',
    slug: 'reception-jt',
    role: RoleType.reception,
    isActif: true,
  );

  Future<void> afficher(WidgetTester tester, Employee? employee) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [employeeCourantProvider.overrideWithValue(employee)],
        child: const MaterialApp(home: ReceptionEnConstructionScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('annonce que la vue Réception est en construction',
      (tester) async {
    await afficher(tester, reception);

    expect(find.text('Vue Réception en construction'), findsOneWidget);
    expect(find.textContaining('pas encore disponible'), findsOneWidget);
  });

  testWidgets('affiche la personne connectée et propose de se déconnecter',
      (tester) async {
    await afficher(tester, reception);

    expect(find.text('Connecté(e) : Marie Tremblay'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });

  testWidgets('n\'affiche aucune donnée de l\'application ni navigation',
      (tester) async {
    await afficher(tester, reception);

    // Aucun menu, aucune liste, aucun accès aux écrans du responsable.
    for (final interdit in [
      'Planning',
      'Employé(e)s',
      'Résidents',
      'Chat Équipe',
      'Mémo',
      'Statistiques',
      'Demandes équipe',
      'Absences',
      'Tableau de bord',
    ]) {
      expect(find.text(interdit), findsNothing, reason: interdit);
    }
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('sans utilisateur, n\'affiche pas de nom', (tester) async {
    await afficher(tester, null);

    expect(find.textContaining('Connecté(e)'), findsNothing);
    expect(find.text('Vue Réception en construction'), findsOneWidget);
  });
}
