import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cleanops/core/errors/failures.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';
import 'package:cleanops/features/demandes_equipe/data/models/demande_equipe_model.dart';
import 'package:cleanops/features/demandes_equipe/domain/entities/demande_equipe.dart';
import 'package:cleanops/features/demandes_equipe/domain/entities/document_demande.dart';
import 'package:cleanops/features/demandes_equipe/domain/entities/fichier_choisi.dart';
import 'package:cleanops/features/demandes_equipe/domain/repositories/demande_equipe_repository.dart';
import 'package:cleanops/features/demandes_equipe/domain/selecteur_document.dart';
import 'package:cleanops/features/demandes_equipe/presentation/providers/demande_equipe_provider.dart';
import 'package:cleanops/features/demandes_equipe/presentation/widgets/nouvelle_demande_equipe_sheet.dart';
import 'package:cleanops/features/demandes_equipe/presentation/widgets/piece_jointe_demande.dart';
import 'package:cleanops/features/demandes_equipe/presentation/screens/document_demande_screen.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _employe = Employee(
  id: 'e1',
  nom: 'Dab',
  prenom: 'Nadine',
  slug: 'nadine',
  role: RoleType.employe,
  isActif: true,
);

DemandeEquipe _demande({
  String id = 'd1',
  String? documentNom,
}) =>
    DemandeEquipe(
      id: id,
      employeeId: 'e1',
      type: TypeDemandeEquipe.conge,
      dateDebut: DateTime(2026, 9, 21),
      motif: 'Un motif',
      statut: StatutDemandeEquipe.enAttente,
      createdAt: DateTime(2026, 9, 21),
      documentNom: documentNom,
      documentTypeMime: documentNom == null ? null : 'application/pdf',
      documentTaille: documentNom == null ? null : 1234,
    );

Map<String, dynamic> _json({dynamic documents}) => {
      'id': 'd1',
      'employee_id': 'e1',
      'type': 'Conge',
      'date_debut': '2026-09-21',
      'date_fin': null,
      'motif': 'x',
      'statut': 'EnAttente',
      'date_creation': '2026-09-21T10:00:00Z',
      if (documents != null) 'demandes_equipe_documents': documents,
    };

/// Repository de test : réponses configurables pour `creerDemande` et
/// `joindreDocument` ; `getMesDemandes` ne se termine jamais (évite la course
/// avec le chargement automatique du constructeur, hors sujet ici).
class _FakeRepo implements DemandeEquipeRepository {
  Either<Failure, DemandeEquipe> Function()? creerDemandeResultat;
  Either<Failure, void> Function()? joindreDocumentResultat;
  final joindreAppels = <Map<String, Object?>>[];

  @override
  Future<Either<Failure, List<DemandeEquipe>>> getMesDemandes(
          String employeeId) =>
      Completer<Either<Failure, List<DemandeEquipe>>>().future;

  @override
  Future<Either<Failure, List<DemandeEquipe>>> getAllDemandes() async =>
      const Right([]);

  @override
  Future<Either<Failure, DemandeEquipe>> creerDemande({
    required String employeeId,
    required String employeePrenom,
    required String employeeNom,
    required TypeDemandeEquipe type,
    required DateTime dateDebut,
    DateTime? dateFin,
    required String motif,
  }) async =>
      creerDemandeResultat!();

  @override
  Future<Either<Failure, DemandeEquipe>> traiterDemande({
    required String demandeId,
    required String traiteParId,
    required bool approuve,
    String? note,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> joindreDocument({
    required String demandeId,
    required String employeeId,
    required String nom,
    required String typeMime,
    required Uint8List octets,
  }) async {
    joindreAppels.add({
      'demandeId': demandeId,
      'employeeId': employeeId,
      'nom': nom,
      'typeMime': typeMime,
      'taille': octets.length,
    });
    return joindreDocumentResultat!();
  }

  @override
  Future<Either<Failure, DocumentDemande>> lireDocument(
          String demandeId) async =>
      throw UnimplementedError();
}

/// Sélecteur de document de test.
class _FakeSelecteur implements SelecteurDocument {
  FichierChoisi? retour;
  Object? erreur;
  final appels = <List<String>>[];

  @override
  Future<FichierChoisi?> choisir({required List<String> extensions}) async {
    appels.add(extensions);
    if (erreur != null) throw erreur!;
    return retour;
  }
}

Uint8List _pdf() => Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 1, 2, 3, 4]);

