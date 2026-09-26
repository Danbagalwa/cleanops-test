/// Partage natif du navigateur (Web Share API) quand il existe. Sur les
/// autres plateformes, et quand le navigateur ne sait pas partager, les
/// fonctions renvoient `false` : l'appelant se replie alors sur une autre voie
/// (téléchargement, copie du lien).
library;

export 'partage_natif_stub.dart'
    if (dart.library.js_interop) 'partage_natif_web.dart';
