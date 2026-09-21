import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cleanops/features/reception/domain/reception_equipe_models.dart';
import 'package:cleanops/features/reception/domain/reception_equipe_repository.dart';
import 'package:cleanops/features/reception/domain/reception_residents_repository.dart'
    show ReceptionErreur;
import 'package:cleanops/features/reception/presentation/providers/reception_equipe_provider.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_equipe_screen.dart';

class _DepotSimule implements ReceptionEquipeRepository {
  EquipeDuJour equipe;
  Object? erreur;
  int chargements = 0;

  _DepotSimule(this.equipe);

  @override
  Future<EquipeDuJour> equipeDuJour() async {
    chargements++;
    if (erreur != null) throw erreur!;
    return equipe;
  }
}

MembreEquipe _membre(
  String prenom,
  String nom,
  PresenceJour presence, {
  PartieJournee? journee,
  String? debut,
  String? fin,
}) =>
    MembreEquipe(
      id: 'id-$prenom',
      prenom: prenom,
      nom: nom,
      presence: presence,
      journee: journee,
      heureDebut: debut,
      heureFin: fin,
    );

EquipeDuJour _equipe() => EquipeDuJour(
      date: DateTime(2026, 9, 21),
      membres: [
        _membre('Essie', 'France', PresenceJour.presente,
            journee: PartieJournee.complete, debut: '08:00', fin: '13:00'),
        _membre('Annise', 'Sylvestre', PresenceJour.presente,
            journee: PartieJournee.complete),
        _membre('Marta', 'Louis', PresenceJour.absente),
        _membre('Naomie', 'Bagalwa', PresenceJour.nonConfirmee),
        _membre('Liliane', 'Sylvestre', PresenceJour.presente,
            journee: PartieJournee.apresMidi),
        _membre('Martine', 'Jean', PresenceJour.presente,
            journee: PartieJournee.matin),
      ],
    );

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
      overrides: [receptionEquipeRepositoryProvider.overrideWithValue(depot)],
      child: const MaterialApp(home: ReceptionEquipeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Rien de ce qui décrit le travail de l'équipe ne doit apparaître : ni tâche,
/// ni compteur, ni progression, ni appartement, ni motif, ni action.
void _verifierAucuneInfoDeTravail() {
  for (final mot in [
    'effectué',
    'Effectué',
    'À faire',
    'Non effectué',
    'ménage',
    'Ménage',
    'Apt',
    'tâche',
    'Tâche',
    '%',
    'motif',
    'Motif',
    'attribution',
  ]) {
    expect(find.textContaining(mot), findsNothing, reason: mot);
  }
  expect(find.byType(FilledButton), findsNothing);
  expect(find.byType(OutlinedButton), findsNothing);
  expect(find.byTooltip("Voir l'horaire du jour"), findsNothing);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('Modèles', () {
    test('analyse du JSON du serveur', () {
      final e = EquipeDuJour.fromJson({
        'date': '2026-09-21',
        'employes': [
          {
            'id': 'e1',
            'prenom': 'Essie',
            'nom': 'France',
            'presence': 'presente',
            'journee': 'complete',
            'heure_debut': '08:00',
            'heure_fin': '13:00',
          },
          {
            'id': 'e2',
            'prenom': 'Marta',
            'nom': 'Louis',
            'presence': 'non_confirmee',
            'journee': null,
            'heure_debut': null,
            'heure_fin': null,
          },
        ],
      });

      expect(e.date, DateTime(2026, 9, 21));
      expect(e.membres, hasLength(2));
      expect(e.membres.first.horaire, '8h00 – 13h00');
      expect(e.membres.last.presence, PresenceJour.nonConfirmee);
      expect(e.membres.last.horaire, isNull);
    });

    test('exactement trois présences : Présente · Absente · Non confirmée', () {
      expect(PresenceJour.values, hasLength(3));
      expect(PresenceJour.fromCode('presente').libelle, 'Présente');
      expect(PresenceJour.fromCode('absente').libelle, 'Absente');
      expect(PresenceJour.fromCode('non_confirmee').libelle, 'Non confirmée');
    });

    test('un code inconnu (dont l\'ancien « non_declaree ») est refusé', () {
      expect(() => PresenceJour.fromCode('non_declaree'), throwsFormatException);
      expect(() => PresenceJour.fromCode('absente_matin'), throwsFormatException);
      expect(() => PartieJournee.fromCode('semaine'), throwsFormatException);
    });

    test('formatage des heures : 8h00 – 13h00', () {
      expect(formaterHeure('08:00'), '8h00');
      expect(formaterHeure('13:00'), '13h00');
      expect(formaterHeure('07:30'), '7h30');
      expect(formaterHeure('16:45:00'), '16h45');
      expect(formaterHeure('bientôt'), 'bientôt');
    });

    group('horaire du jour', () {
      test('heures précisées', () {
        expect(
          _membre('A', 'B', PresenceJour.presente,
                  journee: PartieJournee.complete, debut: '08:00', fin: '13:00')
              .horaire,
          '8h00 – 13h00',
        );
      });

      test('sans heures : toute la journée', () {
        expect(
          _membre('A', 'B', PresenceJour.presente,
                  journee: PartieJournee.complete)
              .horaire,
          'Toute la journée',
        );
      });

      test('absente le matin : elle travaille l\'après-midi seulement', () {
        expect(
          _membre('A', 'B', PresenceJour.presente,
                  journee: PartieJournee.apresMidi)
              .horaire,
          'Après-midi seulement',
        );
      });

      test('absente l\'après-midi : elle travaille le matin seulement', () {
        expect(
          _membre('A', 'B', PresenceJour.presente, journee: PartieJournee.matin)
              .horaire,
          'Matin seulement',
        );
      });

      test('les heures priment sur la partie de journée', () {
        expect(
          _membre('A', 'B', PresenceJour.presente,
                  journee: PartieJournee.apresMidi, debut: '13:00', fin: '17:00')
              .horaire,
          '13h00 – 17h00',
        );
      });

      test('une seule heure ne suffit pas', () {
        expect(
          _membre('A', 'B', PresenceJour.presente,
                  journee: PartieJournee.complete, debut: '08:00')
              .horaire,
          'Toute la journée',
        );
      });

      test('absente ou non confirmée : aucun horaire', () {
        expect(_membre('A', 'B', PresenceJour.absente).horaire, isNull);
        expect(_membre('A', 'B', PresenceJour.nonConfirmee).horaire, isNull);
        expect(
          _membre('A', 'B', PresenceJour.absente, debut: '08:00', fin: '13:00')
              .horaire,
          isNull,
          reason: 'des heures résiduelles ne doivent pas s\'afficher',
        );
      });
    });

    test('rien d\'autre : tâches, compteurs et motifs n\'atteignent jamais '
        'le modèle', () {
      final m = MembreEquipe.fromJson({
        'id': 'e1',
        'prenom': 'Essie',
        'nom': 'France',
        'presence': 'absente',
        'journee': null,
        'heure_debut': null,
        'heure_fin': null,
        // Ce que l'ancienne version renvoyait, ou un motif par erreur :
        'taches': [
          {
            'appartement_id': 'a1',
            'numero': '101',
            'periode': 'AM',
            'etat': 'a_faire',
          },
        ],
        'en_attente': [
          {'numero': '909'},
        ],
        'motif': 'MOTIF-SECRET raison personnelle',
        'motif_absent': 'MOTIF-SECRET',
        'pourcentage': 80,
      });

      expect(m.toString(), isNot(contains('MOTIF-SECRET')));
      expect(m.toString(), isNot(contains('101')));
      expect(m.nomComplet, 'Essie France');
    });
  });

  group('Tableau de l\'équipe', () {
    testWidgets('trois colonnes seulement : nom, présence, horaire du jour',
        (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      for (final t in ['NOM', 'PRÉSENCE', 'HORAIRE DU JOUR']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      for (final t in ['MÉNAGES', 'ACTIONS', 'ÉTAGE', 'APPARTEMENT']) {
        expect(find.text(t), findsNothing, reason: t);
      }
      expect(find.text('Équipe  (6)'), findsOneWidget);
      expect(find.text('Essie France'), findsOneWidget);
    });

    testWidgets('affiche la date du Québec renvoyée par le serveur',
        (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));
      expect(find.text('Aujourd\'hui — Lundi 21 septembre 2026'),
          findsOneWidget);
    });

    testWidgets('présences : Présente · Absente · Non confirmée',
        (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      expect(find.text('Présente'), findsNWidgets(4));
      expect(find.text('Absente'), findsOneWidget);
      expect(find.text('Non confirmée'), findsOneWidget);
    });

    testWidgets('l\'horaire du jour de chaque employé', (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      expect(find.text('8h00 – 13h00'), findsOneWidget);
      expect(find.text('Toute la journée'), findsOneWidget);
      expect(find.text('Après-midi seulement'), findsOneWidget);
      expect(find.text('Matin seulement'), findsOneWidget);
      // Absente et non confirmée : « — », pas d'horaire inventé.
      expect(find.text('—'), findsNWidgets(2));
    });

    testWidgets('AUCUNE information sur le travail de l\'équipe',
        (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      _verifierAucuneInfoDeTravail();
      expect(find.byType(IconButton).evaluate().length, lessThanOrEqualTo(1),
          reason: 'seul « Actualiser » est cliquable');
    });

    testWidgets('toucher une ligne n\'ouvre rien', (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      await tester.tap(find.text('Essie France'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Horaire du jour'), findsNothing);
    });

    testWidgets('filtre Présents', (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      await tester.tap(find.text('Présents'));
      await tester.pump();

      expect(find.text('Essie France'), findsOneWidget);
      expect(find.text('Martine Jean'), findsOneWidget);
      expect(find.text('Marta Louis'), findsNothing);
      expect(find.text('Naomie Bagalwa'), findsNothing);
    });

    testWidgets('filtre Absents', (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      await tester.tap(find.text('Absents'));
      await tester.pump();

      expect(find.text('Marta Louis'), findsOneWidget);
      expect(find.text('Essie France'), findsNothing);
      expect(find.text('Naomie Bagalwa'), findsNothing);
    });

    testWidgets('filtre Non confirmés', (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      await tester.tap(find.text('Non confirmés'));
      await tester.pump();

      expect(find.text('Naomie Bagalwa'), findsOneWidget);
      expect(find.text('Essie France'), findsNothing);
      expect(find.text('Marta Louis'), findsNothing);
    });

    testWidgets('recherche par nom, puis aucun résultat', (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      await tester.enterText(find.byType(TextField), 'sylvest');
      await tester.pump();
      expect(find.text('Annise Sylvestre'), findsOneWidget);
      expect(find.text('Liliane Sylvestre'), findsOneWidget);
      expect(find.text('Essie France'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Aucun résultat'), findsOneWidget);

      await tester.tap(find.text('Effacer les filtres'));
      await tester.pump();
      expect(find.text('Essie France'), findsOneWidget);
    });

    testWidgets('aucun employé actif', (tester) async {
      await _afficher(
        tester,
        _DepotSimule(EquipeDuJour(date: DateTime(2026, 9, 21), membres: const [])),
      );
      expect(find.text('Aucun employé'), findsOneWidget);
    });

    testWidgets('une erreur de chargement propose de réessayer',
        (tester) async {
      final depot = _DepotSimule(_equipe())
        ..erreur = const ReceptionErreur('Réseau indisponible.');
      await _afficher(tester, depot);

      expect(find.text('Réessayer'), findsOneWidget);

      depot.erreur = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(depot.chargements, 2);
      expect(find.text('Essie France'), findsOneWidget);
    });

    testWidgets('« Actualiser » recharge la liste', (tester) async {
      final depot = _DepotSimule(_equipe());
      await _afficher(tester, depot);

      await tester.tap(find.byTooltip('Actualiser'));
      await tester.pumpAndSettle();

      expect(depot.chargements, 2);
    });

    testWidgets('sur mobile : cartes avec présence et horaire',
        (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()),
          taille: const Size(420, 900));

      expect(find.text('NOM'), findsNothing);
      expect(find.text('Essie France'), findsOneWidget);
      expect(find.text('8h00 – 13h00'), findsOneWidget);
      expect(find.text('Non confirmée'), findsOneWidget);
      _verifierAucuneInfoDeTravail();
    });
  });
}
