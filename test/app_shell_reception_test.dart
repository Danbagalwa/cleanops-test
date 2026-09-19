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

Future<void> _afficher(WidgetTester tester, RoleType role) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 900);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        employeeCourantProvider.overrideWithValue(_avec(role)),
      ],
      child: const MaterialApp(
        home: AppShell(
          location: '/planning',
          child: Text('DONNÉES DE LA PAGE DEMANDÉE'),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
      'Réception : la page demandée n\'est JAMAIS affichée, seulement un refus',
      (tester) async {
    await _afficher(tester, RoleType.reception);

    expect(find.text('DONNÉES DE LA PAGE DEMANDÉE'), findsNothing);
    expect(find.text('Accès non disponible pour ce profil.'), findsOneWidget);
  });

  testWidgets('Réception : aucun menu du responsable ni de la préposée',
      (tester) async {
    await _afficher(tester, RoleType.reception);

    for (final entree in [
      'Planning',
      'Employé(e)s',
      'Chat Équipe',
      'Mémo',
      'Statistiques',
      'Demandes équipe',
      'Absences',
      'Progression du jour',
      'Ma Journée',
      'Tableau de bord',
    ]) {
      expect(find.text(entree), findsNothing, reason: entree);
    }
  });

  testWidgets('Contrôle : un Admin voit toujours la page et son menu',
      (tester) async {
    await _afficher(tester, RoleType.admin);

    expect(find.text('DONNÉES DE LA PAGE DEMANDÉE'), findsOneWidget);
    expect(find.text('Accès non disponible pour ce profil.'), findsNothing);
    expect(find.text('Employé(e)s'), findsWidgets);
  });
}
