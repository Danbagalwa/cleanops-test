import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:image/image.dart' as img;

/// Réglages de la réduction d'une photo de profil.
///
/// Une photo de profil s'affiche en petit (quelques dizaines de pixels, au plus
/// quelques centaines) : garder l'original de plusieurs Mo n'apporterait rien et
/// remplirait le stockage. L'image est donc recadrée en carré, réduite, puis
/// compressée en JPEG jusqu'à passer sous une taille cible.
class ParametresPhoto {
  /// Côté du carré de départ, en pixels. Jamais agrandi : une image plus petite
  /// garde sa taille.
  final int coteMax;

  /// Côté en dessous duquel on ne réduit plus (au-delà, la photo serait floue).
  final int coteMin;

  /// Qualité JPEG de départ, puis plancher, et pas de descente (1 à 100).
  final int qualiteInitiale;
  final int qualiteMin;
  final int pasQualite;

  /// Qualité de reprise après une réduction du côté (on repart moins haut pour
  /// converger plus vite).
  final int qualiteReprise;

  /// Taille visée. On descend en qualité, puis en dimensions, jusqu'à passer
  /// dessous.
  final int tailleCible;

  /// Taille à ne JAMAIS dépasser : au-delà, la photo est refusée.
  final int tailleMaxAbsolue;

  /// Image d'origine refusée au-delà de cette taille (protège la mémoire).
  final int tailleMaxEntree;

  /// Côté minimal de l'image d'origine : plus petite, elle serait inutilisable.
  final int coteMinEntree;

  const ParametresPhoto({
    this.coteMax = 320,
    this.coteMin = 128,
    this.qualiteInitiale = 82,
    this.qualiteMin = 40,
    this.pasQualite = 6,
    this.qualiteReprise = 70,
    this.tailleCible = 40 * 1024,
    this.tailleMaxAbsolue = 64 * 1024,
    this.tailleMaxEntree = 15 * 1024 * 1024,
    this.coteMinEntree = 96,
  });
}

/// Photo réduite, prête à être envoyée.
class PhotoCompressee {
  /// Octets JPEG.
  final Uint8List octets;
  final int largeur;
  final int hauteur;

  /// Qualité JPEG finalement retenue.
  final int qualite;

  /// Taille de l'image d'origine, en octets.
  final int tailleOriginale;

  const PhotoCompressee({
    required this.octets,
    required this.largeur,
    required this.hauteur,
    required this.qualite,
    required this.tailleOriginale,
  });

  int get taille => octets.length;

  /// « 320 × 320 px · 28,4 Ko (original : 3,4 Mo) ».
  String get resume => '$largeur × $hauteur px · ${formaterTaille(taille)} '
      "(original : ${formaterTaille(tailleOriginale)})";
}

/// Erreur affichable telle quelle à l'utilisateur.
class ErreurPhoto implements Exception {
  final String message;

  const ErreurPhoto(this.message);

  @override
  String toString() => message;
}

/// « 512 o », « 28,4 Ko », « 3,4 Mo » (virgule décimale).
String formaterTaille(int octets) {
  String un(double v) =>
      v.toStringAsFixed(1).replaceAll('.', ',').replaceAll(RegExp(r',0$'), '');
  if (octets < 1024) return '$octets o';
  if (octets < 1024 * 1024) return '${un(octets / 1024)} Ko';
  return '${un(octets / (1024 * 1024))} Mo';
}

/// Image décodée : pixels RGBA, 4 octets par pixel.
class PhotoRaster {
  final int largeur;
  final int hauteur;
  final Uint8List rgba;

  const PhotoRaster({
    required this.largeur,
    required this.hauteur,
    required this.rgba,
  });
}

/// Décode une image d'origine en pixels, DÉJÀ réduite pour que son petit côté
/// vaille au plus `coteMax`. Séparé pour pouvoir être remplacé dans les tests.
typedef DecodeurPhoto = Future<PhotoRaster> Function(
  Uint8List octets,
  int coteMax,
  ParametresPhoto parametres,
);

/// Réduit une photo de profil : décodage réduit, recadrage carré centré,
/// puis compression JPEG jusqu'à passer sous la taille cible.
abstract final class CompresseurPhoto {
  /// Point d'entrée. Lève [ErreurPhoto] (message affichable) si l'image est
  /// illisible, trop volumineuse, trop petite ou impossible à réduire assez.
  static Future<PhotoCompressee> compresser(
    Uint8List entree, {
    ParametresPhoto parametres = const ParametresPhoto(),
    DecodeurPhoto decodeur = decoderAvecMoteur,
  }) async {
    if (entree.isEmpty) {
      throw const ErreurPhoto("Ce fichier est vide.");
    }
    if (entree.length > parametres.tailleMaxEntree) {
      throw ErreurPhoto(
        'Cette image est trop volumineuse '
        '(${formaterTaille(parametres.tailleMaxEntree)} au maximum).',
      );
    }

    final PhotoRaster raster;
    try {
      raster = await decodeur(entree, parametres.coteMax, parametres);
    } on ErreurPhoto {
      rethrow;
    } on UnsupportedError catch (e) {
      // Ce n'est pas la faute du fichier : la plateforme ne sait pas faire. On ne
      // le déguise pas en « image illisible ».
      debugPrint('CompresseurPhoto : plateforme non supportée : $e');
      throw const ErreurPhoto(
        "Le traitement des images n'est pas disponible sur cet appareil.",
      );
    } catch (e) {
      // Garde la vraie cause dans la console (elle était auparavant perdue).
      debugPrint('CompresseurPhoto : décodage impossible : $e');
      throw const ErreurPhoto("Ce fichier n'est pas une image lisible.");
    }

    return reduire(raster, parametres, tailleOriginale: entree.length);
  }

