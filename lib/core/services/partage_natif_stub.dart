import 'dart:typed_data';

/// Hors navigateur : pas de Web Share API.
Future<bool> partagerFichierNatif(
        Uint8List octets, String nom, String typeMime) async =>
    false;

Future<bool> partagerLienNatif(String url, String titre) async => false;

bool peutPartagerLienNatif() => false;

bool peutPartagerFichierNatif(String typeMime) => false;

bool ouvrirDansNouvelOnglet(String url) => false;

/// Navigue vers [url] (ex. lien cleanops:// qui ouvre l'application).
bool ouvrirLienExterne(String url) => false;

/// Navigateur de téléphone ou de tablette ?
bool get navigateurMobile => false;
