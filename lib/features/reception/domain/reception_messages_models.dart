import 'package:intl/intl.dart';
import 'reception_models.dart' show NatureDemande;

/// Statut d'un message transmis à l'administration. Trois valeurs seulement :
/// aucun statut « Traitée ».
enum StatutMessage {
  enAttente,
  repondue,
  resolue;

  static StatutMessage fromCode(String code) => switch (code) {
        'EnAttente' => StatutMessage.enAttente,
        'Repondue' => StatutMessage.repondue,
        'Resolue' => StatutMessage.resolue,
        _ => throw FormatException('Statut de message inconnu : $code'),
      };

  String get libelle => switch (this) {
        StatutMessage.enAttente => 'En attente',
        StatutMessage.repondue => 'Répondue',
        StatutMessage.resolue => 'Résolue',
      };

  /// Ce que le statut veut dire pour la Réception : de quoi répondre
  /// honnêtement à un résident qui rappelle.
  String get signification => switch (this) {
        StatutMessage.enAttente => "Personne n'a encore traité cette demande.",
        StatutMessage.repondue =>
          "Une réponse a été donnée, mais l'horaire n'a pas changé.",
        StatutMessage.resolue => "L'horaire a été modifié.",
      };
}

/// Un message envoyé par la Réception à l'administration. Lecture seule.
class MessageTransmis {
  final String id;
  final String appartementId;
  final String numero;

  /// Nature de la demande du résident (annulation, reprogrammation, autre).
  final NatureDemande nature;
  final String message;
  final String auteurPrenom;

  /// Vrai si la case « Transmettre aussi à l'employé » était cochée.
  final bool transmisEmploye;
  final String? employePrenom;
  final StatutMessage statut;

  /// Réponse de l'administration, si elle existe.
  final String? reponse;

  /// Dates à l'heure du Québec, déjà converties par le serveur.
  final DateTime dateCreation;
  final DateTime? dateReponse;
  final DateTime? dateResolution;

  const MessageTransmis({
    required this.id,
    required this.appartementId,
    required this.numero,
    required this.message,
    required this.auteurPrenom,
    required this.statut,
    required this.dateCreation,
    this.nature = NatureDemande.autre,
    this.transmisEmploye = false,
    this.employePrenom,
    this.reponse,
    this.dateReponse,
    this.dateResolution,
  });

  factory MessageTransmis.fromJson(Map<String, dynamic> json) {
    DateTime? date(String cle) =>
        json[cle] == null ? null : DateTime.parse(json[cle] as String);

    return MessageTransmis(
      id: json['id'] as String,
      appartementId: json['appartement_id'] as String,
      numero: json['numero'] as String,
      // Les messages d'avant la nature de la demande valent « Autre ».
      nature: json['nature'] == null
          ? NatureDemande.autre
          : NatureDemande.fromCode(json['nature'] as String),
      message: json['message'] as String,
      auteurPrenom: json['auteur_prenom'] as String? ?? '',
      transmisEmploye: json['transmis_employe'] as bool? ?? false,
      employePrenom: json['employe_prenom'] as String?,
      statut: StatutMessage.fromCode(json['statut'] as String),
      reponse: json['reponse'] as String?,
      dateCreation: DateTime.parse(json['date_creation'] as String),
      dateReponse: date('date_reponse'),
      dateResolution: date('date_resolution'),
    );
  }

  static String formater(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);

  String get envoyeLe => formater(dateCreation);
}
