/// Présence d'un employé pour la journée, telle que renvoyée par le serveur.
enum PresenceJour {
  presente,
  absente,
  absenteMatin,
  absenteApresMidi,
  nonDeclaree;

  static PresenceJour fromCode(String code) => switch (code) {
        'presente' => PresenceJour.presente,
        'absente' => PresenceJour.absente,
        'absente_matin' => PresenceJour.absenteMatin,
        'absente_apres_midi' => PresenceJour.absenteApresMidi,
        'non_declaree' => PresenceJour.nonDeclaree,
        _ => throw FormatException('Présence inconnue : $code'),
      };

  String get libelle => switch (this) {
        PresenceJour.presente => 'Présente',
        PresenceJour.absente => 'Absente',
        PresenceJour.absenteMatin => 'Absente le matin',
        PresenceJour.absenteApresMidi => "Absente l'après-midi",
        PresenceJour.nonDeclaree => 'Non déclarée',
      };

  /// Toute absence, même partielle.
  bool get estAbsence =>
      this == absente || this == absenteMatin || this == absenteApresMidi;
}

/// État d'un ménage du jour, sans aucune précision sur un non-réalisé : le
/// motif (Absent, Refus, autre) n'est jamais transmis à la réception.
enum EtatTacheEquipe {
  aFaire,
  realise,
  nonRealise;

  static EtatTacheEquipe fromCode(String code) => switch (code) {
        'a_faire' => EtatTacheEquipe.aFaire,
        'realise' => EtatTacheEquipe.realise,
        'non_realise' => EtatTacheEquipe.nonRealise,
        _ => throw FormatException('État de tâche inconnu : $code'),
      };

  String get libelle => switch (this) {
        EtatTacheEquipe.aFaire => 'À faire',
        EtatTacheEquipe.realise => 'Effectué',
        EtatTacheEquipe.nonRealise => 'Non effectué',
      };
}

/// Un ménage du jour dans l'horaire d'un employé.
class TacheEquipe {
  final String appartementId;
  final String numero;

  /// 'AM' ou 'PM'.
  final String periode;
  final EtatTacheEquipe etat;

  const TacheEquipe({
    required this.appartementId,
    required this.numero,
    required this.periode,
    required this.etat,
  });

  factory TacheEquipe.fromJson(Map<String, dynamic> json) => TacheEquipe(
        appartementId: json['appartement_id'] as String,
        numero: json['numero'] as String,
        periode: json['periode'] as String? ?? '',
        etat: EtatTacheEquipe.fromCode(json['etat'] as String),
      );
}

/// Un ménage libéré, en attente d'attribution à un employé.
class TacheEnAttente {
  final String appartementId;
  final String numero;
  final String periode;

  const TacheEnAttente({
    required this.appartementId,
    required this.numero,
    required this.periode,
  });

  factory TacheEnAttente.fromJson(Map<String, dynamic> json) => TacheEnAttente(
        appartementId: json['appartement_id'] as String,
        numero: json['numero'] as String,
        periode: json['periode'] as String? ?? '',
      );
}

/// Une ligne du tableau de l'équipe : un employé, sa présence et son horaire.
class MembreEquipe {
  final String id;
  final String prenom;
  final String nom;
  final PresenceJour presence;

  /// « HH:mm » (informatif), ou `null`.
  final String? heureDebut;
  final String? heureFin;
  final List<TacheEquipe> taches;

  const MembreEquipe({
    required this.id,
    required this.prenom,
    required this.nom,
    required this.presence,
    this.heureDebut,
    this.heureFin,
    this.taches = const [],
  });

  factory MembreEquipe.fromJson(Map<String, dynamic> json) => MembreEquipe(
        id: json['id'] as String,
        prenom: json['prenom'] as String,
        nom: json['nom'] as String,
        presence: PresenceJour.fromCode(json['presence'] as String),
        heureDebut: json['heure_debut'] as String?,
        heureFin: json['heure_fin'] as String?,
        taches: [
          for (final t in (json['taches'] as List? ?? const []))
            TacheEquipe.fromJson(t as Map<String, dynamic>),
        ],
      );

  String get nomComplet => '$prenom $nom';

  String get initiales {
    String premiere(String s) => s.isEmpty ? '' : s[0].toUpperCase();
    return '${premiere(prenom)}${premiere(nom)}';
  }

  /// « 08:00 – 16:00 », ou `null` si les heures ne sont pas précisées.
  String? get horaire => heureDebut != null && heureFin != null
      ? '$heureDebut – $heureFin'
      : null;

  int get nbRealises =>
      taches.where((t) => t.etat == EtatTacheEquipe.realise).length;

  /// « Aucun », ou « 1/3 effectués ».
  String get resumeMenages => taches.isEmpty
      ? 'Aucun'
      : '$nbRealises/${taches.length} effectué${nbRealises > 1 ? 's' : ''}';
}

/// L'équipe pour la journée du Québec courante.
class EquipeDuJour {
  final DateTime date;
  final List<MembreEquipe> membres;
  final List<TacheEnAttente> enAttente;

  const EquipeDuJour({
    required this.date,
    required this.membres,
    this.enAttente = const [],
  });

  factory EquipeDuJour.fromJson(Map<String, dynamic> json) => EquipeDuJour(
        date: DateTime.parse(json['date'] as String),
        membres: [
          for (final m in (json['employes'] as List? ?? const []))
            MembreEquipe.fromJson(m as Map<String, dynamic>),
        ],
        enAttente: [
          for (final t in (json['en_attente'] as List? ?? const []))
            TacheEnAttente.fromJson(t as Map<String, dynamic>),
        ],
      );
}
