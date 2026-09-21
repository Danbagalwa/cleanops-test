import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';
import 'package:cleanops/features/reception/domain/reception_avis_models.dart';
import 'package:cleanops/features/reception/domain/reception_avis_repository.dart';
import 'package:cleanops/features/reception/domain/reception_residents_repository.dart'
    show ReceptionErreur;
import 'package:cleanops/features/reception/presentation/providers/reception_avis_provider.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_a_aviser_screen.dart';

const _reception = Employee(
  id: 'r1',
  nom: 'Dab',
  prenom: 'Receptioniste',
  slug: 'receptioniste',
  role: RoleType.reception,
  isActif: true,
);

class _Traitement {
  final String avisId;
  final String auteurId;
  final ActionAvis action;
  final String? commentaire;

  _Traitement(this.avisId, this.auteurId, this.action, this.commentaire);
}

class _DepotSimule implements ReceptionAvisRepository {
  List<AvisResident> liste;
  Object? erreurListe;
  Object? erreurTraitement;
  int chargements = 0;
  final traitements = <_Traitement>[];

  _DepotSimule(this.liste);

  @override
  Future<List<AvisResident>> avis() async {
    chargements++;
    if (erreurListe != null) throw erreurListe!;
    return liste;
  }

  @override
  Future<void> traiter({
    required String avisId,
    required String auteurId,
    required ActionAvis action,
    String? commentaire,
  }) async {
    if (erreurTraitement != null) throw erreurTraitement!;
    traitements.add(_Traitement(avisId, auteurId, action, commentaire));
  }
}

AvisResident _avis(
  String id,
  String prenom,
  String nom,
  String numero, {
  TypeAvis type = TypeAvis.absence,
  StatutAvis statut = StatutAvis.aAviser,
  String message = 'La préposée prévue est absente.',
  String? commentaire,
  int minutes = 10,
  bool enRetard = false,
}) =>
    AvisResident(
      id: id,
      prenom: prenom,
      nom: nom,
      appartementId: 'a$numero',
      numero: numero,
      type: type,
      message: message,
      statut: statut,
      commentaire: commentaire,
      depuisMinutes: minutes,
      enRetard: enRetard,
    );

