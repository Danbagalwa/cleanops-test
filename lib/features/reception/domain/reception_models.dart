import 'package:intl/intl.dart';

/// Une date de ménage à venir pour un appartement.
class ProchaineDate {
  final DateTime date;
  final String jour;

  /// 'AM' ou 'PM'.
  final String periode;
  final String? employePrenom;

  const ProchaineDate({
    required this.date,
    required this.jour,
    required this.periode,
    this.employePrenom,
  });

  factory ProchaineDate.fromJson(Map<String, dynamic> json) => ProchaineDate(
        date: DateTime.parse(json['date'] as String),
        jour: json['jour'] as String? ?? '',
        periode: json['periode'] as String? ?? '',
        employePrenom: json['employe_prenom'] as String?,
      );

  /// Date au format « 21/09/2026 ».
  String get dateCourte => DateFormat('dd/MM/yyyy').format(date);
}

/// Les 7 états du statut du jour d'un appartement.
enum EtatStatut {
  aucun,
  prevu,
  confirme,
  transfere,
  libere,
  realise,
  nonRealise;

  static EtatStatut fromCode(String code) => switch (code) {
        'aucun' => EtatStatut.aucun,
        'prevu' => EtatStatut.prevu,
        'confirme' => EtatStatut.confirme,
        'transfere' => EtatStatut.transfere,
        'libere' => EtatStatut.libere,
        'realise' => EtatStatut.realise,
        'non_realise' => EtatStatut.nonRealise,
        _ => throw FormatException('État de statut inconnu : $code'),
      };
}

/// Statut du jour d'un appartement, tel que renvoyé par le serveur.
///
/// Ce modèle ne contient VOLONTAIREMENT aucun champ pour le motif d'un
/// non-réalisé : le serveur ne le renvoie jamais et rien ici ne peut le porter.
class StatutDuJour {
  final EtatStatut etat;

  /// 'AM' ou 'PM' (absent pour « aucun » et « non réalisé »).
  final String? periode;
  final String? employePrenom;

  /// Heure « HH:mm » de réalisation (état « réalisé » seulement).
  final String? heure;

  /// Prochaine date (état « aucun » seulement).
  final ProchaineDate? prochaine;

  const StatutDuJour({
    required this.etat,
    this.periode,
    this.employePrenom,
    this.heure,
    this.prochaine,
  });

  factory StatutDuJour.fromJson(Map<String, dynamic> json) {
    final prochaine = json['prochaine'];
    return StatutDuJour(
      etat: EtatStatut.fromCode(json['etat'] as String),
      periode: json['periode'] as String?,
      employePrenom: json['employe_prenom'] as String?,
      heure: json['heure'] as String?,
      prochaine: prochaine is Map<String, dynamic>
          ? ProchaineDate.fromJson(prochaine)
          : null,
    );
  }

  /// Libellé EXACT affiché à la réception, un par état.
  String get libelle {
    final p = periode ?? '';
    final nom = employePrenom;
    return switch (etat) {
      EtatStatut.aucun => prochaine == null
          ? "Pas de ménage prévu aujourd'hui — aucun prochain ménage planifié"
          : "Pas de ménage prévu aujourd'hui — prochain : "
              '${prochaine!.dateCourte} ${prochaine!.periode}',
      EtatStatut.prevu => "Prévu aujourd'hui $p — ${nom ?? 'non attribué'}",
      EtatStatut.confirme =>
        "Confirmé pour aujourd'hui $p — ${nom ?? 'non attribué'}",
      EtatStatut.transfere => "Aujourd'hui $p — ${nom ?? 'non attribué'}",
      EtatStatut.libere => "Aujourd'hui $p — en attente d'attribution",
      EtatStatut.realise => heure == null
          ? "Effectué aujourd'hui — ${nom ?? 'non attribué'}"
          : "Effectué aujourd'hui à $heure — ${nom ?? 'non attribué'}",
      EtatStatut.nonRealise => "Non effectué aujourd'hui",
    };
  }
}

/// Une ligne du tableau des résidents : un résident actif et son appartement.
class ResidentLigne {
  final String residentId;
  final String prenom;
  final String nom;
  final String appartementId;
  final String numero;
  final int? etage;

  const ResidentLigne({
    required this.residentId,
    required this.prenom,
    required this.nom,
    required this.appartementId,
    required this.numero,
    this.etage,
  });

  factory ResidentLigne.fromJson(Map<String, dynamic> json) => ResidentLigne(
        residentId: json['resident_id'] as String,
        prenom: json['prenom'] as String,
        nom: json['nom'] as String,
        appartementId: json['appartement_id'] as String,
        numero: json['numero'] as String,
        etage: json['etage'] as int?,
      );

  String get nomComplet => '$prenom $nom';

  String get initiales {
    String premiere(String s) => s.isEmpty ? '' : s[0].toUpperCase();
    return '${premiere(prenom)}${premiere(nom)}';
  }
}

/// Employé concerné par l'appartement (destinataire de « Transmettre aussi à
/// l'employé »).
class EmployeConcerne {
  final String id;
  final String prenom;

  const EmployeConcerne({required this.id, required this.prenom});

  factory EmployeConcerne.fromJson(Map<String, dynamic> json) =>
      EmployeConcerne(
        id: json['id'] as String,
        prenom: json['prenom'] as String,
      );
}

/// Fiche d'un appartement, en lecture seule.
class FicheAppartement {
  final String id;
  final String numero;
  final int? etage;
  final String? taille;

  /// « Prénom Nom » de chaque résident actif.
  final List<String> residents;
  final StatutDuJour statut;
  final List<ProchaineDate> prochainesDates;
  final EmployeConcerne? employeConcerne;

  const FicheAppartement({
    required this.id,
    required this.numero,
    this.etage,
    this.taille,
    this.residents = const [],
    required this.statut,
    this.prochainesDates = const [],
    this.employeConcerne,
  });

  factory FicheAppartement.fromJson(Map<String, dynamic> json) {
    final apt = json['appartement'] as Map<String, dynamic>;
    final concerne = json['employe_concerne'];
    return FicheAppartement(
      id: apt['id'] as String,
      numero: apt['numero'] as String,
      etage: apt['etage'] as int?,
      taille: apt['taille'] as String?,
      residents: [
        for (final r in (json['residents'] as List? ?? const []))
          '${(r as Map<String, dynamic>)['prenom']} ${r['nom']}',
      ],
      statut:
          StatutDuJour.fromJson(json['statut_du_jour'] as Map<String, dynamic>),
      prochainesDates: [
        for (final d in (json['prochaines_dates'] as List? ?? const []))
          ProchaineDate.fromJson(d as Map<String, dynamic>),
      ],
      employeConcerne: concerne is Map<String, dynamic>
          ? EmployeConcerne.fromJson(concerne)
          : null,
    );
  }
}
