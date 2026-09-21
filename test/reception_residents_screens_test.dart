import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';
import 'package:cleanops/features/reception/domain/reception_models.dart';
import 'package:cleanops/features/reception/domain/reception_residents_repository.dart';
import 'package:cleanops/features/reception/presentation/providers/reception_residents_provider.dart';
import 'package:cleanops/features/reception/presentation/reception_sections.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_fiche_screen.dart';
import 'package:cleanops/features/reception/presentation/screens/reception_residents_screen.dart';

const _reception = Employee(
  id: 'r1',
  nom: 'Dab',
  prenom: 'Receptioniste',
  slug: 'receptioniste',
  role: RoleType.reception,
  isActif: true,
);

class _EnvoiRecu {
  final String appartementId;
  final String auteurId;
  final String message;
  final bool transmettre;

  final NatureDemande nature;

  _EnvoiRecu(this.appartementId, this.auteurId, this.message, this.transmettre,
      this.nature);
}

class _DepotSimule implements ReceptionResidentsRepository {
  final List<ResidentLigne> lignes;
  FicheAppartement? ficheRenvoyee;
  Object? erreurEnvoi;
  Object? erreurListe;
  Object? erreurFiche;
  int chargementsListe = 0;
  final fichesDemandees = <String>[];
  final envois = <_EnvoiRecu>[];

  _DepotSimule({this.lignes = const [], this.ficheRenvoyee});

  @override
  Future<List<ResidentLigne>> residents() async {
    chargementsListe++;
    if (erreurListe != null) throw erreurListe!;
    return lignes;
  }

  @override
  Future<FicheAppartement?> fiche(String appartementId) async {
    fichesDemandees.add(appartementId);
    if (erreurFiche != null) throw erreurFiche!;
    return ficheRenvoyee;
  }

  @override
  Future<void> envoyerMessage({
    required String appartementId,
    required String auteurId,
    required NatureDemande nature,
    required String message,
    required bool transmettreEmploye,
  }) async {
    if (erreurEnvoi != null) throw erreurEnvoi!;
    envois.add(
        _EnvoiRecu(appartementId, auteurId, message, transmettreEmploye, nature));
  }
}

FicheAppartement _fiche({
  StatutDuJour statut = const StatutDuJour(
    etat: EtatStatut.prevu,
    periode: 'AM',
    employePrenom: 'Essie',
  ),
  List<ProchaineDate>? dates,
  EmployeConcerne? concerne = const EmployeConcerne(id: 'e1', prenom: 'Essie'),
}) =>
    FicheAppartement(
      id: 'a1',
      numero: '101',
      etage: 1,
      taille: '4 1/2',
      residents: const ['Jeanne Tremblay'],
      statut: statut,
      prochainesDates: dates ??
          [
            ProchaineDate(
              date: DateTime(2026, 9, 22),
              jour: 'Mardi',
              periode: 'AM',
              employePrenom: 'Essie',
            ),
            ProchaineDate(
              date: DateTime(2026, 9, 29),
              jour: 'Mardi',
              periode: 'AM',
            ),
          ],
      employeConcerne: concerne,
    );

