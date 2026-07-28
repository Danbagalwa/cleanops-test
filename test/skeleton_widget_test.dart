import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jazz_teasdale/core/widgets/skeleton_widget.dart';

void main() {
  testWidgets('affiche une structure de liste pendant le chargement',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: AppSkeletonList(itemCount: 3),
          ),
        ),
      ),
    );

    expect(find.byType(SkeletonShimmer), findsOneWidget);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.bySemanticsLabel('Chargement du contenu'), findsOneWidget);
  });

  testWidgets('affiche la structure d’un formulaire', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppSkeletonForm(fieldCount: 3)),
      ),
    );

    expect(find.byType(SkeletonShimmer), findsOneWidget);
    expect(find.bySemanticsLabel('Préparation du formulaire'), findsOneWidget);
  });
}
