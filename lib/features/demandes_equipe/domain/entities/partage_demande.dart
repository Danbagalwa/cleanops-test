import 'demande_equipe.dart';

/// Ce que voit la personne qui ouvre un lien de partage : la demande (état,
/// réponse), qui l'a faite, qui l'a traitée, et le lien du document.
class PartageDemande {
  final DemandeEquipe demande;
  final String demandeur;
  final String? traitePar;
  final String? urlDocument;
  final DateTime expireLe;

  const PartageDemande({
    required this.demande,
    required this.demandeur,
    required this.traitePar,
    required this.urlDocument,
    required this.expireLe,
  });

  static String _nom(Map<String, dynamic>? e) {
    if (e == null) return '';
    return '${e['prenom'] ?? ''} ${e['nom'] ?? ''}'.trim();
  }

  factory PartageDemande.fromJson(Map<String, dynamic> json) {
    final d = json['demande'] as Map<String, dynamic>;
    final doc = json['document'] as Map<String, dynamic>?;
    final preuve = json['preuve'] as Map<String, dynamic>?;
    DateTime? date(Object? v) => v == null ? null : DateTime.parse('$v');
    final traite = _nom(json['traite_par'] as Map<String, dynamic>?);
    return PartageDemande(
      demande: DemandeEquipe(
        id: d['id'] as String,
        employeeId: '',
        type: TypeDemandeEquipe.fromString(d['type'] as String),
        dateDebut: date(d['date_debut'])!,
        dateFin: date(d['date_fin']),
        motif: d['motif'] as String? ?? '',
        statut: StatutDemandeEquipe.fromString(d['statut'] as String),
        approuve: d['approuve'] as bool?,
        noteResponsable: d['note_responsable'] as String?,
        createdAt: date(d['date_creation']) ?? DateTime.now(),
        dateTraitement: date(d['date_traitement']),
        documentNom: doc?['nom'] as String?,
        documentTypeMime: doc?['type_mime'] as String?,
        documentTaille: (doc?['taille'] as num?)?.toInt(),
        preuveNom: preuve?['nom'] as String?,
        preuveTypeMime: preuve?['type_mime'] as String?,
        preuveTaille: (preuve?['taille'] as num?)?.toInt(),
      ),
      demandeur: _nom(json['employe'] as Map<String, dynamic>?),
      traitePar: traite.isEmpty ? null : traite,
      urlDocument: json['url_document'] as String?,
      expireLe: date(json['expire_le'])!,
    );
  }
}
