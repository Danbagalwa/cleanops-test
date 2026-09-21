/// Une ligne du tableau des PIN : un résident actif et l'état de son PIN.
///
/// Le PIN lui-même n'apparaît nulle part : il est stocké haché et n'est jamais
/// relisible. Seul `aPin` indique qu'il en existe un.
class ResidentPin {
  final String residentId;
  final String prenom;
  final String nom;
  final String appartementId;
  final String numero;
  final bool aApplication;
  final bool aPin;

  const ResidentPin({
    required this.residentId,
    required this.prenom,
    required this.nom,
    required this.appartementId,
    required this.numero,
    this.aApplication = false,
    this.aPin = false,
  });

  factory ResidentPin.fromJson(Map<String, dynamic> json) => ResidentPin(
        residentId: json['resident_id'] as String,
        prenom: json['prenom'] as String,
        nom: json['nom'] as String,
        appartementId: json['appartement_id'] as String,
        numero: json['numero'] as String,
        aApplication: json['a_application'] as bool? ?? false,
        aPin: json['a_pin'] as bool? ?? false,
      );

  String get nomComplet => '$prenom $nom';

  String get initiales {
    String premiere(String s) => s.isEmpty ? '' : s[0].toUpperCase();
    return '${premiere(prenom)}${premiere(nom)}';
  }
}

/// Le PIN qui vient d'être généré : affiché UNE fois, puis oublié.
class PinGenere {
  final String pin;

  /// Vrai si un ancien PIN a été remplacé.
  final bool reinitialise;

  const PinGenere({required this.pin, required this.reinitialise});

  factory PinGenere.fromJson(Map<String, dynamic> json) => PinGenere(
        pin: json['pin'] as String,
        reinitialise: json['reinitialise'] as bool? ?? false,
      );

  /// Ne jamais laisser le PIN dans un journal ou un message d'erreur.
  @override
  String toString() => 'PinGenere(reinitialise: $reinitialise)';
}
