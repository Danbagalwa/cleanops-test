/// Ce qui a changé pour le ménage du résident (source de l'avis).
enum TypeAvis {
  absence,
  remplacement,
  menageEnAttente,
  reprogrammation;

  static TypeAvis fromCode(String code) => switch (code) {
        'Absence' => TypeAvis.absence,
        'Remplacement' => TypeAvis.remplacement,
        'MenageEnAttente' => TypeAvis.menageEnAttente,
        'Reprogrammation' => TypeAvis.reprogrammation,
        _ => throw FormatException("Type d'avis inconnu : $code"),
      };

  String get libelle => switch (this) {
        TypeAvis.absence => 'Préposée absente',
        TypeAvis.remplacement => 'Remplacement confirmé',
        TypeAvis.menageEnAttente => 'Ménage annulé, en attente',
        TypeAvis.reprogrammation => 'Ménage déplacé',
      };
}

/// Statut d'un avis. « À aviser » et « Reporté » sont ouverts ; « Appelé(e) »
/// et « Note laissée » sont traités.
enum StatutAvis {
  aAviser,
  reporte,
  appele,
  noteLaissee;

  static StatutAvis fromCode(String code) => switch (code) {
        'AAviser' => StatutAvis.aAviser,
        'Reporte' => StatutAvis.reporte,
        'Appele' => StatutAvis.appele,
        'NoteLaissee' => StatutAvis.noteLaissee,
        _ => throw FormatException("Statut d'avis inconnu : $code"),
      };

  /// Valeur attendue par le serveur.
  String get code => switch (this) {
        StatutAvis.aAviser => 'AAviser',
        StatutAvis.reporte => 'Reporte',
        StatutAvis.appele => 'Appele',
        StatutAvis.noteLaissee => 'NoteLaissee',
      };

  String get libelle => switch (this) {
        StatutAvis.aAviser => 'À aviser',
        StatutAvis.reporte => 'Reporté',
        StatutAvis.appele => 'Appelé(e)',
        StatutAvis.noteLaissee => 'Note laissée',
      };

  bool get ouvert => this == aAviser || this == reporte;
}

/// Les trois façons de traiter un avis.
enum ActionAvis {
  appele,
  noteLaissee,
  reporter;

  /// Valeur attendue par le serveur.
  String get code => switch (this) {
        ActionAvis.appele => 'Appele',
        ActionAvis.noteLaissee => 'NoteLaissee',
        ActionAvis.reporter => 'Reporte',
      };

  String get libelle => switch (this) {
        ActionAvis.appele => 'Appelé(e)',
        ActionAvis.noteLaissee => 'Note laissée',
        ActionAvis.reporter => 'Reporter',
      };
}

/// Un résident sans application à prévenir.
class AvisResident {
  final String id;

  /// Le résident concerné (sa photo de profil s'il en a une).
  final String residentId;
  final String prenom;
  final String nom;
  final String appartementId;
  final String numero;
  final TypeAvis type;

  /// Le message que reçoivent les résidents avec l'application : ce qu'il faut
  /// annoncer. Il ne contient jamais de motif.
  final String message;
  final StatutAvis statut;
  final String? commentaire;

  /// Minutes écoulées depuis la création ou le dernier « Reporter », calculées
  /// par le serveur.
  final int depuisMinutes;

  /// Vrai si l'avis est ouvert depuis plus de 2 heures : badge rouge.
  final bool enRetard;

  const AvisResident({
    required this.id,
    required this.residentId,
    required this.prenom,
    required this.nom,
    required this.appartementId,
    required this.numero,
    required this.type,
    required this.message,
    required this.statut,
    this.commentaire,
    this.depuisMinutes = 0,
    this.enRetard = false,
  });

  factory AvisResident.fromJson(Map<String, dynamic> json) => AvisResident(
        id: json['id'] as String,
        residentId: json['resident_id'] as String,
        prenom: json['prenom'] as String,
        nom: json['nom'] as String,
        appartementId: json['appartement_id'] as String,
        numero: json['numero'] as String,
        type: TypeAvis.fromCode(json['type'] as String),
        message: json['message'] as String,
        statut: StatutAvis.fromCode(json['statut'] as String),
        commentaire: json['commentaire'] as String?,
        depuisMinutes: (json['depuis_minutes'] as num?)?.toInt() ?? 0,
        enRetard: json['en_retard'] as bool? ?? false,
      );

  String get nomComplet => '$prenom $nom';

  String get initiales {
    String premiere(String s) => s.isEmpty ? '' : s[0].toUpperCase();
    return '${premiere(prenom)}${premiere(nom)}';
  }

  bool get ouvert => statut.ouvert;

  /// « à l'instant », « il y a 35 min », « il y a 2 h 10 ».
  String get depuis {
    if (depuisMinutes < 1) return "à l'instant";
    if (depuisMinutes < 60) return 'il y a $depuisMinutes min';
    final h = depuisMinutes ~/ 60;
    final m = depuisMinutes % 60;
    return m == 0 ? 'il y a $h h' : 'il y a $h h ${m.toString().padLeft(2, '0')}';
  }
}
