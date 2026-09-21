import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cleanops/core/services/compression_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Dégradé lisse : se compresse très bien (comme une vraie photo).
PhotoRaster _degrade(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      px[i] = (x * 255 ~/ w);
      px[i + 1] = (y * 255 ~/ h);
      px[i + 2] = 128;
      px[i + 3] = 255;
    }
  }
  return PhotoRaster(largeur: w, hauteur: h, rgba: px);
}

/// Bruit pur : le PIRE cas pour la compression JPEG.
PhotoRaster _bruit(int w, int h, {int graine = 7}) {
  final hasard = math.Random(graine);
  final px = Uint8List(w * h * 4);
  for (var i = 0; i < px.length; i += 4) {
    px[i] = hasard.nextInt(256);
    px[i + 1] = hasard.nextInt(256);
    px[i + 2] = hasard.nextInt(256);
    px[i + 3] = 255;
  }
  return PhotoRaster(largeur: w, hauteur: h, rgba: px);
}

/// Moitié gauche rouge, moitié droite bleue.
PhotoRaster _rougeEtBleu(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final gauche = x < w ~/ 2;
      px[i] = gauche ? 230 : 20;
      px[i + 1] = 20;
      px[i + 2] = gauche ? 20 : 230;
      px[i + 3] = 255;
    }
  }
  return PhotoRaster(largeur: w, hauteur: h, rgba: px);
}

PhotoRaster _transparent(int w, int h) => PhotoRaster(
      largeur: w,
      hauteur: h,
      rgba: Uint8List(w * h * 4), // tout à zéro : noir totalement transparent
    );

Uint8List _png(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgb(x, y, x * 255 ~/ w, y * 255 ~/ h, 128);
    }
  }
  return img.encodePng(image);
}

bool _estJpeg(Uint8List o) =>
    o.length > 3 && o[0] == 0xFF && o[1] == 0xD8 && o[2] == 0xFF;

