import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:web/web.dart' as web;

/// Partage natif réservé aux téléphones et tablettes : sur ordinateur, Chrome
/// ouvre la fenêtre de partage du système (Windows notamment), peu fiable et
/// inutile — l'app propose alors la copie du lien ou le téléchargement.
bool get _appareilMobile =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Le navigateur sait-il partager [donnees] (Web Share API) ?
bool _peutPartager(web.ShareData donnees) {
  if (!_appareilMobile) return false;
  try {
    return web.window.navigator.canShare(donnees);
  } catch (_) {
    return false; // canShare absent (ex. Firefox sur ordinateur)
  }
}

/// `true` si le partage a eu lieu ou a été annulé par l'utilisateur ;
/// `false` si le navigateur ne sait pas partager ou l'a REFUSÉ. Chrome refuse
/// (NotAllowedError) un partage qui n'est pas lancé juste après un clic : il
/// faut alors proposer un autre moyen (copie, téléchargement).
Future<bool> _partager(web.ShareData donnees) async {
  if (!_peutPartager(donnees)) return false;
  try {
    await web.window.navigator.share(donnees).toDart;
    return true;
  } catch (e) {
    return e.toString().contains('AbortError');
  }
}

web.File _fichier(Uint8List octets, String nom, String typeMime) => web.File(
      [octets.toJS].toJS,
      nom,
      web.FilePropertyBag(type: typeMime),
    );

Future<bool> partagerFichierNatif(
        Uint8List octets, String nom, String typeMime) =>
    _partager(web.ShareData(
        files: [_fichier(octets, nom, typeMime)].toJS, title: nom));

Future<bool> partagerLienNatif(String url, String titre) =>
    _partager(web.ShareData(url: url, title: titre));

/// Le partage natif d'un lien est-il disponible (pour afficher le bouton) ?
bool peutPartagerLienNatif() =>
    _peutPartager(web.ShareData(url: 'https://exemple.org', title: 'x'));

/// Le partage natif d'un fichier est-il disponible ?
bool peutPartagerFichierNatif(String typeMime) => _peutPartager(web.ShareData(
    files: [_fichier(Uint8List(1), 'x.pdf', typeMime)].toJS, title: 'x'));

/// Ouvre [url] dans un nouvel onglet.
bool ouvrirDansNouvelOnglet(String url) {
  web.window.open(url, '_blank');
  return true;
}

/// Navigue vers [url] dans l'onglet courant (ex. lien cleanops:// qui ouvre
/// l'application mobile installée).
bool ouvrirLienExterne(String url) {
  web.window.location.href = url;
  return true;
}

/// Navigateur de téléphone ou de tablette ?
bool get navigateurMobile => _appareilMobile;
