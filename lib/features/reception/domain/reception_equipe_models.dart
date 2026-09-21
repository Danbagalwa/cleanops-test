/// Présence d'un employé pour la journée. Trois états seulement.
enum PresenceJour {
  presente,
  absente,
  nonConfirmee;

  static PresenceJour fromCode(String code) => switch (code) {
        'presente' => PresenceJour.presente,
        'absente' => PresenceJour.absente,
        'non_confirmee' => PresenceJour.nonConfirmee,
        _ => throw FormatException('Présence inconnue : $code'),
      };

  String get libelle => switch (this) {
        PresenceJour.presente => 'Présente',
        PresenceJour.absente => 'Absente',
        PresenceJour.nonConfirmee => 'Non confirmée',
      };
}

/// Partie de la journée où l'employé travaille.
enum PartieJournee {
  complete,
  matin,
  apresMidi;

  static PartieJournee fromCode(String code) => switch (code) {
        'complete' => PartieJournee.complete,
        'matin' => PartieJournee.matin,
        'apres_midi' => PartieJournee.apresMidi,
        _ => throw FormatException('Partie de journée inconnue : $code'),
      };
}

/// « 08:00 » -> « 8h00 », « 13:30 » -> « 13h30 ». Toute autre forme est rendue
/// telle quelle.
String formaterHeure(String heure) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(heure);
  if (m == null) return heure;
  return '${int.parse(m.group(1)!)}h${m.group(2)}';
}

/// Une ligne du tableau de l'équipe : l'employé, sa présence et son horaire du
/// jour. RIEN D'AUTRE.
///
/// Ce modèle ne contient VOLONTAIREMENT aucun champ pour une tâche, un
/// compteur, une progression, un appartement, le motif d'une absence ou
/// l'horaire d'un autre jour : la Réception ne doit pas pouvoir observer le
/// travail de l'équipe. Un JSON qui en contiendrait (par erreur) ne l'atteint
/// jamais.
class MembreEquipe {
  final String id;
  final String prenom;
  final String nom;
  final PresenceJour presence;

  /// Partie de la journée travaillée (`null` si absente ou non confirmée).
  final PartieJournee? journee;

  /// Heures précisées par l'employé, « HH:mm » (informatif), ou `null`.
  final String? heureDebut;
  final String? heureFin;

  const MembreEquipe({
    required this.id,
    required this.prenom,
    required this.nom,
    required this.presence,
    this.journee,
    this.heureDebut,
    this.heureFin,
  });

  factory MembreEquipe.fromJson(Map<String, dynamic> json) => MembreEquipe(
        id: json['id'] as String,
        prenom: json['prenom'] as String,
        nom: json['nom'] as String,
        presence: PresenceJour.fromCode(json['presence'] as String),
        journee: json['journee'] == null
            ? null
            : PartieJournee.fromCode(json['journee'] as String),
        heureDebut: json['heure_debut'] as String?,
        heureFin: json['heure_fin'] as String?,
      );

  String get nomComplet => '$prenom $nom';

  String get initiales {
    String premiere(String s) => s.isEmpty ? '' : s[0].toUpperCase();
    return '${premiere(prenom)}${premiere(nom)}';
  }

  /// L'horaire du jour : « 8h00 – 13h00 », « Toute la journée », « Matin
  /// seulement » ou « Après-midi seulement ». `null` si l'employé n'est pas
  /// présent (absente ou non confirmée).
  String? get horaire {
    if (presence != PresenceJour.presente) return null;
    if (heureDebut != null && heureFin != null) {
      return '${formaterHeure(heureDebut!)} – ${formaterHeure(heureFin!)}';
    }
    return switch (journee) {
      PartieJournee.matin => 'Matin seulement',
      PartieJournee.apresMidi => 'Après-midi seulement',
      _ => 'Toute la journée',
    };
  }
}

/// L'équipe pour la journée du Québec courante.
class EquipeDuJour {
  final DateTime date;
  final List<MembreEquipe> membres;

  const EquipeDuJour({required this.date, required this.membres});

  factory EquipeDuJour.fromJson(Map<String, dynamic> json) => EquipeDuJour(
        date: DateTime.parse(json['date'] as String),
        membres: [
          for (final m in (json['employes'] as List? ?? const []))
            MembreEquipe.fromJson(m as Map<String, dynamic>),
        ],
      );
}