PhotoCompressee _reduire(PhotoRaster r,
        {ParametresPhoto p = const ParametresPhoto(), int original = 1000000}) =>
    CompresseurPhoto.reduire(r, p, tailleOriginale: original);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formaterTaille', () {
    test('octets, kilo-octets et méga-octets, virgule décimale', () {
      expect(formaterTaille(512), '512 o');
      expect(formaterTaille(1024), '1 Ko');
      expect(formaterTaille(28 * 1024 + 410), '28,4 Ko');
      expect(formaterTaille(1024 * 1024), '1 Mo');
      expect(formaterTaille((3.4 * 1024 * 1024).round()), '3,4 Mo');
    });
  });

  group('Réduction d\'une photo (partie pure de l\'algorithme)', () {
    test('une grande photo devient un petit carré JPEG sous la taille cible', () {
      final r = _reduire(_degrade(2000, 1500));

      expect(_estJpeg(r.octets), isTrue);
      expect(r.largeur, r.hauteur, reason: 'carré');
      expect(r.largeur, lessThanOrEqualTo(320));
      expect(r.taille, lessThanOrEqualTo(40 * 1024));

      final relue = img.decodeJpg(r.octets)!;
      expect(relue.width, r.largeur);
      expect(relue.height, r.hauteur);
    });

    test('une photo qui se compresse bien garde la meilleure qualité', () {
      final r = _reduire(_degrade(1200, 900));
      expect(r.qualite, 82);
      expect(r.largeur, 320, reason: 'pas de réduction inutile');
    });

    test('le côté du carré est celui du petit côté, sans agrandissement', () {
      final r = _reduire(_degrade(200, 150));
      expect(r.largeur, 150);
      expect(r.hauteur, 150);
    });

    test('le recadrage est CENTRÉ, pas étiré', () {
      // 600 × 300 : le carré central couvre x de 150 à 450.
      final r = _reduire(_rougeEtBleu(600, 300));
      final j = img.decodeJpg(r.octets)!;

      final gauche = j.getPixel(8, j.height ~/ 2);
      final droite = j.getPixel(j.width - 9, j.height ~/ 2);
      expect(gauche.r, greaterThan(150));
      expect(gauche.b, lessThan(100));
      expect(droite.b, greaterThan(150));
      expect(droite.r, lessThan(100));
    });

    test('une image transparente devient blanche, pas noire', () {
      final r = _reduire(_transparent(400, 400));
      final j = img.decodeJpg(r.octets)!;
      final p = j.getPixel(j.width ~/ 2, j.height ~/ 2);
      expect(p.r, greaterThan(240));
      expect(p.g, greaterThan(240));
      expect(p.b, greaterThan(240));
    });

    test('le pire cas (bruit pur) passe quand même sous la taille cible',
        () {
      final r = _reduire(_bruit(1500, 1500));

      expect(r.taille, lessThanOrEqualTo(40 * 1024));
      // Pour y arriver, l'algorithme a dû baisser qualité et/ou dimensions.
      expect(r.qualite < 82 || r.largeur < 320, isTrue);
      expect(r.largeur, greaterThanOrEqualTo(128), reason: 'plancher');
    });

    test('la qualité baisse AVANT les dimensions', () {
      // Une cible un peu plus serrée que le résultat à pleine qualité : baisser
      // la qualité seule doit suffire.
      final image = _degrade(1200, 900);
      final pleine = _reduire(image);
      final cible = (pleine.taille * 0.85).floor();
      final r = _reduire(image, p: ParametresPhoto(tailleCible: cible));

      expect(r.taille, lessThanOrEqualTo(cible));
      expect(r.largeur, 320, reason: 'les dimensions sont préservées d\'abord');
      expect(r.qualite, lessThan(82));
    });

    test('les dimensions ne baissent qu\'après le plancher de qualité', () {
      // Très serré : la qualité ne suffit pas, il faut réduire le côté.
      const p = ParametresPhoto(tailleCible: 6 * 1024);
      final r = _reduire(_bruit(1000, 1000), p: p);
      expect(r.largeur, lessThan(320));
    });

    test('impossible à réduire assez : refus clair', () {
      const p = ParametresPhoto(tailleCible: 500, tailleMaxAbsolue: 1024);
      expect(
        () => _reduire(_bruit(800, 800), p: p),
        throwsA(isA<ErreurPhoto>().having((e) => e.message, 'message',
            contains('ne peut pas être réduite'))),
      );
    });

    test('image d\'origine trop petite : refus clair', () {
      expect(
        () => _reduire(_degrade(80, 80)),
        throwsA(isA<ErreurPhoto>()
            .having((e) => e.message, 'message', contains('trop petite'))),
      );
    });

    test('le résumé décrit le résultat et l\'original', () {
      final r = _reduire(_degrade(1200, 900), original: 3 * 1024 * 1024);
      expect(r.resume, contains('× ${r.hauteur} px'));
      expect(r.resume, contains('original : 3 Mo'));
    });

    test('déterministe : même image, même résultat', () {
      final a = _reduire(_bruit(700, 700, graine: 3));
      final b = _reduire(_bruit(700, 700, graine: 3));
      expect(a.octets, b.octets);
    });
  });

  group('Entrées refusées avant tout traitement', () {
    test('fichier vide', () {
      expect(
        () => CompresseurPhoto.compresser(Uint8List(0)),
        throwsA(isA<ErreurPhoto>()
            .having((e) => e.message, 'message', contains('vide'))),
      );
    });

    test('image d\'origine trop volumineuse (15 Mo)', () {
      expect(
        () => CompresseurPhoto.compresser(Uint8List(15 * 1024 * 1024 + 1)),
        throwsA(isA<ErreurPhoto>()
            .having((e) => e.message, 'message', contains('trop volumineuse'))),
      );
    });

    test('le décodeur n\'est pas appelé quand l\'entrée est refusée', () async {
      var appels = 0;
      try {
        await CompresseurPhoto.compresser(
          Uint8List(0),
          decodeur: (_, __, ___) async {
            appels++;
            return _degrade(200, 200);
          },
        );
      } on ErreurPhoto {
        // attendu
      }
      expect(appels, 0);
    });

    test('un décodeur qui échoue : « pas une image lisible »', () {
      expect(
        () => CompresseurPhoto.compresser(
          Uint8List.fromList([1, 2, 3]),
          decodeur: (_, __, ___) async => throw StateError('boom'),
        ),
        throwsA(isA<ErreurPhoto>().having(
            (e) => e.message, 'message', contains("pas une image lisible"))),
      );
    });

    test('un message d\'erreur du décodeur est conservé', () {
      expect(
        () => CompresseurPhoto.compresser(
          Uint8List.fromList([1, 2, 3]),
          decodeur: (_, __, ___) async =>
              throw const ErreurPhoto('Message précis'),
        ),
        throwsA(isA<ErreurPhoto>()
            .having((e) => e.message, 'message', 'Message précis')),
      );
    });

    test('le décodeur reçoit le côté maximal et la taille d\'origine est '
        'conservée', () async {
      int? coteRecu;
      final entree = Uint8List.fromList(List.filled(5000, 1));
      final r = await CompresseurPhoto.compresser(
        entree,
        decodeur: (o, cote, _) async {
          coteRecu = cote;
          return _degrade(900, 900);
        },
      );
      expect(coteRecu, 320);
      expect(r.tailleOriginale, 5000);
    });
  });

  group('Décodage réel par le moteur graphique', () {
    testWidgets('un PNG de 1200 × 900 devient un carré de 320 px', (tester) async {
      final png = _png(1200, 900);
      await tester.runAsync(() async {
        final r = await CompresseurPhoto.compresser(png);

        expect(_estJpeg(r.octets), isTrue);
        expect(r.largeur, 320);
        expect(r.hauteur, 320);
        expect(r.taille, lessThanOrEqualTo(40 * 1024));
        expect(r.tailleOriginale, png.length);
      });
    });

    testWidgets('un JPEG est accepté aussi', (tester) async {
      final image = img.Image(width: 800, height: 800);
      img.fill(image, color: img.ColorRgb8(30, 120, 200));
      final jpg = img.encodeJpg(image, quality: 95);
      await tester.runAsync(() async {
        final r = await CompresseurPhoto.compresser(jpg);
        expect(_estJpeg(r.octets), isTrue);
        expect(r.largeur, 320);
      });
    });

    testWidgets('une petite image n\'est pas agrandie', (tester) async {
      final png = _png(180, 120);
      await tester.runAsync(() async {
        final r = await CompresseurPhoto.compresser(png);
        expect(r.largeur, 120, reason: 'le petit côté d\'origine');
      });
    });

    testWidgets('une image trop petite est refusée', (tester) async {
      final png = _png(50, 50);
      await tester.runAsync(() async {
        await expectLater(
          CompresseurPhoto.compresser(png),
          throwsA(isA<ErreurPhoto>()
              .having((e) => e.message, 'message', contains('trop petite'))),
        );
      });
    });

    testWidgets('un fichier qui n\'est pas une image est refusé',
        (tester) async {
      final texte = Uint8List.fromList('ceci n\'est pas une image'.codeUnits);
      await tester.runAsync(() async {
        await expectLater(
          CompresseurPhoto.compresser(texte),
          throwsA(isA<ErreurPhoto>().having(
              (e) => e.message, 'message', contains('pas une image lisible'))),
        );
      });
    });

    testWidgets('une vraie photo (détaillée) est réduite fortement',
        (tester) async {
      // Dégradé + grain : proche d'une photo, l'original pèse plusieurs
      // centaines de Ko.
      final hasard = math.Random(11);
      final image = img.Image(width: 1600, height: 1200);
      for (var y = 0; y < 1200; y++) {
        for (var x = 0; x < 1600; x++) {
          int c(int base) => (base + hasard.nextInt(41) - 20).clamp(0, 255);
          image.setPixelRgb(x, y, c(x * 255 ~/ 1600), c(y * 255 ~/ 1200), c(128));
        }
      }
      final original = img.encodeJpg(image, quality: 95);
      expect(original.length, greaterThan(300 * 1024),
          reason: 'l\'original doit être volumineux pour que le test compte');

      await tester.runAsync(() async {
        final r = await CompresseurPhoto.compresser(original);
        expect(r.taille, lessThanOrEqualTo(40 * 1024));
        expect(r.taille, lessThan(original.length ~/ 8),
            reason: 'beaucoup plus petite que l\'original');
      });
    });

    testWidgets('un panorama (très allongé) donne quand même un carré de '
        '320 px', (tester) async {
      // 3000 × 500 : décodé à 640 px de large, il ne ferait que 107 px de haut.
      // Un second décodage, par la hauteur, évite une photo minuscule.
      final image = img.Image(width: 3000, height: 500);
      img.fill(image, color: img.ColorRgb8(90, 140, 210));
      final jpg = img.encodeJpg(image, quality: 90);
      await tester.runAsync(() async {
        final r = await CompresseurPhoto.compresser(jpg);
        expect(r.largeur, 320);
        expect(r.hauteur, 320);
      });
    });

    testWidgets('un portrait très haut donne un carré de 320 px',
        (tester) async {
      final image = img.Image(width: 600, height: 3000);
      img.fill(image, color: img.ColorRgb8(90, 140, 210));
      final jpg = img.encodeJpg(image, quality: 90);
      await tester.runAsync(() async {
        final r = await CompresseurPhoto.compresser(jpg);
        expect(r.largeur, 320);
      });
    });

    testWidgets('les COULEURS sont respectées (pas de canaux inversés)',
        (tester) async {
      final image = img.Image(width: 800, height: 800);
      img.fill(image, color: img.ColorRgb8(210, 40, 40)); // rouge franc
      final png = img.encodePng(image);
      await tester.runAsync(() async {
        final r = await CompresseurPhoto.compresser(png);
        final p = img.decodeJpg(r.octets)!.getPixel(160, 160);
        expect(p.r, greaterThan(180));
        expect(p.g, lessThan(80));
        expect(p.b, lessThan(80));
      });
    });

    testWidgets('un JPEG progressif de téléphone est accepté', (tester) async {
      // Le format de la photo qui a révélé le défaut du navigateur.
      final image = img.Image(width: 1100, height: 1280);
      img.fill(image, color: img.ColorRgb8(150, 120, 90));
      final jpg = img.JpegEncoder(quality: 90).encode(image);
      await tester.runAsync(() async {
        final r = await CompresseurPhoto.compresser(jpg);
        expect(r.largeur, 320);
        expect(r.taille, lessThanOrEqualTo(40 * 1024));
      });
    });
  });

  group('Compatibilité navigateur', () {
    // Ces tests tournent sur le moteur « bureau », où ImageDescriptor.width
    // fonctionne. Sur le WEB, il lève « ImageDescriptor.width is not supported on
    // web » et toute image échouait. Le défaut ne peut donc pas être vu ici : on
    // interdit l'API fautive dans la source, et le décodage a été vérifié à la
    // main dans un vrai navigateur (voir le rapport).
    test('le décodeur n\'utilise aucune API d\'ImageDescriptor', () {
      final source = File('lib/core/services/compression_photo.dart')
          .readAsStringSync();
      final code = source
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      expect(code, isNot(contains('ImageDescriptor')));
      expect(code, isNot(contains('ImmutableBuffer')));
      expect(code, contains('instantiateImageCodec'));
    });

    test('la source n\'utilise pas dart:io (absent du web)', () {
      final source = File('lib/core/services/compression_photo.dart')
          .readAsStringSync();
      expect(source, isNot(contains("import 'dart:io'")));
    });
  });

  group('Erreurs du décodage', () {
    test('une plateforme qui ne sait pas décoder n\'est pas déguisée en '
        '« image illisible »', () {
      expect(
        () => CompresseurPhoto.compresser(
          Uint8List.fromList([1, 2, 3]),
          decodeur: (_, __, ___) async =>
              throw UnsupportedError('pas sur le web'),
        ),
        throwsA(isA<ErreurPhoto>().having((e) => e.message, 'message',
            contains("pas disponible sur cet appareil"))),
      );
    });

    test('un autre échec de décodage reste « image illisible »', () {
      expect(
        () => CompresseurPhoto.compresser(
          Uint8List.fromList([1, 2, 3]),
          decodeur: (_, __, ___) async => throw const FormatException('x'),
        ),
        throwsA(isA<ErreurPhoto>().having(
            (e) => e.message, 'message', contains("pas une image lisible"))),
      );
    });
  });
}
