import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleanops/features/reception/domain/reception_messages_models.dart';
import 'package:cleanops/features/reception/domain/reception_models.dart' show NatureDemande;
import 'package:cleanops/features/reception/domain/reception_messages_repository.dart';
import 'package:cleanops/features/reception/domain/reception_residents_repository.dart'
    show ReceptionErreur;
import 'package:cleanops/features/reception/presentation/providers/reception_messages_provider.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_messages_screen.dart';

class _DepotSimule implements ReceptionMessagesRepository {
  List<MessageTransmis> liste;
  Object? erreur;
  int chargements = 0;

  _DepotSimule(this.liste);

  @override
  Future<List<MessageTransmis>> messages() async {
    chargements++;
    if (erreur != null) throw erreur!;
    return liste;
  }
}

MessageTransmis _msg(
  String id,
  String numero,
  String texte, {
  StatutMessage statut = StatutMessage.enAttente,
  DateTime? creation,
  bool transmis = false,
  NatureDemande nature = NatureDemande.autre,
  String? employe,
  String? reponse,
  DateTime? dateReponse,
  DateTime? dateResolution,
}) =>
    MessageTransmis(
      id: id,
      appartementId: 'a$numero',
      numero: numero,
      message: texte,
      auteurPrenom: 'Receptioniste',
      statut: statut,
      dateCreation: creation ?? DateTime(2026, 9, 21, 9, 5),
      transmisEmploye: transmis,
      nature: nature,
      employePrenom: employe,
      reponse: reponse,
      dateReponse: dateReponse,
      dateResolution: dateResolution,
    );