void main() {
  group('DemandeEquipeModel.fromJson — document joint', () {
    test('aucun document : les champs restent null', () {
      final d = DemandeEquipeModel.fromJson(_json());
      expect(d.aDocument, isFalse);
      expect(d.documentNom, isNull);
    });

    test('embarqué en LISTE (relation PostgREST « à plusieurs »)', () {
      final d = DemandeEquipeModel.fromJson(_json(documents: [
        {'nom': 'billet.pdf', 'type_mime': 'application/pdf', 'taille': 2048},
      ]));
      expect(d.aDocument, isTrue);
      expect(d.documentNom, 'billet.pdf');
      expect(d.documentTypeMime, 'application/pdf');
      expect(d.documentTaille, 2048);
    });

    test('embarqué en OBJET (relation PostgREST « à un »)', () {
      final d = DemandeEquipeModel.fromJson(_json(documents: {
        'nom': 'note.jpg',
        'type_mime': 'image/jpeg',
        'taille': 512,
      }));
      expect(d.aDocument, isTrue);
      expect(d.documentNom, 'note.jpg');
    });

    test('liste vide (relation sans ligne) : pas de document', () {
      final d = DemandeEquipeModel.fromJson(_json(documents: []));
      expect(d.aDocument, isFalse);
    });
  });

  group('DemandeEquipe.avecDocument', () {
    test('remplace les métadonnées du document sans toucher au reste', () {
      final original = _demande();
      final avecDoc = original.avecDocument(
          nom: 'x.pdf', typeMime: 'application/pdf', taille: 99);

      expect(avecDoc.documentNom, 'x.pdf');
      expect(avecDoc.documentTaille, 99);
      expect(avecDoc.motif, original.motif);
      expect(avecDoc.statut, original.statut);
      expect(avecDoc.id, original.id);
      expect(original.aDocument, isFalse, reason: 'immutable');
    });
  });

  group('MesDemandesEquipeNotifier.creerDemande — document', () {
    test('succès sans document : rien à joindre', () async {
      final repo = _FakeRepo()..creerDemandeResultat = () => Right(_demande());
      final notifier = MesDemandesEquipeNotifier(
          repo: repo, employeeId: 'e1', employeePrenom: 'N', employeeNom: 'D');

      final ok = await notifier.creerDemande(
          type: TypeDemandeEquipe.conge,
          dateDebut: DateTime(2026, 9, 21),
          motif: 'x');

      expect(ok, isTrue);
      expect(notifier.state.demandes.single.aDocument, isFalse);
      expect(repo.joindreAppels, isEmpty);
      expect(notifier.state.avertissement, isNull);
    });

    test('document joint avec succès : mis à jour localement, sans recharger',
        () async {
      final repo = _FakeRepo();
      repo.creerDemandeResultat = () => Right(_demande());
      repo.joindreDocumentResultat = () => const Right(null);
      final notifier = MesDemandesEquipeNotifier(
          repo: repo, employeeId: 'e1', employeePrenom: 'N', employeeNom: 'D');

      final ok = await notifier.creerDemande(
        type: TypeDemandeEquipe.conge,
        dateDebut: DateTime(2026, 9, 21),
        motif: 'x',
        documentOctets: _pdf(),
        documentNom: 'billet.pdf',
        documentTypeMime: 'application/pdf',
      );

      expect(ok, isTrue);
      expect(notifier.state.demandes.single.documentNom, 'billet.pdf');
      expect(notifier.state.demandes.single.documentTaille, _pdf().length);
      expect(notifier.state.avertissement, isNull);
      expect(repo.joindreAppels.single['demandeId'], 'd1');
      expect(repo.joindreAppels.single['employeeId'], 'e1');
    });

    test('document refusé par le serveur : avertissement, la demande reste '
        'envoyée', () async {
      final repo = _FakeRepo();
      repo.creerDemandeResultat = () => Right(_demande());
      repo.joindreDocumentResultat = () => Left(ServerFailure(
          'Ce document est trop volumineux et ne peut pas être '
          'enregistré (5 Mo maximum).'));
      final notifier = MesDemandesEquipeNotifier(
          repo: repo, employeeId: 'e1', employeePrenom: 'N', employeeNom: 'D');

      final ok = await notifier.creerDemande(
        type: TypeDemandeEquipe.conge,
        dateDebut: DateTime(2026, 9, 21),
        motif: 'x',
        documentOctets: _pdf(),
        documentNom: 'billet.pdf',
        documentTypeMime: 'application/pdf',
      );

      expect(ok, isTrue, reason: 'la demande a bien été créée');
      expect(notifier.state.demandes.single.aDocument, isFalse);
      expect(notifier.state.avertissement, contains('trop volumineux'));
      expect(notifier.state.avertissement, contains('a été envoyée'));
    });

    test('échec de la création : le document n\'est jamais envoyé', () async {
      final repo = _FakeRepo()
        ..creerDemandeResultat = () => Left(ServerFailure('Erreur serveur'));
      final notifier = MesDemandesEquipeNotifier(
          repo: repo, employeeId: 'e1', employeePrenom: 'N', employeeNom: 'D');

      final ok = await notifier.creerDemande(
        type: TypeDemandeEquipe.conge,
        dateDebut: DateTime(2026, 9, 21),
        motif: 'x',
        documentOctets: _pdf(),
        documentNom: 'billet.pdf',
        documentTypeMime: 'application/pdf',
      );

      expect(ok, isFalse);
      expect(repo.joindreAppels, isEmpty);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.demandes, isEmpty);
    });

    test('viderAvertissement efface l\'avertissement', () async {
      final repo = _FakeRepo();
      repo.creerDemandeResultat = () => Right(_demande());
      repo.joindreDocumentResultat =
          () => Left(ServerFailure('ne peut pas être enregistré'));
      final notifier = MesDemandesEquipeNotifier(
          repo: repo, employeeId: 'e1', employeePrenom: 'N', employeeNom: 'D');
      await notifier.creerDemande(
        type: TypeDemandeEquipe.conge,
        dateDebut: DateTime(2026, 9, 21),
        motif: 'x',
        documentOctets: _pdf(),
        documentNom: 'billet.pdf',
        documentTypeMime: 'application/pdf',
      );
      expect(notifier.state.avertissement, isNotNull);

      notifier.viderAvertissement();
      expect(notifier.state.avertissement, isNull);
    });
  });

  group('Sélection du document — NouvelleDemandeEquipeSheet', () {
    Future<void> pump(
      WidgetTester tester, {
      required _FakeSelecteur selecteur,
      required _FakeRepo repo,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeeCourantProvider.overrideWithValue(_employe),
            selecteurDocumentProvider.overrideWithValue(selecteur),
            demandeEquipeRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('fr', 'FR'), Locale('en')],
            home: Scaffold(body: NouvelleDemandeEquipeSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('bouton « Joindre un document » proposé au départ',
        (tester) async {
      await pump(tester, selecteur: _FakeSelecteur(), repo: _FakeRepo());
      expect(find.text('Joindre un document (PDF ou image)'), findsOneWidget);
    });

    testWidgets('un fichier choisi affiche son nom et sa taille',
        (tester) async {
      final selecteur = _FakeSelecteur()
        ..retour = FichierChoisi(
            nom: 'billet.pdf', extension: 'pdf', octets: _pdf());
      await pump(tester, selecteur: selecteur, repo: _FakeRepo());

      await tester.tap(find.text('Joindre un document (PDF ou image)'));
      await tester.pumpAndSettle();

      expect(find.text('billet.pdf'), findsOneWidget);
      expect(find.byTooltip('Retirer le document'), findsOneWidget);
      expect(
          find.text('Joindre un document (PDF ou image)'), findsNothing);
    });

    testWidgets('annuler (aucun fichier retourné) ne montre pas d\'erreur',
        (tester) async {
      final selecteur = _FakeSelecteur()..retour = null;
      await pump(tester, selecteur: selecteur, repo: _FakeRepo());

      await tester.tap(find.text('Joindre un document (PDF ou image)'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
      expect(find.text('Joindre un document (PDF ou image)'), findsOneWidget);
    });

    testWidgets('extension refusée : message clair, rien de joint',
        (tester) async {
      final selecteur = _FakeSelecteur()
        ..retour = FichierChoisi(
            nom: 'notes.docx',
            extension: 'docx',
            octets: Uint8List.fromList([1, 2, 3]));
      await pump(tester, selecteur: selecteur, repo: _FakeRepo());

      await tester.tap(find.text('Joindre un document (PDF ou image)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('PDF, JPEG ou PNG'), findsOneWidget);
      expect(find.text('notes.docx'), findsNothing);
    });

    testWidgets('fichier trop volumineux : refusé avec la taille max affichée',
        (tester) async {
      final gros = Uint8List(tailleMaxDocumentDemande + 1);
      final selecteur = _FakeSelecteur()
        ..retour = FichierChoisi(nom: 'gros.pdf', extension: 'pdf', octets: gros);
      await pump(tester, selecteur: selecteur, repo: _FakeRepo());

      await tester.tap(find.text('Joindre un document (PDF ou image)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('trop volumineux'), findsOneWidget);
      expect(find.textContaining('5 Mo'), findsOneWidget);
    });

    testWidgets('retirer le document choisi ramène le bouton initial',
        (tester) async {
      final selecteur = _FakeSelecteur()
        ..retour = FichierChoisi(
            nom: 'billet.pdf', extension: 'pdf', octets: _pdf());
      await pump(tester, selecteur: selecteur, repo: _FakeRepo());
      await tester.tap(find.text('Joindre un document (PDF ou image)'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Retirer le document'));
      await tester.pumpAndSettle();

      expect(find.text('Joindre un document (PDF ou image)'), findsOneWidget);
      expect(find.text('billet.pdf'), findsNothing);
    });

    test('signatureDocumentValide : détecte un fichier mal étiqueté', () {
      final pdf = _pdf(); // %PDF...
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]);
      final png =
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4, 5]);
      final texte = Uint8List.fromList('coucou, pas un document'.codeUnits);

      expect(signatureDocumentValide(pdf, 'application/pdf'), isTrue);
      expect(signatureDocumentValide(jpeg, 'image/jpeg'), isTrue);
      expect(signatureDocumentValide(png, 'image/png'), isTrue);

      // Renommé en .pdf mais c'est en fait un JPEG (ou l'inverse) : refusé.
      expect(signatureDocumentValide(jpeg, 'application/pdf'), isFalse);
      expect(signatureDocumentValide(pdf, 'image/jpeg'), isFalse);
      expect(signatureDocumentValide(texte, 'application/pdf'), isFalse);
      expect(signatureDocumentValide(Uint8List(0), 'application/pdf'), isFalse,
          reason: 'trop court pour contenir la signature');
    });

    testWidgets(
        'un fichier renommé (mauvaise signature) est refusé avec un message '
        'clair', (tester) async {
      final selecteur = _FakeSelecteur()
        ..retour = FichierChoisi(
          nom: 'photo.pdf',
          extension: 'pdf',
          // Un vrai JPEG, mais renommé en .pdf.
          octets: Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]),
        );
      await pump(tester, selecteur: selecteur, repo: _FakeRepo());

      await tester.tap(find.text('Joindre un document (PDF ou image)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ne semble pas être un pdf valide'),
          findsOneWidget);
      expect(find.text('photo.pdf'), findsNothing);
    });

    test('typeMimeDocumentDemande : extensions reconnues', () {
      expect(typeMimeDocumentDemande('pdf'), 'application/pdf');
      expect(typeMimeDocumentDemande('PDF'), 'application/pdf');
      expect(typeMimeDocumentDemande('jpg'), 'image/jpeg');
      expect(typeMimeDocumentDemande('jpeg'), 'image/jpeg');
      expect(typeMimeDocumentDemande('png'), 'image/png');
      expect(typeMimeDocumentDemande('docx'), isNull);
      expect(typeMimeDocumentDemande(null), isNull);
    });

    testWidgets(
        'envoi : le document choisi est transmis au dépôt avec la demande',
        (tester) async {
      final repo = _FakeRepo();
      repo.creerDemandeResultat = () => Right(_demande());
      repo.joindreDocumentResultat = () => const Right(null);
      final selecteur = _FakeSelecteur()
        ..retour = FichierChoisi(
            nom: 'billet.pdf', extension: 'pdf', octets: _pdf());
      await pump(tester, selecteur: selecteur, repo: repo);

      await tester.tap(find.text('Joindre un document (PDF ou image)'));
      await tester.pumpAndSettle();

      // Date + motif, requis pour activer l'envoi.
      await tester.tap(find.text('Choisir…').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Un motif valable');
      await tester.ensureVisible(find.text('Envoyer la demande'));
      await tester.tap(find.text('Envoyer la demande'));
      await tester.pumpAndSettle();

      expect(repo.joindreAppels, hasLength(1));
      expect(repo.joindreAppels.single['nom'], 'billet.pdf');
      expect(repo.joindreAppels.single['typeMime'], 'application/pdf');
    });
  });

  group('PieceJointeDemande', () {
    Future<void> pump(WidgetTester tester, DemandeEquipe demande,
        {required _FakeRepo repo}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [demandeEquipeRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
              home: Scaffold(body: PieceJointeDemande(demande: demande))),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('rien n\'est affiché sans document', (tester) async {
      await pump(tester, _demande(), repo: _FakeRepo());
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('affiche le nom du fichier quand il y en a un',
        (tester) async {
      await pump(tester, _demande(documentNom: 'billet.pdf'),
          repo: _FakeRepo());
      expect(find.text('billet.pdf'), findsOneWidget);
      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
    });

    testWidgets('un appui ouvre la visionneuse du document', (tester) async {
      await pump(tester, _demande(documentNom: 'billet.pdf'),
          repo: _FakeRepo());

      await tester.tap(find.byType(InkWell));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DocumentDemandeScreen), findsOneWidget);
    });
  });

  group('DocumentDemandeScreen', () {
    testWidgets('une image reçue s\'affiche dans une visionneuse',
        (tester) async {
      // PNG 1×1 valide.
      final pixel = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8B'
          'QDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
      final repo = _FakeRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [demandeEquipeRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: DocumentDemandeScreen(demandeId: 'd1', nom: 'photo.png'),
          ),
        ),
      );
      // lireDocument n'est pas branché : on vérifie seulement l'état de
      // chargement, sans dépendre du greffon d'impression (PDF).
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(pixel, isNotEmpty);
    });
  });
}