List<AvisResident> _jeu() => [
      _avis('1', 'Aline', 'Parenteau', '101',
          minutes: 190, enRetard: true, type: TypeAvis.absence),
      _avis('2', 'Paul', 'Gagnon', '202',
          minutes: 35,
          type: TypeAvis.remplacement,
          message: 'Votre ménage est confirmé — Préposée : Essie'),
      _avis('3', 'Marie', 'Roy', '303',
          statut: StatutAvis.reporte,
          minutes: 5,
          type: TypeAvis.menageEnAttente),
      _avis('4', 'Jeanne', 'Tremblay', '404',
          statut: StatutAvis.appele,
          commentaire: 'Rappellera demain',
          type: TypeAvis.reprogrammation),
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
        receptionAvisRepositoryProvider.overrideWithValue(depot),
      ],
      child: const MaterialApp(home: ReceptionAAviserScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Modèles', () {
    test('analyse du JSON du serveur', () {
      final a = AvisResident.fromJson({
        'id': 'x1',
        'resident_id': 'r1',
        'prenom': 'Aline',
        'nom': 'Parenteau',
        'appartement_id': 'a1',
        'numero': '101',
        'type': 'Remplacement',
        'message': 'Votre ménage est confirmé',
        'statut': 'Reporte',
        'commentaire': null,
        'depuis_minutes': 130,
        'en_retard': true,
        'traite_le': null,
      });

      expect(a.nomComplet, 'Aline Parenteau');
      expect(a.initiales, 'AP');
      expect(a.type, TypeAvis.remplacement);
      expect(a.statut, StatutAvis.reporte);
      expect(a.ouvert, isTrue);
      expect(a.enRetard, isTrue);
      expect(a.commentaire, isNull);
    });

    test('libellés des types et des statuts', () {
      expect(TypeAvis.fromCode('Absence').libelle, 'Préposée absente');
      expect(TypeAvis.fromCode('Remplacement').libelle,
          'Remplacement confirmé');
      expect(TypeAvis.fromCode('MenageEnAttente').libelle,
          'Ménage annulé, en attente');
      expect(TypeAvis.fromCode('Reprogrammation').libelle, 'Ménage déplacé');

      expect(StatutAvis.fromCode('AAviser').libelle, 'À aviser');
      expect(StatutAvis.fromCode('Reporte').libelle, 'Reporté');
      expect(StatutAvis.fromCode('Appele').libelle, 'Appelé(e)');
      expect(StatutAvis.fromCode('NoteLaissee').libelle, 'Note laissée');
    });

    test('seuls « À aviser » et « Reporté » sont ouverts', () {
      expect(StatutAvis.aAviser.ouvert, isTrue);
      expect(StatutAvis.reporte.ouvert, isTrue);
      expect(StatutAvis.appele.ouvert, isFalse);
      expect(StatutAvis.noteLaissee.ouvert, isFalse);
    });

    test('les 3 actions envoient la valeur attendue par le serveur', () {
      expect(ActionAvis.appele.code, 'Appele');
      expect(ActionAvis.noteLaissee.code, 'NoteLaissee');
      expect(ActionAvis.reporter.code, 'Reporte');
      expect(ActionAvis.reporter.libelle, 'Reporter');
    });

    test('une valeur inconnue est refusée plutôt qu\'affichée de travers', () {
      expect(() => TypeAvis.fromCode('Autre'), throwsFormatException);
      expect(() => StatutAvis.fromCode('Traitee'), throwsFormatException);
    });

    test('durée écoulée', () {
      String depuis(int m) => _avis('x', 'A', 'B', '1', minutes: m).depuis;
      expect(depuis(0), "à l'instant");
      expect(depuis(35), 'il y a 35 min');
      expect(depuis(60), 'il y a 1 h');
      expect(depuis(125), 'il y a 2 h 05');
      expect(depuis(130), 'il y a 2 h 10');
    });
  });

  group('Tableau À aviser', () {
    testWidgets('s\'ouvre sur les avis à traiter', (tester) async {
      final depot = _DepotSimule(_jeu());
      await _afficher(tester, depot);

      for (final t in [
        'RÉSIDENT',
        'APPARTEMENT',
        'RAISON',
        'DEPUIS',
        'STATUT',
        'ACTIONS'
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('À aviser  (3)'), findsOneWidget);
      expect(find.text('Aline Parenteau'), findsOneWidget);
      expect(find.text('Paul Gagnon'), findsOneWidget);
      expect(find.text('Marie Roy'), findsOneWidget);
      // Traité : masqué dans la vue par défaut.
      expect(find.text('Jeanne Tremblay'), findsNothing);
    });

    testWidgets('affiche raison, durée et statut', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      expect(find.text('Préposée absente'), findsOneWidget);
      expect(find.text('Remplacement confirmé'), findsOneWidget);
      expect(find.text('il y a 3 h 10'), findsOneWidget);
      expect(find.text('il y a 35 min'), findsOneWidget);
      expect(find.text('À aviser'), findsWidgets);
      expect(find.text('Reporté'), findsOneWidget);
    });

    testWidgets('badge rouge seulement pour l\'avis en retard', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      expect(find.text('En retard'), findsOneWidget);
      expect(find.text('1 résident attend depuis plus de 2 heures.'),
          findsOneWidget);
    });

    testWidgets('pluriel du bandeau quand plusieurs sont en retard',
        (tester) async {
      final liste = [
        _avis('1', 'A', 'A', '1', minutes: 150, enRetard: true),
        _avis('2', 'B', 'B', '2', minutes: 300, enRetard: true),
      ];
      await _afficher(tester, _DepotSimule(liste));

      expect(find.text('2 résidents attendent depuis plus de 2 heures.'),
          findsOneWidget);
      expect(find.text('En retard'), findsNWidgets(2));
    });

    testWidgets('aucun badge ni bandeau quand personne n\'est en retard',
        (tester) async {
      final liste = [_avis('1', 'A', 'A', '1', minutes: 30)];
      await _afficher(tester, _DepotSimule(liste));

      expect(find.text('En retard'), findsNothing);
      expect(find.textContaining('attend'), findsNothing);
    });

    testWidgets('filtre « Traités aujourd\'hui » avec le commentaire',
        (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.tap(find.text("Traités aujourd'hui"));
      await tester.pump();

      expect(find.text('Jeanne Tremblay'), findsOneWidget);
      expect(find.text('Appelé(e)'), findsOneWidget);
      expect(find.text('« Rappellera demain »'), findsOneWidget);
      expect(find.text('Aline Parenteau'), findsNothing);
    });

    testWidgets('filtre « Tous »', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.tap(find.text('Tous'));
      await tester.pump();

      expect(find.text('Aline Parenteau'), findsOneWidget);
      expect(find.text('Jeanne Tremblay'), findsOneWidget);
    });

    testWidgets('trois actions sur un avis ouvert, aucune sur un traité',
        (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      expect(find.byTooltip('Appelé(e)'), findsNWidgets(3));
      expect(find.byTooltip('Note laissée'), findsNWidgets(3));
      expect(find.byTooltip('Reporter'), findsNWidgets(3));

      await tester.tap(find.text("Traités aujourd'hui"));
      await tester.pump();

      expect(find.byTooltip('Appelé(e)'), findsNothing);
      expect(find.byTooltip('Note laissée'), findsNothing);
      expect(find.byTooltip('Reporter'), findsNothing);
    });

    testWidgets('recherche par nom et par appartement', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.enterText(find.byType(TextField), 'gagn');
      await tester.pump();
      expect(find.text('Paul Gagnon'), findsOneWidget);
      expect(find.text('Aline Parenteau'), findsNothing);

      await tester.enterText(find.byType(TextField), '303');
      await tester.pump();
      expect(find.text('Marie Roy'), findsOneWidget);
      expect(find.text('Paul Gagnon'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Aucun résultat'), findsOneWidget);
    });

    testWidgets('aucun avis du tout', (tester) async {
      await _afficher(tester, _DepotSimule(const []));
      expect(find.text('Aucun résident à aviser'), findsOneWidget);
    });

    testWidgets('tous les avis sont traités : « Tout le monde est prévenu »',
        (tester) async {
      await _afficher(
        tester,
        _DepotSimule([_avis('1', 'A', 'B', '1', statut: StatutAvis.appele)]),
      );
      expect(find.text('Tout le monde est prévenu'), findsOneWidget);
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

      expect(find.text('Aline Parenteau'), findsOneWidget);
    });

    testWidgets('pagination : 10 avis par page', (tester) async {
      final liste = [
        for (var i = 1; i <= 12; i++) _avis('$i', 'Prénom$i', 'Nom', '${100 + i}'),
      ];
      await _afficher(tester, _DepotSimule(liste));

      expect(find.text('Prénom10 Nom'), findsOneWidget);
      expect(find.text('Prénom11 Nom'), findsNothing);
      expect(find.text('1–10 sur 12'), findsOneWidget);

      await tester.tap(find.byTooltip('Suivant'));
      await tester.pump();
      expect(find.text('Prénom11 Nom'), findsOneWidget);
    });

    testWidgets('sur mobile : cartes avec les mêmes actions', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()),
          taille: const Size(420, 900));

      expect(find.text('RÉSIDENT'), findsNothing);
      expect(find.text('Aline Parenteau'), findsOneWidget);
      expect(find.text('Apt 101 · Préposée absente'), findsOneWidget);
      expect(find.text('En retard'), findsOneWidget);
      expect(find.byTooltip('Appelé(e)'), findsNWidgets(3));
    });

    testWidgets('la liste se rafraîchit chaque minute', (tester) async {
      final depot = _DepotSimule(_jeu());
      await _afficher(tester, depot);
      expect(depot.chargements, 1);

      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      expect(depot.chargements, 2);
    });
  });

  group('Traitement d\'un avis', () {
    Finder champCommentaire() => find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        );

    FilledButton confirmer(WidgetTester tester) => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmer'));

    testWidgets('« Appelé(e) » ouvre la fenêtre avec le message à annoncer',
        (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.tap(find.byTooltip('Appelé(e)').first);
      await tester.pumpAndSettle();

      expect(find.text('Aline Parenteau · Apt 101'), findsOneWidget);
      expect(find.text('À annoncer au résident'), findsOneWidget);
      expect(find.text('La préposée prévue est absente.'), findsOneWidget);
      expect(confirmer(tester).onPressed, isNotNull);
    });

    testWidgets('sans commentaire : envoyé vide, la fenêtre se ferme',
        (tester) async {
      final depot = _DepotSimule(_jeu());
      await _afficher(tester, depot);

      await tester.tap(find.byTooltip('Appelé(e)').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      expect(depot.traitements, hasLength(1));
      expect(depot.traitements.single.avisId, '1');
      expect(depot.traitements.single.auteurId, 'r1');
      expect(depot.traitements.single.action, ActionAvis.appele);
      expect(depot.traitements.single.commentaire, isNull);
      expect(find.text('À annoncer au résident'), findsNothing);
      expect(find.text('Avis enregistré : Appelé(e).'), findsOneWidget);
      expect(depot.chargements, 2, reason: 'la liste est rechargée');
    });

    testWidgets('« Note laissée » avec un commentaire nettoyé', (tester) async {
      final depot = _DepotSimule(_jeu());
      await _afficher(tester, depot);

      await tester.tap(find.byTooltip('Note laissée').at(1));
      await tester.pumpAndSettle();
      await tester.enterText(champCommentaire(), '  Sous la porte  ');
      await tester.pump();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      expect(depot.traitements.single.avisId, '2');
      expect(depot.traitements.single.action, ActionAvis.noteLaissee);
      expect(depot.traitements.single.commentaire, 'Sous la porte');
    });

    testWidgets('« Reporter »', (tester) async {
      final depot = _DepotSimule(_jeu());
      await _afficher(tester, depot);

      await tester.tap(find.byTooltip('Reporter').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      expect(depot.traitements.single.action, ActionAvis.reporter);
    });

    testWidgets('ouvert par la ligne : aucune action, il faut en choisir une',
        (tester) async {
      final depot = _DepotSimule(_jeu());
      await _afficher(tester, depot);

      await tester.tap(find.text('Paul Gagnon'));
      await tester.pumpAndSettle();

      expect(confirmer(tester).onPressed, isNull);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Note laissée'));
      await tester.pump();

      expect(confirmer(tester).onPressed, isNotNull);
    });

    testWidgets('une erreur du serveur s\'affiche, la fenêtre reste ouverte',
        (tester) async {
      final depot = _DepotSimule(_jeu())
        ..erreurTraitement = const ReceptionErreur('Cet avis est déjà traité.');
      await _afficher(tester, depot);

      await tester.tap(find.byTooltip('Appelé(e)').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      expect(find.text('Cet avis est déjà traité.'), findsOneWidget);
      expect(find.text('À annoncer au résident'), findsOneWidget);
      expect(find.textContaining('Avis enregistré'), findsNothing);
    });

    testWidgets('le message à annoncer ne contient aucun motif',
        (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.tap(find.byTooltip('Appelé(e)').first);
      await tester.pumpAndSettle();

      for (final mot in ['Refus', 'vacant', 'motif', 'Motif']) {
        expect(find.textContaining(mot), findsNothing, reason: mot);
      }
    });
  });
}
