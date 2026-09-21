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
  String? debut,
  String? fin,
  List<TacheEquipe> taches = const [],
}) =>
    MembreEquipe(
      id: 'id-$prenom',
      prenom: prenom,
      nom: nom,
      presence: presence,
      heureDebut: debut,
      heureFin: fin,
      taches: taches,
    );

TacheEquipe _tache(String numero, String periode, EtatTacheEquipe etat) =>
    TacheEquipe(
      appartementId: 'a$numero',
      numero: numero,
      periode: periode,
      etat: etat,
    );

EquipeDuJour _equipe({List<TacheEnAttente> attente = const []}) => EquipeDuJour(
      date: DateTime(2026, 9, 21),
      enAttente: attente,
      membres: [
        _membre('Essie', 'France', PresenceJour.presente,
            debut: '08:00',
            fin: '16:00',
            taches: [
              _tache('101', 'AM', EtatTacheEquipe.realise),
              _tache('103', 'PM', EtatTacheEquipe.aFaire),
            ]),
        _membre('Annise', 'Sylvestre', PresenceJour.absente,
            taches: [_tache('202', 'AM', EtatTacheEquipe.aFaire)]),
        _membre('Marta', 'Louis', PresenceJour.absenteMatin),
        _membre('Naomie', 'Bagalwa', PresenceJour.nonDeclaree,
            taches: [_tache('303', 'PM', EtatTacheEquipe.nonRealise)]),
      ],
    );

