import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleanops/core/errors/failures.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';
import 'package:cleanops/features/messages_reception_responsable/domain/messages_reception_responsable_repository.dart';
import 'package:cleanops/features/messages_reception_responsable/presentation/providers/messages_reception_responsable_provider.dart';
import 'package:cleanops/features/messages_reception_responsable/presentation/widgets/messages_reception_section.dart';
import 'package:cleanops/features/reception/domain/reception_messages_models.dart';
import 'package:cleanops/features/reception/domain/reception_models.dart'
    show NatureDemande;
import 'package:cleanops/features/reception/domain/reception_residents_repository.dart'
    show ReceptionErreur;
import 'package:cleanops/features/resident_espace/domain/entities/demande_resident.dart';
import 'package:cleanops/features/resident_espace/domain/repositories/resident_espace_repository.dart';
import 'package:cleanops/features/resident_espace/presentation/providers/resident_espace_provider.dart';
import 'package:cleanops/features/resident_espace/presentation/screens/demandes_residents_responsable_screen.dart';

const _admin = Employee(
  id: 'a1',
  nom: 'Sylvestre',
  prenom: 'Nadine',
  slug: 'nadine',
  role: RoleType.admin,
  isActif: true,
);

class _DepotMessages implements MessagesReceptionResponsableRepository {
  List<MessageTransmis> liste;
  Object? erreurListe;
  Object? erreurAction;
  int chargements = 0;
  final reponses = <({String messageId, String auteurId, String reponse})>[];
  final resolutions = <({String messageId, String auteurId})>[];

  _DepotMessages(this.liste);

  void _maj(String id, MessageTransmis Function(MessageTransmis) f) {
    liste = [for (final m in liste) m.id == id ? f(m) : m];
  }

  @override
  Future<List<MessageTransmis>> messages() async {
    chargements++;
    if (erreurListe != null) throw erreurListe!;
    return List.of(liste);
  }

  @override
  Future<void> repondre({
    required String messageId,
    required String auteurId,
    required String reponse,
  }) async {
    if (erreurAction != null) throw erreurAction!;
    reponses.add((messageId: messageId, auteurId: auteurId, reponse: reponse));
    _maj(
      messageId,
      (m) => _msg(m.id, m.numero, m.message,
          statut: StatutMessage.repondue,
          nature: m.nature,
          reponse: reponse,
          dateReponse: DateTime(2026, 9, 21, 16, 0)),
    );
  }

  @override
  Future<void> resoudre({
    required String messageId,
    required String auteurId,
  }) async {
    if (erreurAction != null) throw erreurAction!;
    resolutions.add((messageId: messageId, auteurId: auteurId));
    _maj(
      messageId,
      (m) => _msg(m.id, m.numero, m.message,
          statut: StatutMessage.resolue,
          nature: m.nature,
          reponse: m.reponse,
          dateReponse: m.dateReponse,
          dateResolution: DateTime(2026, 9, 21, 17, 30)),
    );
  }
}