Future<void> _afficher(
  WidgetTester tester,
  _DepotSimule depot, {
  String initiale = receptionResidentsRoute,
  Size taille = const Size(1000, 1400),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = taille;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: initiale,
    routes: [
      GoRoute(
        path: receptionResidentsRoute,
        builder: (_, __) => const ReceptionResidentsScreen(),
      ),
      GoRoute(
        path: receptionFichePattern,
        builder: (_, state) => ReceptionFicheScreen(
          appartementId: state.pathParameters['appartementId']!,
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        employeeCourantProvider.overrideWithValue(_reception),
        receptionResidentsRepositoryProvider.overrideWithValue(depot),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

ResidentLigne _ligne(String prenom, String nom, String numero,
        {String? apt, int? etage = 1}) =>
    ResidentLigne(
      residentId: 'r-$numero-$prenom',
      prenom: prenom,
      nom: nom,
      appartementId: apt ?? 'a$numero',
      numero: numero,
      etage: etage,
    );

final _troisResidents = [
  _ligne('Jeanne', 'Tremblay', '101', apt: 'a1'),
  _ligne('Paul', 'Gagnon', '202', etage: 2),
  _ligne('Marie', 'Roy', '303', etage: null),
];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('Tableau des résidents', () {
    testWidgets('s\'ouvre directement sur le tableau, sans rien chercher',
        (tester) async {
      final depot = _DepotSimule(lignes: _troisResidents);
      await _afficher(tester, depot);

      expect(depot.chargementsListe, 1);
      for (final t in ['NOM', 'APPARTEMENT', 'ÉTAGE', 'ACTIONS']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Jeanne Tremblay'), findsOneWidget);
      expect(find.text('Paul Gagnon'), findsOneWidget);
      expect(find.text('Marie Roy'), findsOneWidget);
      expect(find.text('Apt 101'), findsOneWidget);
      expect(find.text('Étage 2'), findsOneWidget);
      expect(find.text('Résidents  (3)'), findsOneWidget);
    });

    testWidgets('un étage inconnu s\'affiche « — »', (tester) async {
      await _afficher(tester, _DepotSimule(lignes: [_troisResidents[2]]));
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('chaque ligne propose les trois actions', (tester) async {
      await _afficher(tester, _DepotSimule(lignes: _troisResidents));

      expect(find.byTooltip('Voir la fiche'), findsNWidgets(3));
      expect(find.byTooltip('Imprimer le calendrier'), findsNWidgets(3));
      expect(find.byTooltip('Envoyer un message'), findsNWidgets(3));
    });

    testWidgets('aucun résident actif', (tester) async {
      await _afficher(tester, _DepotSimule());
      expect(find.text('Aucun résident'), findsOneWidget);
    });

    testWidgets('une erreur de chargement propose de réessayer',
        (tester) async {
      final depot = _DepotSimule(lignes: _troisResidents)
        ..erreurListe = const ReceptionErreur('Réseau indisponible.');
      await _afficher(tester, depot);

      expect(find.text('Réessayer'), findsOneWidget);
      expect(depot.chargementsListe, 1);

      depot.erreurListe = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(depot.chargementsListe, 2);
      expect(find.text('Jeanne Tremblay'), findsOneWidget);
    });

    group('recherche', () {
      testWidgets('par nom ou prénom', (tester) async {
        await _afficher(tester, _DepotSimule(lignes: _troisResidents));

        await tester.enterText(find.byType(TextField), 'gagn');
        await tester.pump();

        expect(find.text('Paul Gagnon'), findsOneWidget);
        expect(find.text('Jeanne Tremblay'), findsNothing);
      });

      testWidgets('par numéro d\'appartement', (tester) async {
        await _afficher(tester, _DepotSimule(lignes: _troisResidents));

        await tester.enterText(find.byType(TextField), '303');
        await tester.pump();

        expect(find.text('Marie Roy'), findsOneWidget);
        expect(find.text('Paul Gagnon'), findsNothing);
      });

      testWidgets('aucun résultat, puis effacer', (tester) async {
        await _afficher(tester, _DepotSimule(lignes: _troisResidents));

        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pump();
        expect(find.text('Aucun résultat'), findsOneWidget);

        await tester.tap(find.text('Effacer la recherche'));
        await tester.pump();
        expect(find.text('Jeanne Tremblay'), findsOneWidget);
      });
    });

    group('pagination', () {
      final douze = [
        for (var i = 1; i <= 12; i++) _ligne('Prénom$i', 'Nom', '${100 + i}'),
      ];

      testWidgets('10 lignes par page', (tester) async {
        await _afficher(tester, _DepotSimule(lignes: douze));

        expect(find.text('Prénom1 Nom'), findsOneWidget);
        expect(find.text('Prénom10 Nom'), findsOneWidget);
        expect(find.text('Prénom11 Nom'), findsNothing);
        expect(find.text('1–10 sur 12'), findsOneWidget);

        await tester.tap(find.byTooltip('Suivant'));
        await tester.pump();

        expect(find.text('Prénom11 Nom'), findsOneWidget);
        expect(find.text('Prénom1 Nom'), findsNothing);
        expect(find.text('11–12 sur 12'), findsOneWidget);
      });

      testWidgets('pas de pagination pour 10 résidents ou moins',
          (tester) async {
        await _afficher(tester, _DepotSimule(lignes: douze.take(10).toList()));
        expect(find.byTooltip('Suivant'), findsNothing);
      });
    });

    testWidgets('sur mobile : cartes avec les mêmes actions', (tester) async {
      await _afficher(tester, _DepotSimule(lignes: _troisResidents),
          taille: const Size(420, 900));

      expect(find.text('NOM'), findsNothing);
      expect(find.text('Jeanne Tremblay'), findsOneWidget);
      expect(find.text('Apt 101 · Étage 1'), findsOneWidget);
      expect(find.byTooltip('Voir la fiche'), findsNWidgets(3));
      expect(find.byTooltip('Envoyer un message'), findsNWidgets(3));
    });

    group('actions', () {
      testWidgets('« Voir la fiche » ouvre la fiche de l\'appartement',
          (tester) async {
        final depot =
            _DepotSimule(lignes: _troisResidents, ficheRenvoyee: _fiche());
        await _afficher(tester, depot);

        await tester.tap(find.byTooltip('Voir la fiche').first);
        await tester.pumpAndSettle();

        expect(depot.fichesDemandees, ['a1']);
        expect(find.text('Statut du jour'), findsOneWidget);
      });

      testWidgets('toucher la ligne ouvre aussi la fiche', (tester) async {
        final depot =
            _DepotSimule(lignes: _troisResidents, ficheRenvoyee: _fiche());
        await _afficher(tester, depot);

        await tester.tap(find.text('Jeanne Tremblay'));
        await tester.pumpAndSettle();

        expect(find.text('Statut du jour'), findsOneWidget);
      });

      testWidgets('« Imprimer » sans date planifiée : message, pas d\'aperçu',
          (tester) async {
        final depot = _DepotSimule(
            lignes: _troisResidents, ficheRenvoyee: _fiche(dates: const []));
        await _afficher(tester, depot);

        await tester.tap(find.byTooltip('Imprimer le calendrier').first);
        await tester.pumpAndSettle();

        expect(depot.fichesDemandees, ['a1']);
        expect(
          find.text('Aucune date de ménage planifiée pour l\'appartement 101.'),
          findsOneWidget,
        );
      });

      testWidgets('« Imprimer » : si la fiche ne se charge pas, l\'erreur '
          's\'affiche', (tester) async {
        final depot = _DepotSimule(lignes: _troisResidents)
          ..erreurFiche = const ReceptionErreur('Impossible de charger la fiche.');
        await _afficher(tester, depot);

        await tester.tap(find.byTooltip('Imprimer le calendrier').first);
        await tester.pumpAndSettle();

        expect(find.text('Impossible de charger la fiche.'), findsOneWidget);
      });

      testWidgets('« Message » ouvre le formulaire et l\'envoi le ferme',
          (tester) async {
        final depot =
            _DepotSimule(lignes: _troisResidents, ficheRenvoyee: _fiche());
        await _afficher(tester, depot);

        await tester.tap(find.byTooltip('Envoyer un message').first);
        await tester.pumpAndSettle();

        expect(find.text('Jeanne Tremblay · Apt 101'), findsOneWidget);
        expect(find.text('Message à l\'administration'), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Reprogrammation'));
        await tester.enterText(
          find.descendant(
              of: find.byType(Dialog), matching: find.byType(TextField)),
          'Prévenir avant de passer',
        );
        await tester.pump();
        await tester.tap(find.text('Envoyer'));
        await tester.pumpAndSettle();

        expect(depot.envois, hasLength(1));
        expect(depot.envois.single.appartementId, 'a1');
        expect(depot.envois.single.auteurId, 'r1');
        expect(depot.envois.single.nature, NatureDemande.reprogrammation);
        expect(depot.envois.single.message, 'Prévenir avant de passer');
        expect(find.text('Message à l\'administration'), findsNothing);
      });
    });
  });

  group('Fiche', () {
    testWidgets('affiche l\'appartement, les résidents et le statut',
        (tester) async {
      await _afficher(tester, _DepotSimule(ficheRenvoyee: _fiche()),
          initiale: receptionFicheRoute('a1'));

      expect(find.text('Appartement 101'), findsWidgets);
      expect(find.text('Étage 1 · 4 1/2'), findsOneWidget);
      expect(find.text('Jeanne Tremblay'), findsOneWidget);
      expect(find.text("Prévu aujourd'hui AM — Essie"), findsOneWidget);
    });

    testWidgets('appartement introuvable', (tester) async {
      await _afficher(tester, _DepotSimule(),
          initiale: receptionFicheRoute('inconnu'));

      expect(find.text('Cet appartement est introuvable.'), findsOneWidget);
    });

    testWidgets('liste plusieurs dates et propose l\'impression sans accord',
        (tester) async {
      await _afficher(tester, _DepotSimule(ficheRenvoyee: _fiche()),
          initiale: receptionFicheRoute('a1'));

      expect(find.text('Mardi 22/09/2026 — AM — Essie'), findsOneWidget);
      expect(find.text('Mardi 29/09/2026 — AM'), findsOneWidget);

      final bouton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Imprimer le calendrier'),
      );
      expect(bouton.onPressed, isNotNull);
    });

    testWidgets('sans date : message et impression désactivée', (tester) async {
      await _afficher(
          tester, _DepotSimule(ficheRenvoyee: _fiche(dates: const [])),
          initiale: receptionFicheRoute('a1'));

      expect(find.text('Aucune date planifiée.'), findsOneWidget);
      final bouton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Imprimer le calendrier'),
      );
      expect(bouton.onPressed, isNull);
    });

    testWidgets('non effectué : aucun motif ni nom à l\'écran', (tester) async {
      await _afficher(
        tester,
        _DepotSimule(
          ficheRenvoyee: _fiche(
            statut: const StatutDuJour(etat: EtatStatut.nonRealise),
          ),
        ),
        initiale: receptionFicheRoute('a1'),
      );

      expect(find.text("Non effectué aujourd'hui"), findsOneWidget);
      for (final mot in ['Absent', 'Refus', 'vacant', 'Motif', 'motif']) {
        expect(find.textContaining(mot), findsNothing, reason: mot);
      }
    });
  });

  group('Formulaire de message', () {
    Finder champMessage() => find.descendant(
          of: find.byType(Card),
          matching: find.byType(TextField),
        );

    Future<void> choisirNature(WidgetTester tester, String libelle) async {
      final chip = find.widgetWithText(ChoiceChip, libelle);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
    }

    testWidgets('« Envoyer » est désactivé tant que le message est vide',
        (tester) async {
      await _afficher(tester, _DepotSimule(ficheRenvoyee: _fiche()),
          initiale: receptionFicheRoute('a1'));

      FilledButton envoyer() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Envoyer'));
      expect(envoyer().onPressed, isNull);

      await choisirNature(tester, 'Annulation');
      expect(envoyer().onPressed, isNull, reason: 'la nature seule ne suffit pas');

      await tester.enterText(champMessage(), '   ');
      await tester.pump();
      expect(envoyer().onPressed, isNull);

      await tester.enterText(champMessage(), 'Bonjour');
      await tester.pump();
      expect(envoyer().onPressed, isNotNull);
    });

    testWidgets('la nature de la demande est obligatoire', (tester) async {
      await _afficher(tester, _DepotSimule(ficheRenvoyee: _fiche()),
          initiale: receptionFicheRoute('a1'));

      expect(find.text('Nature de la demande'), findsOneWidget);
      for (final n in ['Annulation', 'Reprogrammation', 'Autre demande']) {
        expect(find.widgetWithText(ChoiceChip, n), findsOneWidget, reason: n);
      }

      await tester.enterText(champMessage(), 'Bonjour');
      await tester.pump();

      final envoyer = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Envoyer'));
      expect(envoyer.onPressed, isNull,
          reason: 'un message sans nature ne part pas');
    });

    testWidgets('la nature choisie est envoyée, puis remise à zéro',
        (tester) async {
      final depot = _DepotSimule(ficheRenvoyee: _fiche());
      await _afficher(tester, depot, initiale: receptionFicheRoute('a1'));

      await choisirNature(tester, 'Annulation');
      await tester.enterText(champMessage(), 'Annuler jeudi');
      await tester.pump();
      await tester.ensureVisible(find.text('Envoyer'));
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(depot.envois.single.nature, NatureDemande.annulation);

      final chip = tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Annulation'));
      expect(chip.selected, isFalse, reason: 'prêt pour la demande suivante');
    });

    testWidgets('envoi simple : la case reste décochée', (tester) async {
      final depot = _DepotSimule(ficheRenvoyee: _fiche());
      await _afficher(tester, depot, initiale: receptionFicheRoute('a1'));

      await choisirNature(tester, 'Autre demande');
      await tester.enterText(champMessage(), '  Fuite dans la salle de bain  ');
      await tester.pump();
      await tester.ensureVisible(find.text('Envoyer'));
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(depot.envois, hasLength(1));
      expect(depot.envois.single.appartementId, 'a1');
      expect(depot.envois.single.auteurId, 'r1');
      expect(depot.envois.single.message, 'Fuite dans la salle de bain');
      expect(depot.envois.single.transmettre, isFalse);
      expect(find.text('Message transmis à l\'administration.'), findsOneWidget);
    });

    testWidgets('transmission à l\'employé quand la case est cochée',
        (tester) async {
      final depot = _DepotSimule(ficheRenvoyee: _fiche());
      await _afficher(tester, depot, initiale: receptionFicheRoute('a1'));

      expect(find.text('Employé concerné : Essie'), findsOneWidget);

      await choisirNature(tester, 'Reprogrammation');
      await tester.enterText(champMessage(), 'Merci de passer plus tôt');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(depot.envois.single.transmettre, isTrue);
    });

    testWidgets('sans employé concerné, la case est désactivée', (tester) async {
      final depot = _DepotSimule(ficheRenvoyee: _fiche(concerne: null));
      await _afficher(tester, depot, initiale: receptionFicheRoute('a1'));

      final case_ = tester.widget<CheckboxListTile>(
          find.byType(CheckboxListTile));
      expect(case_.onChanged, isNull);
      expect(find.text('Aucun employé n\'est concerné par cet appartement.'),
          findsOneWidget);
    });

    testWidgets('une erreur du serveur s\'affiche et le texte est conservé',
        (tester) async {
      final depot = _DepotSimule(ficheRenvoyee: _fiche())
        ..erreurEnvoi = const ReceptionErreur('Auteur invalide ou inactif.');
      await _afficher(tester, depot, initiale: receptionFicheRoute('a1'));

      await choisirNature(tester, 'Autre demande');
      await tester.enterText(champMessage(), 'Bonjour');
      await tester.pump();
      await tester.ensureVisible(find.text('Envoyer'));
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(find.text('Auteur invalide ou inactif.'), findsOneWidget);
      expect(find.text('Bonjour'), findsOneWidget);
      expect(find.text('Message transmis à l\'administration.'), findsNothing);
    });
  });
}