Future<void> _afficher(
  WidgetTester tester,
  _DepotSimule depot, {
  Size taille = const Size(1000, 1400),
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
            'heure_debut': '08:00',
            'heure_fin': '16:00',
            'taches': [
              {
                'appartement_id': 'a1',
                'numero': '101',
                'periode': 'AM',
                'etat': 'realise',
              },
            ],
          },
          {
            'id': 'e2',
            'prenom': 'Marta',
            'nom': 'Louis',
            'presence': 'non_declaree',
            'heure_debut': null,
            'heure_fin': null,
            'taches': [],
          },
        ],
        'en_attente': [
          {'appartement_id': 'a9', 'numero': '909', 'periode': 'PM'},
        ],
      });

      expect(e.date, DateTime(2026, 9, 21));
      expect(e.membres, hasLength(2));
      expect(e.membres.first.horaire, '08:00 – 16:00');
      expect(e.membres.first.taches.single.etat, EtatTacheEquipe.realise);
      expect(e.membres.last.horaire, isNull);
      expect(e.membres.last.presence, PresenceJour.nonDeclaree);
      expect(e.enAttente.single.numero, '909');
    });

    test('les 5 présences ont leur libellé', () {
      expect(PresenceJour.fromCode('presente').libelle, 'Présente');
      expect(PresenceJour.fromCode('absente').libelle, 'Absente');
      expect(PresenceJour.fromCode('absente_matin').libelle,
          'Absente le matin');
      expect(PresenceJour.fromCode('absente_apres_midi').libelle,
          "Absente l'après-midi");
      expect(PresenceJour.fromCode('non_declaree').libelle, 'Non déclarée');
    });

    test('une valeur inconnue est refusée plutôt qu\'affichée de travers', () {
      expect(() => PresenceJour.fromCode('n_importe_quoi'),
          throwsFormatException);
      expect(() => EtatTacheEquipe.fromCode('motif_refus'),
          throwsFormatException);
    });

    test('l\'horaire exige une heure de début ET de fin', () {
      expect(
        _membre('A', 'B', PresenceJour.presente, debut: '08:00').horaire,
        isNull,
      );
      expect(
        _membre('A', 'B', PresenceJour.presente, fin: '16:00').horaire,
        isNull,
      );
      expect(
        _membre('A', 'B', PresenceJour.presente, debut: '08:00', fin: '16:00')
            .horaire,
        '08:00 – 16:00',
      );
    });

    test('le résumé des ménages', () {
      expect(_membre('A', 'B', PresenceJour.presente).resumeMenages, 'Aucun');
      expect(
        _membre('A', 'B', PresenceJour.presente, taches: [
          _tache('1', 'AM', EtatTacheEquipe.aFaire),
          _tache('2', 'PM', EtatTacheEquipe.aFaire),
        ]).resumeMenages,
        '0/2 effectué',
      );
      expect(
        _membre('A', 'B', PresenceJour.presente, taches: [
          _tache('1', 'AM', EtatTacheEquipe.realise),
          _tache('2', 'PM', EtatTacheEquipe.realise),
        ]).resumeMenages,
        '2/2 effectués',
      );
    });

    test('un non-réalisé ne porte aucun motif', () {
      // Le modèle n'a aucun champ pour un motif : un JSON qui en contiendrait
      // un (par erreur du serveur) ne l'atteint jamais.
      final t = TacheEquipe.fromJson({
        'appartement_id': 'a1',
        'numero': '101',
        'periode': 'AM',
        'etat': 'non_realise',
        'motif': 'MOTIF-SECRET',
        'motif_absent': 'MOTIF-SECRET',
      });
      expect(t.etat.libelle, 'Non effectué');
      expect(t.toString(), isNot(contains('MOTIF-SECRET')));
    });
  });

  group('Tableau de l\'équipe', () {
    testWidgets('s\'ouvre directement sur le tableau', (tester) async {
      final depot = _DepotSimule(_equipe());
      await _afficher(tester, depot);

      expect(depot.chargements, 1);
      for (final t in ['NOM', 'PRÉSENCE', 'HORAIRE', 'MÉNAGES', 'ACTIONS']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Équipe  (4)'), findsOneWidget);
      expect(find.text('Essie France'), findsOneWidget);
      expect(find.text('Annise Sylvestre'), findsOneWidget);
      expect(find.text('Marta Louis'), findsOneWidget);
      expect(find.text('Naomie Bagalwa'), findsOneWidget);
    });

    testWidgets('affiche la date du Québec renvoyée par le serveur',
        (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));
      expect(find.text('Aujourd\'hui — Lundi 21 septembre 2026'),
          findsOneWidget);
    });

    testWidgets('présence, horaire et ménages de chaque employé',
        (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      expect(find.text('Présente'), findsOneWidget);
      expect(find.text('Absente'), findsOneWidget);
      expect(find.text('Absente le matin'), findsOneWidget);
      expect(find.text('Non déclarée'), findsOneWidget);
      expect(find.text('08:00 – 16:00'), findsOneWidget);
      expect(find.text('1/2 effectué'), findsOneWidget);
      expect(find.text('Aucun'), findsOneWidget);
    });

    testWidgets('filtre Présents', (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      await tester.tap(find.text('Présents'));
      await tester.pump();

      expect(find.text('Essie France'), findsOneWidget);
      expect(find.text('Annise Sylvestre'), findsNothing);
      expect(find.text('Marta Louis'), findsNothing);
      expect(find.text('Naomie Bagalwa'), findsNothing);
    });

    testWidgets('filtre Absents : toute absence, même partielle',
        (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      await tester.tap(find.text('Absents'));
      await tester.pump();

      expect(find.text('Annise Sylvestre'), findsOneWidget);
      expect(find.text('Marta Louis'), findsOneWidget);
      expect(find.text('Essie France'), findsNothing);
      expect(find.text('Naomie Bagalwa'), findsNothing);
    });

    testWidgets('filtre Non déclarés', (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      await tester.tap(find.text('Non déclarés'));
      await tester.pump();

      expect(find.text('Naomie Bagalwa'), findsOneWidget);
      expect(find.text('Essie France'), findsNothing);
    });

    testWidgets('recherche par nom, puis aucun résultat', (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      await tester.enterText(find.byType(TextField), 'sylvest');
      await tester.pump();
      expect(find.text('Annise Sylvestre'), findsOneWidget);
      expect(find.text('Essie France'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Aucun résultat'), findsOneWidget);

      await tester.tap(find.text('Effacer les filtres'));
      await tester.pump();
      expect(find.text('Essie France'), findsOneWidget);
    });

    testWidgets('ménages en attente d\'attribution', (tester) async {
      await _afficher(
        tester,
        _DepotSimule(_equipe(attente: const [
          TacheEnAttente(appartementId: 'a9', numero: '909', periode: 'PM'),
          TacheEnAttente(appartementId: 'a8', numero: '808', periode: 'AM'),
        ])),
      );

      expect(
        find.text("2 ménages en attente d'attribution : "
            'Apt 909 PM, Apt 808 AM'),
        findsOneWidget,
      );
    });

    testWidgets('aucun bandeau quand rien n\'attend', (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));
      expect(find.textContaining("en attente d'attribution"), findsNothing);
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

    testWidgets('sur mobile : cartes avec présence, horaire et ménages',
        (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()),
          taille: const Size(420, 900));

      expect(find.text('NOM'), findsNothing);
      expect(find.text('Essie France'), findsOneWidget);
      expect(find.text('08:00 – 16:00 · Ménages : 1/2 effectué'),
          findsOneWidget);
      expect(find.byTooltip("Voir l'horaire du jour"), findsNWidgets(4));
    });
  });

  group('Horaire du jour d\'un employé', () {
    testWidgets('liste les appartements, la période et l\'état',
        (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      await tester.tap(find.byTooltip("Voir l'horaire du jour").first);
      await tester.pumpAndSettle();

      expect(find.text('Horaire du jour'), findsOneWidget);
      expect(find.text('Apt 101'), findsOneWidget);
      expect(find.text('Effectué'), findsOneWidget);
      expect(find.text('Apt 103'), findsOneWidget);
      expect(find.text('À faire'), findsOneWidget);
      expect(find.text('Horaire : 08:00 – 16:00'), findsOneWidget);
    });

    testWidgets('un non-réalisé s\'affiche « Non effectué », sans motif',
        (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      // Naomie Bagalwa : quatrième ligne.
      await tester.tap(find.byTooltip("Voir l'horaire du jour").at(3));
      await tester.pumpAndSettle();

      expect(find.text('Non effectué'), findsOneWidget);
      for (final mot in ['Absent ', 'Refus', 'vacant', 'motif', 'Motif']) {
        expect(find.textContaining(mot), findsNothing, reason: mot);
      }
    });

    testWidgets('employé sans ménage', (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      await tester.tap(find.byTooltip("Voir l'horaire du jour").at(2));
      await tester.pumpAndSettle();

      expect(find.text("Aucun ménage prévu aujourd'hui."), findsOneWidget);
    });

    testWidgets('toucher la ligne ouvre aussi l\'horaire', (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      await tester.tap(find.text('Essie France'));
      await tester.pumpAndSettle();

      expect(find.text('Horaire du jour'), findsOneWidget);
    });

    testWidgets('se ferme', (tester) async {
      await _afficher(tester, _DepotSimule(_equipe()));

      await tester.tap(find.byTooltip("Voir l'horaire du jour").first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();

      expect(find.text('Horaire du jour'), findsNothing);
    });
  });
}