  /// Recadre en carré, puis compresse. Partie « pure » de l'algorithme.
  static PhotoCompressee reduire(
    PhotoRaster raster,
    ParametresPhoto p, {
    required int tailleOriginale,
  }) {
    final courtCote = math.min(raster.largeur, raster.hauteur);
    if (courtCote < p.coteMinEntree) {
      throw ErreurPhoto(
        'Cette image est trop petite (${p.coteMinEntree} pixels au minimum).',
      );
    }

    final carre = _recadrerEnCarre(raster);
    var cote = math.min(carre.width, p.coteMax);
    var qualite = p.qualiteInitiale;

    Uint8List? encodage;
    var coteEncode = cote;
    var qualiteEncodee = qualite;

    while (true) {
      final image = cote == carre.width
          ? carre
          : img.copyResize(
              carre,
              width: cote,
              height: cote,
              interpolation: img.Interpolation.average,
            );
      encodage = img.encodeJpg(image, quality: qualite);
      coteEncode = cote;
      qualiteEncodee = qualite;

      if (encodage.length <= p.tailleCible) break;

      // 1. on baisse d'abord la qualité…
      if (qualite - p.pasQualite >= p.qualiteMin) {
        qualite -= p.pasQualite;
        continue;
      }
      // 2. …puis les dimensions…
      final reduit = (cote * 0.85).floor();
      if (reduit >= p.coteMin) {
        cote = reduit;
        qualite = p.qualiteReprise;
        continue;
      }
      // 3. …jusqu'au plancher.
      break;
    }

    if (encodage.length > p.tailleMaxAbsolue) {
      throw ErreurPhoto(
        "Cette image ne peut pas être réduite assez "
        "(${formaterTaille(p.tailleMaxAbsolue)} au maximum). Essayez-en une autre.",
      );
    }

    return PhotoCompressee(
      octets: encodage,
      largeur: coteEncode,
      hauteur: coteEncode,
      qualite: qualiteEncodee,
      tailleOriginale: tailleOriginale,
    );
  }

  /// Carré centré, sur fond blanc (une image transparente ne devient pas noire
  /// en JPEG).
  static img.Image _recadrerEnCarre(PhotoRaster raster) {
    final source = img.Image.fromBytes(
      width: raster.largeur,
      height: raster.hauteur,
      bytes: raster.rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    final cote = math.min(raster.largeur, raster.hauteur);
    final x = (raster.largeur - cote) ~/ 2;
    final y = (raster.hauteur - cote) ~/ 2;
    final recadre = img.copyCrop(source, x: x, y: y, width: cote, height: cote);

    final fond = img.Image(width: cote, height: cote, numChannels: 4);
    img.fill(fond, color: img.ColorRgba8(255, 255, 255, 255));
    return img.compositeImage(fond, recadre);
  }

  /// Décodage par le moteur graphique de Flutter, DIRECTEMENT à taille réduite :
  /// une photo de 12 mégapixels ne devient jamais une image de 48 Mo en mémoire,
  /// et ce n'est pas du Dart qui fait le travail, donc l'écran ne se fige pas.
  ///
  /// Fonctionne sur TOUTES les plateformes, navigateur compris. (Une première
  /// version lisait les dimensions par `ImageDescriptor`, dont `width` et
  /// `height` n'existent PAS sur le web : toute image échouait dans le navigateur.)
  ///
  /// On ne connaît pas les dimensions avant de décoder, donc :
  ///  1. décodage avec la LARGEUR ramenée à 2 × `coteMax` (les proportions sont
  ///     conservées, jamais d'agrandissement) : au plus deux fois le côté final ;
  ///  2. cas d'un panorama (paysage très allongé) dont le petit côté deviendrait
  ///     trop petit : second décodage, cette fois avec la HAUTEUR ramenée à
  ///     `coteMax`.
  static Future<PhotoRaster> decoderAvecMoteur(
    Uint8List octets,
    int coteMax,
    ParametresPhoto parametres,
  ) async {
    final largeurCible = coteMax * 2;
    var raster = await _decoderReduit(octets, largeur: largeurCible);

    final panoramaReduit = raster.largeur > raster.hauteur &&
        raster.largeur >= largeurCible &&
        raster.hauteur < coteMax;
    if (panoramaReduit) {
      raster = await _decoderReduit(octets, hauteur: coteMax);
    }
    return raster;
  }

  /// Décode l'image en imposant UNE dimension (l'autre suit les proportions),
  /// sans jamais agrandir.
  static Future<PhotoRaster> _decoderReduit(
    Uint8List octets, {
    int? largeur,
    int? hauteur,
  }) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(
        octets,
        targetWidth: largeur,
        targetHeight: hauteur,
        allowUpscaling: false,
      );
      image = (await codec.getNextFrame()).image;
      final donnees = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (donnees == null) {
        throw const ErreurPhoto("Ce fichier n'est pas une image lisible.");
      }
      return PhotoRaster(
        largeur: image.width,
        hauteur: image.height,
        // Vue exacte des pixels (et non le tampon entier, qui peut être plus
        // grand ou décalé selon la plateforme).
        rgba: Uint8List.fromList(donnees.buffer
            .asUint8List(donnees.offsetInBytes, donnees.lengthInBytes)),
      );
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}