MessageTransmis _msg(
  String id,
  String numero,
  String texte, {
  StatutMessage statut = StatutMessage.enAttente,
  NatureDemande nature = NatureDemande.autre,
  DateTime? creation,
  bool transmis = false,
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
      nature: nature,
      dateCreation: creation ?? DateTime(2026, 9, 21, 9, 5),
      transmisEmploye: transmis,
      employePrenom: employe,
      reponse: reponse,
      dateReponse: dateReponse,
      dateResolution: dateResolution,
    );

List<MessageTransmis> _jeu() => [
      _msg('1', '101', 'Annuler le ménage de jeudi',
          nature: NatureDemande.annulation,
          creation: DateTime(2026, 9, 21, 14, 30),
          transmis: true,
          employe: 'Essie'),
      _msg('2', '202', 'Repousser à l\'après-midi',
          nature: NatureDemande.reprogrammation,
          statut: StatutMessage.repondue,
          reponse: 'Bien reçu, je vérifie le planning.',
          dateReponse: DateTime(2026, 9, 21, 15, 0),
          creation: DateTime(2026, 9, 21, 10, 0)),
      _msg('3', '303', 'Clé perdue',
          statut: StatutMessage.resolue,
          reponse: 'Clé remise.',
          dateReponse: DateTime(2026, 9, 20, 11, 0),
          dateResolution: DateTime(2026, 9, 20, 16, 45),
          creation: DateTime(2026, 9, 20, 9, 0)),
    ];

Future<void> _afficherSection(
  WidgetTester tester,
  _DepotMessages depot, {
  Size taille = const Size(420, 1600),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = taille;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        employeeCourantProvider.overrideWithValue(_admin),
        messagesReceptionResponsableRepositoryProvider.overrideWithValue(depot),
      ],
      child: const MaterialApp(
        home: Scaffold(body: MessagesReceptionSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _champReponse() =>
    find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));

void main() {
  group('Section « Messages de la réception »', () {
    testWidgets('triée par statut : en attente, répondues puis résolues',
        (tester) async {
      await _afficherSection(tester, _DepotMessages(_jeu()));

      expect(find.text('MESSAGES (3)'), findsOneWidget);
      expect(find.text('En attente'), findsOneWidget);
      expect(find.text('Répondue'), findsOneWidget);
      expect(find.text('Résolue'), findsOneWidget);

      double haut(String texte) => tester.getTopLeft(find.text(texte)).dy;
      expect(haut('Annuler le ménage de jeudi'),
          lessThan(haut("Repousser à l'après-midi")));
      expect(haut("Repousser à l'après-midi"), lessThan(haut('Clé perdue')));
    });

    testWidgets('chaque carte : appartement, nature, message, auteur, date',
        (tester) async {
      await _afficherSection(tester, _DepotMessages(_jeu()));

      expect(find.text('Apt 101 · Annulation'), findsOneWidget);
      expect(find.text('Apt 202 · Reprogrammation'), findsOneWidget);
      expect(find.text('Apt 303 · Autre demande'), findsOneWidget);
      expect(find.text('Annuler le ménage de jeudi'), findsOneWidget);
      expect(find.text('Envoyé le 21/09/2026 14:30 par Receptioniste'),
          findsOneWidget);
    });

    testWidgets('l\'employé prévenu s\'affiche seulement s\'il l\'a été',
        (tester) async {
      await _afficherSection(tester, _DepotMessages(_jeu()));

      expect(find.text("Transmis aussi à l'employé : Essie."), findsOneWidget);
      expect(find.textContaining("Transmis aussi à l'employé"), findsOneWidget);
    });

    testWidgets('la réponse donnée et la résolution s\'affichent',
        (tester) async {
      await _afficherSection(tester, _DepotMessages(_jeu()));

      expect(find.text('Votre réponse · 21/09/2026 15:00'), findsOneWidget);
      expect(find.text('Bien reçu, je vérifie le planning.'), findsOneWidget);
      expect(
        find.text("Résolue le 20/09/2026 16:45 : l'horaire a été modifié."),
        findsOneWidget,
      );
    });

    testWidgets('actions selon le statut', (tester) async {
      await _afficherSection(tester, _DepotMessages(_jeu()));

      // En attente : Répondre + Horaire modifié.
      expect(find.text('Répondre'), findsOneWidget);
      // Répondue : Modifier la réponse + Horaire modifié.
      expect(find.text('Modifier la réponse'), findsOneWidget);
      // Résolue : aucune action → 2 « Horaire modifié » pour 3 messages.
      expect(find.text('Horaire modifié'), findsNWidgets(2));
    });

    testWidgets('aucun libellé « Traitée » nulle part', (tester) async {
      await _afficherSection(tester, _DepotMessages(_jeu()));
      expect(find.textContaining('Trait'), findsNothing);
    });

    testWidgets('filtres par statut', (tester) async {
      await _afficherSection(tester, _DepotMessages(_jeu()));

      await tester.tap(find.byTooltip('En attente'));
      await tester.pump();
      expect(find.text('Annuler le ménage de jeudi'), findsOneWidget);
      expect(find.text('Clé perdue'), findsNothing);
      expect(find.text('MESSAGES (1)'), findsOneWidget);

      await tester.tap(find.byTooltip('Résolues'));
      await tester.pump();
      expect(find.text('Clé perdue'), findsOneWidget);
      expect(find.text('Annuler le ménage de jeudi'), findsNothing);

      await tester.tap(find.byTooltip('Répondues'));
      await tester.pump();
      expect(find.text('Repousser à l\'après-midi'), findsOneWidget);

      await tester.tap(find.byTooltip('Tous les messages'));
      await tester.pump();
      expect(find.text('MESSAGES (3)'), findsOneWidget);
    });

    testWidgets('un filtre sans résultat propose de tout afficher',
        (tester) async {
      final depot = _DepotMessages([_msg('1', '101', 'Un seul message')]);
      await _afficherSection(tester, depot);

      await tester.tap(find.byTooltip('Résolues'));
      await tester.pump();
      expect(
          find.text('Aucun message ne correspond à ce filtre'), findsOneWidget);

      await tester.tap(find.text('Tout afficher'));
      await tester.pump();
      expect(find.text('Un seul message'), findsOneWidget);
    });

    testWidgets('aucun message', (tester) async {
      await _afficherSection(tester, _DepotMessages(const []));
      expect(find.text('Aucun message de la réception'), findsOneWidget);
    });

    testWidgets('une erreur de chargement propose de réessayer',
        (tester) async {
      final depot = _DepotMessages(_jeu())
        ..erreurListe = const ReceptionErreur('Réseau indisponible.');
      await _afficherSection(tester, depot);

      expect(find.text('Réessayer'), findsOneWidget);

      depot.erreurListe = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Clé perdue'), findsOneWidget);
    });

    testWidgets('sur ordinateur : tableau avec actions en icônes',
        (tester) async {
      await _afficherSection(tester, _DepotMessages(_jeu()),
          taille: const Size(1400, 1200));

      expect(find.text('Annuler le ménage de jeudi'), findsOneWidget);
      expect(find.byTooltip('Répondre'), findsOneWidget);
      expect(find.byTooltip('Modifier la réponse'), findsOneWidget);
      expect(find.byTooltip('Horaire modifié'), findsNWidgets(2));
    });

    testWidgets('toucher un message ouvre son détail', (tester) async {
      await _afficherSection(tester, _DepotMessages(_jeu()));

      await tester.tap(find.text('Clé perdue'));
      await tester.pumpAndSettle();

      expect(find.text('MESSAGE DE LA RÉCEPTION'), findsOneWidget);
      expect(find.text("L'horaire a été modifié."), findsOneWidget);
    });
  });

  group("« Horaire modifié » seulement pour les demandes d'horaire", () {
    testWidgets('annulation et reprogrammation : le bouton est proposé',
        (tester) async {
      await _afficherSection(
          tester,
          _DepotMessages([
            _msg('1', '101', 'Annuler jeudi', nature: NatureDemande.annulation),
            _msg('2', '202', 'Repousser',
                nature: NatureDemande.reprogrammation),
          ]));

      expect(find.text('Horaire modifié'), findsNWidgets(2));
    });

    testWidgets('« Autre demande » : pas de bouton, seulement Répondre',
        (tester) async {
      await _afficherSection(
          tester,
          _DepotMessages([
            _msg('1', '101', 'Clé perdue', nature: NatureDemande.autre),
          ]));

      expect(find.text('Répondre'), findsOneWidget);
      expect(find.text('Horaire modifié'), findsNothing);
    });

    testWidgets(
        "un message « Autre » déjà répondu : seulement modifier la réponse",
        (tester) async {
      await _afficherSection(
          tester,
          _DepotMessages([
            _msg('1', '101', 'Clé perdue',
                nature: NatureDemande.autre,
                statut: StatutMessage.repondue,
                reponse: 'Nous cherchons.'),
          ]));

      expect(find.text('Modifier la réponse'), findsOneWidget);
      expect(find.text('Horaire modifié'), findsNothing);
    });

    testWidgets("le bouton n'apparaît que sur les cartes concernées",
        (tester) async {
      await _afficherSection(
          tester,
          _DepotMessages([
            _msg('1', '101', 'Annuler jeudi', nature: NatureDemande.annulation),
            _msg('2', '202', 'Clé perdue', nature: NatureDemande.autre),
            _msg('3', '303', 'Question', nature: NatureDemande.autre),
          ]));

      expect(find.text('Répondre'), findsNWidgets(3));
      expect(find.text('Horaire modifié'), findsOneWidget,
          reason: "une seule demande sur trois concerne l'horaire");
    });

    testWidgets("la fenêtre de réponse ne parle pas d'horaire pour « Autre »",
        (tester) async {
      await _afficherSection(
          tester,
          _DepotMessages([
            _msg('1', '101', 'Clé perdue', nature: NatureDemande.autre),
          ]));

      await tester.tap(find.text('Répondre'));
      await tester.pumpAndSettle();

      expect(find.textContaining('La Réception verra cette réponse'),
          findsOneWidget);
      expect(find.textContaining('Horaire modifié'), findsNothing);
      expect(find.textContaining("l'horaire n'a pas changé"), findsNothing);
    });

    testWidgets("la fenêtre de réponse d'une annulation explique la suite",
        (tester) async {
      await _afficherSection(
          tester,
          _DepotMessages([
            _msg('1', '101', 'Annuler', nature: NatureDemande.annulation),
          ]));

      await tester.tap(find.text('Répondre'));
      await tester.pumpAndSettle();

      expect(find.textContaining("l'horaire n'a pas changé"), findsOneWidget);
      expect(find.textContaining('Horaire modifié'), findsWidgets);
    });
  });

  group('Répondre', () {
    testWidgets('« Envoyer la réponse » exige un texte', (tester) async {
      await _afficherSection(tester, _DepotMessages(_jeu()));

      await tester.tap(find.text('Répondre'));
      await tester.pumpAndSettle();

      FilledButton envoyer() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Envoyer la réponse'));
      expect(envoyer().onPressed, isNull);

      await tester.enterText(_champReponse(), '   ');
      await tester.pump();
      expect(envoyer().onPressed, isNull);

      await tester.enterText(_champReponse(), 'Fait.');
      await tester.pump();
      expect(envoyer().onPressed, isNotNull);
    });

    testWidgets('la réponse part, la fenêtre se ferme, la liste se met à jour',
        (tester) async {
      final depot = _DepotMessages(_jeu());
      await _afficherSection(tester, depot);
      final avant = depot.chargements;

      await tester.tap(find.text('Répondre'));
      await tester.pumpAndSettle();
      await tester.enterText(_champReponse(), '  Nous passons demain  ');
      await tester.pump();
      await tester.tap(find.text('Envoyer la réponse'));
      await tester.pumpAndSettle();

      expect(depot.reponses, hasLength(1));
      expect(depot.reponses.single.messageId, '1');
      expect(depot.reponses.single.auteurId, 'a1');
      expect(depot.reponses.single.reponse, 'Nous passons demain');
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Réponse enregistrée.'), findsOneWidget);
      expect(depot.chargements, greaterThan(avant));
      expect(find.text('Répondue'), findsNWidgets(2));
      expect(find.text('Nous passons demain'), findsOneWidget);
    });

    testWidgets('la fenêtre rappelle que l\'horaire n\'a pas changé',
        (tester) async {
      await _afficherSection(tester, _DepotMessages(_jeu()));

      await tester.tap(find.text('Répondre'));
      await tester.pumpAndSettle();

      expect(find.textContaining("l'horaire n'a pas changé"), findsOneWidget);
      expect(find.textContaining('La Réception verra cette réponse'),
          findsOneWidget);
    });

    testWidgets('modifier une réponse : le texte est prérempli',
        (tester) async {
      final depot = _DepotMessages(_jeu());
      await _afficherSection(tester, depot);

      await tester.tap(find.text('Modifier la réponse'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Bien reçu, je vérifie le planning.'),
        ),
        findsOneWidget,
        reason: 'la réponse existante est préremplie dans la fenêtre',
      );
      await tester.enterText(_champReponse(), 'Reporté à mardi.');
      await tester.pump();
      await tester.tap(find.text('Envoyer la réponse'));
      await tester.pumpAndSettle();

      expect(depot.reponses.single.messageId, '2');
      expect(depot.reponses.single.reponse, 'Reporté à mardi.');
    });

    testWidgets('annuler n\'envoie rien', (tester) async {
      final depot = _DepotMessages(_jeu());
      await _afficherSection(tester, depot);

      await tester.tap(find.text('Répondre'));
      await tester.pumpAndSettle();
      await tester.enterText(_champReponse(), 'Brouillon');
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(depot.reponses, isEmpty);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('une erreur du serveur s\'affiche, la fenêtre reste',
        (tester) async {
      final depot = _DepotMessages(_jeu())
        ..erreurAction = const ReceptionErreur('Ce message est déjà résolu.');
      await _afficherSection(tester, depot);

      await tester.tap(find.text('Répondre'));
      await tester.pumpAndSettle();
      await tester.enterText(_champReponse(), 'Fait.');
      await tester.pump();
      await tester.tap(find.text('Envoyer la réponse'));
      await tester.pumpAndSettle();

      expect(find.text('Ce message est déjà résolu.'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Réponse enregistrée.'), findsNothing);
    });
  });

  group('Horaire modifié (Résolue)', () {
    testWidgets('confirmation qui précise que le planning n\'est pas modifié',
        (tester) async {
      final depot = _DepotMessages(_jeu());
      await _afficherSection(tester, depot);

      await tester.tap(find.text('Horaire modifié').first);
      await tester.pumpAndSettle();

      expect(find.text('HORAIRE MODIFIÉ ?'), findsOneWidget);
      expect(find.text('Apt 101 · Annulation'), findsWidgets);
      expect(
          find.text(
              'Cette action ne modifie pas le planning : faites-le avant.'),
          findsOneWidget);
      expect(depot.resolutions, isEmpty, reason: 'rien avant la confirmation');
    });

    testWidgets('confirmer : le message devient résolu', (tester) async {
      final depot = _DepotMessages(_jeu());
      await _afficherSection(tester, depot);

      await tester.tap(find.text('Horaire modifié').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      expect(depot.resolutions, hasLength(1));
      expect(depot.resolutions.single.messageId, '1');
      expect(depot.resolutions.single.auteurId, 'a1');
      expect(find.text('Message marqué comme résolu.'), findsOneWidget);
      expect(find.text('Résolue'), findsNWidgets(2));
      expect(find.text('En attente'), findsNothing,
          reason: 'plus rien en attente');
    });

    testWidgets('annuler : rien n\'est résolu', (tester) async {
      final depot = _DepotMessages(_jeu());
      await _afficherSection(tester, depot);

      await tester.tap(find.text('Horaire modifié').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(depot.resolutions, isEmpty);
      expect(find.text('En attente'), findsOneWidget);
    });

    testWidgets('on peut résoudre un message déjà répondu', (tester) async {
      final depot = _DepotMessages(_jeu());
      await _afficherSection(tester, depot);

      await tester.tap(find.text('Horaire modifié').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      expect(depot.resolutions.single.messageId, '2');
    });

    testWidgets('une erreur du serveur s\'affiche', (tester) async {
      final depot = _DepotMessages(_jeu())
        ..erreurAction = const ReceptionErreur('Ce message est déjà résolu.');
      await _afficherSection(tester, depot);

      await tester.tap(find.text('Horaire modifié').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      expect(find.text('Ce message est déjà résolu.'), findsOneWidget);
      expect(find.text('Message marqué comme résolu.'), findsNothing);
    });
  });

  group('Compteur « En attente »', () {
    test('ne compte que les messages en attente', () async {
      final container = ProviderContainer(overrides: [
        messagesReceptionResponsableRepositoryProvider
            .overrideWithValue(_DepotMessages(_jeu())),
      ]);
      addTearDown(container.dispose);

      expect(container.read(messagesReceptionEnAttenteProvider), 0,
          reason: '0 tant que la liste n\'est pas chargée');

      final sub =
          container.listen(messagesReceptionResponsableProvider, (_, __) {});
      await container.read(messagesReceptionResponsableProvider.future);

      expect(container.read(messagesReceptionEnAttenteProvider), 1);
      sub.close();
    });
  });

  group('Dans l\'écran « Demandes résidents »', () {
    Future<({_DepotMessages depot, _DepotResidents residents})> ecran(
      WidgetTester tester, {
      List<MessageTransmis>? messages,
      Size taille = const Size(1200, 1600),
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = taille;
      addTearDown(tester.view.reset);

      final depot = _DepotMessages(messages ?? _jeu());
      final residents = _DepotResidents();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeeCourantProvider.overrideWithValue(_admin),
            messagesReceptionResponsableRepositoryProvider
                .overrideWithValue(depot),
            residentEspaceRepositoryProvider.overrideWithValue(residents),
          ],
          child: const MaterialApp(home: DemandesResidentsResponsableScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return (depot: depot, residents: residents);
    }

    testWidgets('deux onglets, les demandes des résidents d\'abord',
        (tester) async {
      await ecran(tester);

      expect(find.text('Demandes résidents'), findsOneWidget);
      expect(find.text('Demandes des résidents'), findsOneWidget);
      expect(find.text('Messages de la réception'), findsOneWidget);
      // Onglet des demandes de résidents (vide dans ce test).
      expect(find.text('Aucune demande de résident'), findsOneWidget);
      expect(find.text('Annuler le ménage de jeudi'), findsNothing);
    });

    testWidgets('le compteur de l\'onglet montre les messages en attente',
        (tester) async {
      await ecran(tester);

      final onglet = find.widgetWithText(InkWell, 'Messages de la réception');
      expect(find.descendant(of: onglet, matching: find.text('1')),
          findsOneWidget);
      // L'onglet des demandes de résidents n'a pas de compteur de messages.
      final autre = find.widgetWithText(InkWell, 'Demandes des résidents');
      expect(
          find.descendant(of: autre, matching: find.text('1')), findsNothing);
    });

    testWidgets('pas de compteur quand rien n\'est en attente', (tester) async {
      await ecran(tester, messages: [
        _msg('3', '303', 'Clé perdue', statut: StatutMessage.resolue),
      ]);

      final onglet = find.widgetWithText(InkWell, 'Messages de la réception');
      expect(onglet, findsOneWidget);
      // Rien en attente : l'onglet n'a que son libellé, sans pastille.
      expect(find.descendant(of: onglet, matching: find.byType(Text)),
          findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('l\'onglet des messages affiche la section', (tester) async {
      await ecran(tester);

      await tester.tap(find.text('Messages de la réception'));
      await tester.pumpAndSettle();

      expect(find.text('Annuler le ménage de jeudi'), findsOneWidget);
      expect(find.text('En attente'), findsOneWidget);
      expect(find.text('Aucune demande de résident'), findsNothing,
          reason: 'le contenu des demandes de résidents disparaît');
    });

    testWidgets('revenir aux demandes des résidents', (tester) async {
      await ecran(tester);

      await tester.tap(find.text('Messages de la réception'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demandes des résidents'));
      await tester.pumpAndSettle();

      expect(find.text('Aucune demande de résident'), findsOneWidget);
      expect(find.text('Annuler le ménage de jeudi'), findsNothing);
    });

    testWidgets('« Actualiser » recharge la liste de l\'onglet affiché',
        (tester) async {
      final ctx = await ecran(tester);
      final messagesAvant = ctx.depot.chargements;
      final residentsAvant = ctx.residents.chargements;

      await tester.tap(find.text('Messages de la réception'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Actualiser'));
      await tester.pumpAndSettle();

      expect(ctx.depot.chargements, greaterThan(messagesAvant));
      expect(ctx.residents.chargements, residentsAvant,
          reason: 'les demandes de résidents ne sont pas rechargées');
    });

    testWidgets(
        'sur l\'onglet des demandes, « Actualiser » recharge les '
        'demandes de résidents', (tester) async {
      final ctx = await ecran(tester);
      final residentsAvant = ctx.residents.chargements;

      await tester.tap(find.byTooltip('Actualiser'));
      await tester.pumpAndSettle();

      expect(ctx.residents.chargements, greaterThan(residentsAvant));
    });

    testWidgets('répondre depuis l\'écran complet', (tester) async {
      final ctx = await ecran(tester);

      await tester.tap(find.text('Messages de la réception'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Répondre'));
      await tester.pumpAndSettle();
      await tester.enterText(_champReponse(), 'Vu.');
      await tester.pump();
      await tester.tap(find.text('Envoyer la réponse'));
      await tester.pumpAndSettle();

      expect(ctx.depot.reponses.single.reponse, 'Vu.');
    });

    testWidgets('ouvert directement sur les messages (depuis une notification)',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 1600);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeeCourantProvider.overrideWithValue(_admin),
            messagesReceptionResponsableRepositoryProvider
                .overrideWithValue(_DepotMessages(_jeu())),
            residentEspaceRepositoryProvider
                .overrideWithValue(_DepotResidents()),
          ],
          child: const MaterialApp(
            home: DemandesResidentsResponsableScreen(ouvrirMessages: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Annuler le ménage de jeudi'), findsOneWidget);
      expect(find.text('Aucune demande de résident'), findsNothing);
    });

    testWidgets('sur mobile', (tester) async {
      await ecran(tester, taille: const Size(420, 1200));

      expect(find.text('Demandes des résidents'), findsOneWidget);
      expect(find.text('Messages de la réception'), findsOneWidget);
    });
  });
}

/// Dépôt de l'espace résident : seul `getAllDemandes` est utilisé par l'écran.
class _DepotResidents implements ResidentEspaceRepository {
  int chargements = 0;

  @override
  Future<Either<Failure, List<DemandeResident>>> getAllDemandes() async {
    chargements++;
    return const Right([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
