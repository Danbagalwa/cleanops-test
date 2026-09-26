import 'dart:async';

import 'package:cleanops/core/services/compression_photo.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';
import 'package:cleanops/features/photo_profil/domain/photo_profil_models.dart';
import 'package:cleanops/features/photo_profil/domain/photo_profil_repository.dart';
import 'package:cleanops/features/photo_profil/domain/selecteur_image.dart';
import 'package:cleanops/features/photo_profil/presentation/providers/photo_profil_provider.dart';
import 'package:cleanops/features/photo_profil/presentation/widgets/avatar_profil.dart';
import 'package:cleanops/features/photo_profil/presentation/widgets/photo_profil_editeur.dart';
import 'package:cleanops/features/profile/presentation/screens/profile_screen.dart';
import 'package:cleanops/features/resident_espace/presentation/widgets/tab_profil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _reception = Employee(
  id: 'r1',
  nom: 'Dab',
  prenom: 'Receptioniste',
  slug: 'receptioniste',
  role: RoleType.reception,
  isActif: true,
);

const _admin = Employee(
  id: 'a1',
  nom: 'Sylvestre',
  prenom: 'Nadine',
  slug: 'nadine',
  role: RoleType.admin,
  isActif: true,
);

const _resident = Employee(
  id: 'z1',
  nom: 'Tremblay',
  prenom: 'Jeanne',
  slug: 'jeanne',
  role: RoleType.resident,
  isActif: true,
  nomResidence: '101',
);

/// Un vrai JPEG minuscule : l'affichage peut le décoder sans erreur.
Uint8List _jpeg([int couleur = 120]) {
  final image = img.Image(width: 16, height: 16);
  img.fill(image, color: img.ColorRgb8(couleur, 60, 200));
  return img.encodeJpg(image);
}

PhotoCompressee _photo(
        {int taille = 28 * 1024, int original = 3 * 1024 * 1024}) =>
    PhotoCompressee(
      octets: Uint8List.fromList([..._jpeg(), ...List.filled(taille, 0)]),
      largeur: 320,
      hauteur: 320,
      qualite: 82,
      tailleOriginale: original,
    );

class _FauxRepo implements PhotoProfilRepository {
  Uint8List? photo;
  Object? erreurLire;
  Object? erreurDefinir;
  Object? erreurSupprimer;
  final definitions = <(ProprietairePhoto, PhotoCompressee)>[];
  final suppressions = <ProprietairePhoto>[];
  int lectures = 0;

  _FauxRepo({this.photo});

  @override
  Future<Uint8List?> lire(ProprietairePhoto proprietaire) async {
    lectures++;
    if (erreurLire != null) throw erreurLire!;
    return photo;
  }

  @override
  Future<void> definir(
      ProprietairePhoto proprietaire, PhotoCompressee p) async {
    if (erreurDefinir != null) throw erreurDefinir!;
    definitions.add((proprietaire, p));
    photo = p.octets;
  }

  @override
  Future<void> supprimer(ProprietairePhoto proprietaire) async {
    if (erreurSupprimer != null) throw erreurSupprimer!;
    suppressions.add(proprietaire);
    photo = null;
  }
}

class _FauxSelecteur implements SelecteurImage {
  Uint8List? retour = Uint8List.fromList([1, 2, 3]);
  Object? erreur;
  Completer<void>? attente;
  final sources = <SourcePhoto>[];

  @override
  Future<Uint8List?> choisir(SourcePhoto source) async {
    sources.add(source);
    if (attente != null) await attente!.future;
    if (erreur != null) throw erreur!;
    return retour;
  }
}

class _Contexte {
  final _FauxRepo repo;
  final _FauxSelecteur selecteur;
  final List<Uint8List> compressions;

  _Contexte(this.repo, this.selecteur, this.compressions);
}

Future<_Contexte> _afficher(
  WidgetTester tester, {
  required Widget enfant,
  _FauxRepo? repo,
  _FauxSelecteur? selecteur,
  Future<PhotoCompressee> Function(Uint8List)? compression,
  Employee employe = _admin,
  Size taille = const Size(900, 1200),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = taille;
  addTearDown(tester.view.reset);

  final r = repo ?? _FauxRepo();
  final s = selecteur ?? _FauxSelecteur();
  final compressions = <Uint8List>[];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        employeeCourantProvider.overrideWithValue(employe),
        photoProfilRepositoryProvider.overrideWithValue(r),
        selecteurImageProvider.overrideWithValue(s),
        compressionPhotoProvider.overrideWithValue((octets) async {
          compressions.add(octets);
          return compression != null ? await compression(octets) : _photo();
        }),
      ],
      child: MaterialApp(home: Scaffold(body: Center(child: enfant))),
    ),
  );
  await tester.pumpAndSettle();
  return _Contexte(r, s, compressions);
}

