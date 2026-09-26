import 'package:equatable/equatable.dart';

enum AireCategorie { ascenseur, corridor, tapis, chute, salon, wc }

enum AireStatut { aFaire, fait }

class TacheAireCommune extends Equatable {
  final String id;
  final AireCategorie categorie;
  final String zone;
  final DateTime semaineDate;
  final AireStatut statut;
  final String? confirmeParId;
  final String? confirmeParPrenom;
  final DateTime? confirmeLE;
  final String? note;

  const TacheAireCommune({
    required this.id,
    required this.categorie,
    required this.zone,
    required this.semaineDate,
    required this.statut,
    this.confirmeParId,
    this.confirmeParPrenom,
    this.confirmeLE,
    this.note,
  });

  bool get estFait => statut == AireStatut.fait;

  @override
  List<Object?> get props => [id];
}

extension AireCategorieAffichage on AireCategorie {
  /// Nom au pluriel affiché dans l'app et les exports.
  String get libelle => switch (this) {
        AireCategorie.ascenseur => 'Ascenseurs',
        AireCategorie.corridor => 'Corridors',
        AireCategorie.tapis => 'Tapis',
        AireCategorie.chute => 'Chutes',
        AireCategorie.salon => 'Salon',
        AireCategorie.wc => 'WC',
      };
}

/// « Corridor_Etage_3 » → « Corridor – Étage 3 ».
String formatZoneAire(String zone) =>
    zone.replaceAll('_Etage_', ' – Étage ').replaceAll('_', ' ');

/// Tri naturel des zones : « Étage 2 » avant « Étage 10 ».
int comparerZones(String a, String b) {
  final chiffres = RegExp(r'\d+');
  final ca = chiffres.allMatches(a).map((m) => int.parse(m[0]!)).toList();
  final cb = chiffres.allMatches(b).map((m) => int.parse(m[0]!)).toList();
  final baseA = a.replaceAll(chiffres, '#');
  final baseB = b.replaceAll(chiffres, '#');
  final c = baseA.compareTo(baseB);
  if (c != 0) return c;
  for (var i = 0; i < ca.length && i < cb.length; i++) {
    if (ca[i] != cb[i]) return ca[i].compareTo(cb[i]);
  }
  return ca.length.compareTo(cb.length);
}