List<MessageTransmis> _jeu() => [
      _msg('1', '101', 'Fuite dans la salle de bain',
          nature: NatureDemande.annulation,
          creation: DateTime(2026, 9, 21, 14, 30)),
      _msg('2', '202', 'Prévenir avant de passer',
          nature: NatureDemande.reprogrammation,
          statut: StatutMessage.repondue,
          transmis: true,
          employe: 'Essie',
          reponse: 'Bien reçu, nous passons demain.',
          dateReponse: DateTime(2026, 9, 21, 15, 0),
          creation: DateTime(2026, 9, 21, 10, 0)),
      _msg('3', '303', 'Clé perdue',
          statut: StatutMessage.resolue,
          reponse: 'Une clé de remplacement a été remise.',
          dateReponse: DateTime(2026, 9, 20, 11, 0),
          dateResolution: DateTime(2026, 9, 20, 16, 45),
          creation: DateTime(2026, 9, 20, 9, 0)),
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
      overrides: [receptionMessagesRepositoryProvider.overrideWithValue(depot)],
      child: const MaterialApp(home: ReceptionMessagesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Modèles', () {
    test('analyse du JSON du serveur', () {
      final m = MessageTransmis.fromJson({
        'id': 'x1',
        'appartement_id': 'a1',
        'numero': '101',
        'message': 'Bonjour',
        'auteur_prenom': 'Receptioniste',
        'transmis_employe': true,
        'employe_prenom': 'Essie',
        'statut': 'Resolue',
        'reponse': 'Fait.',
        'date_creation': '2026-09-21T14:30:00',
        'date_reponse': '2026-09-21T15:00:00',
        'date_resolution': '2026-09-21T16:00:00',
      });

      expect(m.numero, '101');
      expect(m.transmisEmploye, isTrue);
      expect(m.employePrenom, 'Essie');
      expect(m.statut, StatutMessage.resolue);
      expect(m.envoyeLe, '21/09/2026 14:30');
      expect(m.dateReponse, DateTime(2026, 9, 21, 15, 0));
      expect(m.dateResolution, DateTime(2026, 9, 21, 16, 0));
    });

    test('un message sans réponse ni résolution', () {
      final m = MessageTransmis.fromJson({
        'id': 'x1',
        'appartement_id': 'a1',
        'numero': '101',
        'message': 'Bonjour',
        'auteur_prenom': 'R',
        'transmis_employe': false,
        'employe_prenom': null,
        'statut': 'EnAttente',
        'reponse': null,
        'date_creation': '2026-09-21T09:05:00',
        'date_reponse': null,
        'date_resolution': null,
      });

      expect(m.reponse, isNull);
      expect(m.dateReponse, isNull);
      expect(m.dateResolution, isNull);
      expect(m.transmisEmploye, isFalse);
    });

    test('exactement trois statuts : En attente · Répondue · Résolue', () {
      expect(StatutMessage.values, hasLength(3));
      expect(StatutMessage.fromCode('EnAttente').libelle, 'En attente');
      expect(StatutMessage.fromCode('Repondue').libelle, 'Répondue');
      expect(StatutMessage.fromCode('Resolue').libelle, 'Résolue');
      expect(
        StatutMessage.values.map((s) => s.libelle).join(' '),
        isNot(contains('Trait')),
        reason: 'le statut « Traitée » est abandonné',
      );
    });

    test('ce que chaque statut signifie pour la Réception', () {
      expect(StatutMessage.enAttente.signification,
          "Personne n'a encore traité cette demande.");
      expect(StatutMessage.repondue.signification,
          "Une réponse a été donnée, mais l'horaire n'a pas changé.");
      expect(StatutMessage.resolue.signification, "L'horaire a été modifié.");
    });

    test('la nature de la demande vient du serveur', () {
      MessageTransmis avec(Object? nature) => MessageTransmis.fromJson({
            'id': 'x',
            'appartement_id': 'a',
            'numero': '1',
            'nature': nature,
            'message': 'm',
            'statut': 'EnAttente',
            'date_creation': '2026-09-21T09:05:00',
          });

      expect(avec('Annulation').nature, NatureDemande.annulation);
      expect(avec('Reprogrammation').nature, NatureDemande.reprogrammation);
      expect(avec('Autre').nature, NatureDemande.autre);
      expect(avec(null).nature, NatureDemande.autre,
          reason: 'les messages d\'avant la nature valent « Autre »');
      expect(() => avec('Inconnue'), throwsFormatException);
    });

    test('valeurs envoyées au serveur pour la nature', () {
      expect(NatureDemande.annulation.code, 'Annulation');
      expect(NatureDemande.reprogrammation.code, 'Reprogrammation');
      expect(NatureDemande.autre.code, 'Autre');
      expect(NatureDemande.autre.libelle, 'Autre demande');
    });

    test('un statut inconnu (dont « Traitee ») est refusé', () {
      expect(() => StatutMessage.fromCode('Traitee'), throwsFormatException);
    });
  });

  group('Tableau des messages transmis', () {
    testWidgets('s\'ouvre directement sur le tableau', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      for (final t in ['APPARTEMENT', 'NATURE', 'MESSAGE', 'ENVOYÉ', 'STATUT', 'ACTIONS']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Messages transmis  (3)'), findsOneWidget);
      expect(find.text('Apt 101'), findsOneWidget);
      expect(find.text('Fuite dans la salle de bain'), findsOneWidget);
      expect(find.text('21/09/2026 14:30'), findsOneWidget);
    });

    testWidgets('la nature de chaque demande s\'affiche', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      expect(find.text('Annulation'), findsOneWidget);
      expect(find.text('Reprogrammation'), findsOneWidget);
      expect(find.text('Autre demande'), findsOneWidget);
    });

    testWidgets('les trois statuts s\'affichent', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      expect(find.text('En attente'), findsWidgets);
      expect(find.text('Répondue'), findsOneWidget);
      expect(find.text('Résolue'), findsOneWidget);
    });

    testWidgets('aucun libellé « Traitée » nulle part', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      expect(find.textContaining('Trait'), findsNothing);

      await tester.tap(find.text('Répondus'));
      await tester.pump();
      expect(find.textContaining('Trait'), findsNothing);
    });

    testWidgets('lecture seule : aucune action de modification', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      expect(find.byTooltip('Voir le message'), findsNWidgets(3));
      for (final t in ['Répondre', 'Résoudre', 'Supprimer', 'Modifier']) {
        expect(find.byTooltip(t), findsNothing, reason: t);
        expect(find.text(t), findsNothing, reason: t);
      }
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('filtres par statut', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.tap(find.text('En attente').first);
      await tester.pump();
      expect(find.text('Fuite dans la salle de bain'), findsOneWidget);
      expect(find.text('Clé perdue'), findsNothing);

      await tester.tap(find.text('Répondus'));
      await tester.pump();
      expect(find.text('Prévenir avant de passer'), findsOneWidget);
      expect(find.text('Fuite dans la salle de bain'), findsNothing);

      await tester.tap(find.text('Résolus'));
      await tester.pump();
      expect(find.text('Clé perdue'), findsOneWidget);
      expect(find.text('Prévenir avant de passer'), findsNothing);

      await tester.tap(find.text('Tous'));
      await tester.pump();
      expect(find.text('Fuite dans la salle de bain'), findsOneWidget);
      expect(find.text('Clé perdue'), findsOneWidget);
    });

    testWidgets('recherche par appartement et par texte', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.enterText(find.byType(TextField), '303');
      await tester.pump();
      expect(find.text('Clé perdue'), findsOneWidget);
      expect(find.text('Fuite dans la salle de bain'), findsNothing);

      await tester.enterText(find.byType(TextField), 'fuite');
      await tester.pump();
      expect(find.text('Fuite dans la salle de bain'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Aucun résultat'), findsOneWidget);

      await tester.tap(find.text('Effacer les filtres'));
      await tester.pump();
      expect(find.text('Clé perdue'), findsOneWidget);
    });

    testWidgets('aucun message', (tester) async {
      await _afficher(tester, _DepotSimule(const []));
      expect(find.text('Aucun message transmis'), findsOneWidget);
    });

    testWidgets('une erreur de chargement propose de réessayer',
        (tester) async {
      final depot = _DepotSimule(_jeu())
        ..erreur = const ReceptionErreur('Réseau indisponible.');
      await _afficher(tester, depot);

      expect(find.text('Réessayer'), findsOneWidget);

      depot.erreur = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Clé perdue'), findsOneWidget);
    });

    testWidgets('« Actualiser » recharge la liste', (tester) async {
      final depot = _DepotSimule(_jeu());
      await _afficher(tester, depot);
      expect(depot.chargements, 1);

      await tester.tap(find.byTooltip('Actualiser'));
      await tester.pumpAndSettle();

      expect(depot.chargements, 2);
    });

    testWidgets('pagination : 10 messages par page', (tester) async {
      final liste = [
        for (var i = 1; i <= 12; i++) _msg('$i', '${100 + i}', 'Message numéro $i'),
      ];
      await _afficher(tester, _DepotSimule(liste));

      expect(find.text('Message numéro 10'), findsOneWidget);
      expect(find.text('Message numéro 11'), findsNothing);
      expect(find.text('1–10 sur 12'), findsOneWidget);
    });

    testWidgets('sur mobile : cartes', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()),
          taille: const Size(420, 900));

      expect(find.text('APPARTEMENT'), findsNothing);
      expect(find.text('Apt 101 · Annulation'), findsOneWidget);
      expect(find.text('Fuite dans la salle de bain'), findsOneWidget);
      expect(find.byTooltip('Voir le message'), findsNWidgets(3));
    });
  });

  group('Détail d\'un message', () {
    testWidgets('en attente : aucune réponse', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.tap(find.byTooltip('Voir le message').at(0));
      await tester.pumpAndSettle();

      expect(find.text('Message · Apt 101'), findsOneWidget);
      expect(find.text('Envoyé le 21/09/2026 14:30 par Receptioniste'),
          findsOneWidget);
      expect(find.text('Votre message'), findsOneWidget);
      expect(find.text('Nature : Annulation'), findsOneWidget);
      expect(find.text("Personne n'a encore traité cette demande."),
          findsOneWidget);
      expect(find.text('Réponse'), findsNothing);
    });

    testWidgets('répondue : la réponse et l\'employé destinataire',
        (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.tap(find.byTooltip('Voir le message').at(1));
      await tester.pumpAndSettle();

      expect(find.text("Transmis aussi à l'employé : Essie."), findsOneWidget);
      expect(find.text('Nature : Reprogrammation'), findsOneWidget);
      expect(
        find.text("Une réponse a été donnée, mais l'horaire n'a pas changé."),
        findsOneWidget,
      );
      expect(find.text('Réponse · 21/09/2026 15:00'), findsOneWidget);
      expect(find.text('Bien reçu, nous passons demain.'), findsOneWidget);
      expect(find.textContaining('Résolue le'), findsNothing);
    });

    testWidgets('résolue : la date de résolution', (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.tap(find.byTooltip('Voir le message').at(2));
      await tester.pumpAndSettle();

      expect(find.text('Une clé de remplacement a été remise.'),
          findsOneWidget);
      expect(find.text('Résolue le 20/09/2026 16:45.'), findsOneWidget);
      expect(find.text("L'horaire a été modifié."), findsOneWidget);
      expect(find.text('Nature : Autre demande'), findsOneWidget);
    });

    testWidgets('un message non transmis à l\'employé ne le mentionne pas',
        (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.tap(find.byTooltip('Voir le message').at(0));
      await tester.pumpAndSettle();

      expect(find.textContaining("Transmis aussi à l'employé"), findsNothing);
    });

    testWidgets('toucher la ligne ouvre aussi le détail, puis se ferme',
        (tester) async {
      await _afficher(tester, _DepotSimule(_jeu()));

      await tester.tap(find.text('Clé perdue'));
      await tester.pumpAndSettle();
      expect(find.text('Message · Apt 303'), findsOneWidget);

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.text('Message · Apt 303'), findsNothing);
    });
  });
}