const _moi = ProprietairePhoto(TypeProprietairePhoto.employe, 'a1');

Widget _editeur() => const PhotoProfilEditeur(
      proprietaire: _moi,
      initiales: 'NS',
      couleurFond: Colors.red,
    );

Future<void> _ouvrirMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Modifier la photo'));
  await tester.pumpAndSettle();
}

Future<void> _choisirGalerie(WidgetTester tester) async {
  await _ouvrirMenu(tester);
  await tester.tap(find.text('Choisir dans la galerie'));
  await tester.pumpAndSettle();
}

void main() {
  group('Propriétaire d\'une photo', () {
    test('un employé, quel que soit son rôle, est de type « employe »', () {
      expect(ProprietairePhoto.de(_admin).type, TypeProprietairePhoto.employe);
      expect(
          ProprietairePhoto.de(_reception).type, TypeProprietairePhoto.employe);
      const preposee = Employee(
        id: 'p1',
        nom: 'F',
        prenom: 'E',
        slug: 'e',
        role: RoleType.employe,
        isActif: true,
      );
      expect(
          ProprietairePhoto.de(preposee).type, TypeProprietairePhoto.employe);
    });

    test('un résident est de type « resident »', () {
      final p = ProprietairePhoto.de(_resident);
      expect(p.type, TypeProprietairePhoto.resident);
      expect(p.id, 'z1');
    });

    test('valeurs envoyées au serveur', () {
      expect(TypeProprietairePhoto.employe.code, 'employe');
      expect(TypeProprietairePhoto.resident.code, 'resident');
    });

    test('égalité par valeur (clé de fournisseur)', () {
      const a = ProprietairePhoto(TypeProprietairePhoto.employe, 'x');
      const b = ProprietairePhoto(TypeProprietairePhoto.employe, 'x');
      const c = ProprietairePhoto(TypeProprietairePhoto.resident, 'x');
      const d = ProprietairePhoto(TypeProprietairePhoto.employe, 'y');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse, reason: 'même id, autre type');
      expect(a == d, isFalse);
    });
  });

  group('Avatar', () {
    testWidgets('sans photo : les initiales', (tester) async {
      await _afficher(
        tester,
        enfant: const AvatarProfil(
            proprietaire: _moi, initiales: 'NS', couleurFond: Colors.red),
      );

      expect(find.text('NS'), findsOneWidget);
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.foregroundImage, isNull);
    });

    testWidgets('initiales vides : un point d\'interrogation', (tester) async {
      await _afficher(
        tester,
        enfant: const AvatarProfil(
            proprietaire: _moi, initiales: '', couleurFond: Colors.red),
      );
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('avec photo : l\'image est affichée', (tester) async {
      final octets = _jpeg();
      await _afficher(
        tester,
        repo: _FauxRepo(photo: octets),
        enfant: const AvatarProfil(
            proprietaire: _moi, initiales: 'NS', couleurFond: Colors.red),
      );

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.foregroundImage, isA<MemoryImage>());
      expect((avatar.foregroundImage as MemoryImage).bytes, octets);
    });

    testWidgets('échec du chargement : les initiales, sans erreur à l\'écran',
        (tester) async {
      await _afficher(
        tester,
        repo: _FauxRepo()..erreurLire = const ErreurPhoto('Réseau coupé'),
        enfant: const AvatarProfil(
            proprietaire: _moi, initiales: 'NS', couleurFond: Colors.red),
      );

      expect(find.text('NS'), findsOneWidget);
      expect(find.text('Réseau coupé'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Choisir une nouvelle photo', () {
    testWidgets('le bouton « Modifier la photo » est proposé', (tester) async {
      await _afficher(tester, enfant: _editeur());
      expect(find.byTooltip('Modifier la photo'), findsOneWidget);
    });

    testWidgets('la galerie est toujours proposée', (tester) async {
      await _afficher(tester, enfant: _editeur());
      await _ouvrirMenu(tester);
      expect(find.text('Choisir dans la galerie'), findsOneWidget);
    });

    testWidgets('l\'appareil photo n\'est proposé que sur mobile',
        (tester) async {
      // (Dans flutter_test, la plateforme par défaut est Android : on force les
      // deux cas. La variable doit être remise à zéro AVANT la fin du test.)
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        await _afficher(tester, enfant: _editeur());
        await _ouvrirMenu(tester);
        expect(find.text('Prendre une photo'), findsNothing,
            reason: 'poste de bureau');

        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await tester.pumpWidget(const SizedBox());
        await _afficher(tester, enfant: _editeur());
        await _ouvrirMenu(tester);
        expect(find.text('Prendre une photo'), findsOneWidget,
            reason: 'téléphone Android');

        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        await tester.pumpWidget(const SizedBox());
        await _afficher(tester, enfant: _editeur());
        await _ouvrirMenu(tester);
        expect(find.text('Prendre une photo'), findsNothing, reason: 'Mac');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('« Prendre une photo » utilise l\'appareil', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final ctx = await _afficher(tester, enfant: _editeur());

        await _ouvrirMenu(tester);
        await tester.tap(find.text('Prendre une photo'));
        await tester.pumpAndSettle();

        expect(ctx.selecteur.sources, [SourcePhoto.appareil]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('« Supprimer la photo » seulement s\'il y a une photo',
        (tester) async {
      await _afficher(tester, enfant: _editeur());
      await _ouvrirMenu(tester);
      expect(find.text('Supprimer la photo'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await _afficher(tester,
          repo: _FauxRepo(photo: _jpeg()), enfant: _editeur());
      await _ouvrirMenu(tester);
      expect(find.text('Supprimer la photo'), findsOneWidget);
    });

    testWidgets('l\'image choisie est réduite AVANT tout envoi',
        (tester) async {
      final ctx = await _afficher(
        tester,
        selecteur: _FauxSelecteur()..retour = Uint8List.fromList([9, 8, 7]),
        enfant: _editeur(),
      );

      await _choisirGalerie(tester);

      expect(ctx.compressions, [
        Uint8List.fromList([9, 8, 7])
      ]);
      expect(ctx.repo.definitions, isEmpty,
          reason: 'rien n\'est envoyé avant la confirmation');
    });

    testWidgets('aperçu : l\'image réduite et sa taille', (tester) async {
      final photo = _photo();
      await _afficher(tester,
          enfant: _editeur(), compression: (_) async => photo);
      await _choisirGalerie(tester);

      expect(find.text('Votre nouvelle photo'), findsOneWidget);
      expect(find.text('Photo optimisée : ${photo.resume}'), findsOneWidget);
      expect(photo.resume, startsWith('320 × 320 px · 28,'));
      expect(photo.resume, endsWith('(original : 3 Mo)'));
    });

    testWidgets('l\'aperçu montre la photo RÉDUITE, pas l\'original',
        (tester) async {
      final reduite = _photo();
      await _afficher(tester,
          enfant: _editeur(), compression: (_) async => reduite);
      await _choisirGalerie(tester);

      final apercu = tester
          .widgetList<CircleAvatar>(find.byType(CircleAvatar))
          .firstWhere((a) => a.radius == 80);
      expect((apercu.backgroundImage as MemoryImage).bytes, reduite.octets);
    });

    testWidgets('enregistrer : la photo réduite part au serveur',
        (tester) async {
      final reduite = _photo();
      final ctx = await _afficher(tester,
          enfant: _editeur(), compression: (_) async => reduite);

      await _choisirGalerie(tester);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(ctx.repo.definitions, hasLength(1));
      expect(ctx.repo.definitions.single.$1, _moi);
      expect(ctx.repo.definitions.single.$2, reduite);
      expect(find.text('Photo de profil mise à jour.'), findsOneWidget);
    });

    testWidgets('l\'avatar affiche ensuite la nouvelle photo', (tester) async {
      final reduite = _photo();
      await _afficher(tester,
          enfant: _editeur(), compression: (_) async => reduite);

      await _choisirGalerie(tester);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect((avatar.foregroundImage as MemoryImage).bytes, reduite.octets);
    });

    testWidgets('annuler l\'aperçu n\'enregistre rien', (tester) async {
      final ctx = await _afficher(tester, enfant: _editeur());

      await _choisirGalerie(tester);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(ctx.repo.definitions, isEmpty);
      expect(find.text('Photo de profil mise à jour.'), findsNothing);
    });

    testWidgets(
        '« remplacera votre photo actuelle » seulement s\'il y en a '
        'une', (tester) async {
      await _afficher(tester, enfant: _editeur());
      await _choisirGalerie(tester);
      expect(find.text('Elle remplacera votre photo actuelle.'), findsNothing);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await _afficher(tester,
          repo: _FauxRepo(photo: _jpeg()), enfant: _editeur());
      await _choisirGalerie(tester);
      expect(
          find.text('Elle remplacera votre photo actuelle.'), findsOneWidget);
    });

    testWidgets('l\'utilisateur annule le choix : rien ne se passe',
        (tester) async {
      final ctx = await _afficher(
        tester,
        selecteur: _FauxSelecteur()..retour = null,
        enfant: _editeur(),
      );

      await _choisirGalerie(tester);

      expect(ctx.compressions, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(ctx.repo.definitions, isEmpty);
    });
  });

  group('Erreurs', () {
    testWidgets(
        'image trop volumineuse ou illisible : message clair, rien '
        'n\'est envoyé', (tester) async {
      final ctx = await _afficher(
        tester,
        enfant: _editeur(),
        compression: (_) async => throw const ErreurPhoto(
            'Cette image est trop volumineuse (15 Mo au maximum).'),
      );

      await _choisirGalerie(tester);

      expect(find.text('Cette image est trop volumineuse (15 Mo au maximum).'),
          findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(ctx.repo.definitions, isEmpty);
    });

    testWidgets('le sélecteur échoue : message clair', (tester) async {
      await _afficher(
        tester,
        selecteur: _FauxSelecteur()
          ..erreur = const ErreurPhoto("Impossible d'ouvrir l'image choisie."),
        enfant: _editeur(),
      );

      await _choisirGalerie(tester);

      expect(find.text("Impossible d'ouvrir l'image choisie."), findsOneWidget);
    });

    testWidgets('le serveur refuse l\'enregistrement : message clair',
        (tester) async {
      await _afficher(
        tester,
        repo: _FauxRepo()
          ..erreurDefinir = const ErreurPhoto(
              'La photo est trop volumineuse (96 Ko au maximum).'),
        enfant: _editeur(),
      );

      await _choisirGalerie(tester);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('La photo est trop volumineuse (96 Ko au maximum).'),
          findsOneWidget);
      expect(find.text('Photo de profil mise à jour.'), findsNothing);
    });

    testWidgets('après une erreur, on peut réessayer', (tester) async {
      final repo = _FauxRepo()..erreurDefinir = const ErreurPhoto('Coupure');
      await _afficher(tester, repo: repo, enfant: _editeur());

      await _choisirGalerie(tester);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Coupure'), findsOneWidget);

      repo.erreurDefinir = null;
      await _choisirGalerie(tester);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(repo.definitions, hasLength(1));
    });
  });

  group('Traitement en cours', () {
    testWidgets('un indicateur s\'affiche pendant le choix et la réduction',
        (tester) async {
      final selecteur = _FauxSelecteur()..attente = Completer<void>();
      await _afficher(tester, selecteur: selecteur, enfant: _editeur());

      await _ouvrirMenu(tester);
      await tester.tap(find.text('Choisir dans la galerie'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      selecteur.attente!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('on ne peut pas relancer pendant le traitement',
        (tester) async {
      final selecteur = _FauxSelecteur()..attente = Completer<void>();
      final ctx =
          await _afficher(tester, selecteur: selecteur, enfant: _editeur());

      await _ouvrirMenu(tester);
      await tester.tap(find.text('Choisir dans la galerie'));
      // Laisse la fenêtre du menu finir de se fermer (l'indicateur, lui, tourne
      // sans fin : pas de pumpAndSettle).
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byTooltip('Modifier la photo'),
          warnIfMissed: false);
      await tester.pump();
      expect(find.text('Choisir dans la galerie'), findsNothing,
          reason: 'le menu ne se rouvre pas pendant le traitement');

      selecteur.attente!.complete();
      await tester.pumpAndSettle();
      expect(ctx.selecteur.sources, hasLength(1));
    });
  });

  group('Supprimer la photo', () {
    testWidgets('confirmation, puis suppression', (tester) async {
      final ctx = await _afficher(tester,
          repo: _FauxRepo(photo: _jpeg()), enfant: _editeur());

      await _ouvrirMenu(tester);
      await tester.tap(find.text('Supprimer la photo'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer la photo de profil ?'), findsOneWidget);
      expect(ctx.repo.suppressions, isEmpty, reason: 'rien avant confirmation');

      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(ctx.repo.suppressions, [_moi]);
      expect(find.text('Photo supprimée.'), findsOneWidget);
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.foregroundImage, isNull, reason: 'retour aux initiales');
    });

    testWidgets('annuler la suppression garde la photo', (tester) async {
      final ctx = await _afficher(tester,
          repo: _FauxRepo(photo: _jpeg()), enfant: _editeur());

      await _ouvrirMenu(tester);
      await tester.tap(find.text('Supprimer la photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(ctx.repo.suppressions, isEmpty);
      expect(ctx.repo.photo, isNotNull);
    });

    testWidgets('une erreur du serveur s\'affiche', (tester) async {
      await _afficher(
        tester,
        repo: _FauxRepo(photo: _jpeg())
          ..erreurSupprimer =
              const ErreurPhoto("La photo n'a pas pu être supprimée."),
        enfant: _editeur(),
      );

      await _ouvrirMenu(tester);
      await tester.tap(find.text('Supprimer la photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text("La photo n'a pas pu être supprimée."), findsOneWidget);
      expect(find.text('Photo supprimée.'), findsNothing);
    });
  });

  group('Dans les écrans de profil', () {
    testWidgets('« Mon profil » d\'un responsable', (tester) async {
      await _afficher(tester,
          enfant:
              const SizedBox(width: 700, height: 900, child: ProfileScreen()));

      expect(find.byTooltip('Modifier la photo'), findsOneWidget);
      expect(find.text('NS'), findsOneWidget);
    });

    testWidgets('« Mon profil » de la Réception aussi', (tester) async {
      await _afficher(tester,
          employe: _reception,
          enfant:
              const SizedBox(width: 700, height: 900, child: ProfileScreen()));

      expect(find.byTooltip('Modifier la photo'), findsOneWidget);
    });

    testWidgets('la photo d\'un employé est lue avec son propre identifiant',
        (tester) async {
      final ctx = await _afficher(tester,
          repo: _FauxRepo(photo: _jpeg()),
          enfant:
              const SizedBox(width: 700, height: 900, child: ProfileScreen()));

      expect(ctx.repo.lectures, greaterThan(0));
      final avatar =
          tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
      expect(avatar.foregroundImage, isA<MemoryImage>());
    });

    testWidgets('profil d\'un résident', (tester) async {
      await _afficher(tester,
          employe: _resident,
          enfant: const SizedBox(
              width: 700, height: 900, child: TabProfil(employee: _resident)));

      expect(find.byTooltip('Modifier la photo'), findsOneWidget);
    });

    testWidgets(
        'résident : la photo est enregistrée comme celle d\'un '
        'RÉSIDENT', (tester) async {
      final ctx = await _afficher(tester,
          employe: _resident,
          enfant: const SizedBox(
              width: 700, height: 900, child: TabProfil(employee: _resident)));

      await _choisirGalerie(tester);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(ctx.repo.definitions.single.$1,
          const ProprietairePhoto(TypeProprietairePhoto.resident, 'z1'));
    });

    testWidgets(
        'employé : la photo est enregistrée comme celle d\'un '
        'EMPLOYÉ', (tester) async {
      final ctx = await _afficher(tester,
          enfant:
              const SizedBox(width: 700, height: 900, child: ProfileScreen()));

      await _choisirGalerie(tester);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(ctx.repo.definitions.single.$1,
          const ProprietairePhoto(TypeProprietairePhoto.employe, 'a1'));
    });

    testWidgets('sur mobile', (tester) async {
      await _afficher(tester,
          taille: const Size(420, 900),
          enfant:
              const SizedBox(width: 400, height: 800, child: ProfileScreen()));

      expect(find.byTooltip('Modifier la photo'), findsOneWidget);
    });
  });
}
