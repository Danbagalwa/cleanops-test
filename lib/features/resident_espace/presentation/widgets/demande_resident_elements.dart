import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/demande_resident.dart';

// Éléments communs aux vues responsable des demandes des résidents (tableau,
// grille, détail, exports).

const _jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

String _deux(int n) => n.toString().padLeft(2, '0');

String dateCourteDemande(DateTime d) {
  final l = d.toLocal();
  return '${_deux(l.day)}/${_deux(l.month)}/${l.year}';
}

/// « 24/09/2026 14:30 ».
String dateHeureDemande(DateTime d) {
  final l = d.toLocal();
  return '${dateCourteDemande(l)} ${_deux(l.hour)}:${_deux(l.minute)}';
}

String dateEnvoiDemandeResident(DemandeResident d) =>
    dateHeureDemande(d.createdAt);

String periodeFr(String? p) => switch (p) {
      'AM' => 'Matin',
      'PM' => 'Après-midi',
      _ => '',
    };

String _jourEtDate(DateTime d) =>
    '${_jours[d.weekday - 1]} ${_deux(d.day)}/${_deux(d.month)}';

/// Ménage visé : « jeu. 24/09 · Matin », ou `null`.
String? menageDemande(DemandeResident d) {
  final date = d.menageDate;
  if (date == null) return null;
  final p = periodeFr(d.menagePeriode);
  return p.isEmpty ? _jourEtDate(date) : '${_jourEtDate(date)} · $p';
}

/// Nouveau créneau proposé par le responsable, ou `null`.
String? propositionDemande(DemandeResident d) {
  final date = d.propositionDate;
  if (date == null) return null;
  final p = periodeFr(d.propositionPeriode);
  return p.isEmpty ? _jourEtDate(date) : '${_jourEtDate(date)} · $p';
}

String nomResidentDemande(DemandeResident d) => d.nomResident ?? 'Résident';

String? appartementDemande(DemandeResident d) =>
    d.numeroAppartement == null ? null : 'Apt ${d.numeroAppartement}';

String libelleTypeDemandeResident(TypeDemande t) => switch (t) {
      TypeDemande.reprogrammer => 'Reprogrammation',
      TypeDemande.annuler => 'Annulation',
      TypeDemande.commentaire => 'Commentaire',
      TypeDemande.infoAppartement => 'Infos appartement',
    };

IconData iconeTypeDemandeResident(TypeDemande t) => switch (t) {
      TypeDemande.reprogrammer => Icons.event_repeat_rounded,
      TypeDemande.annuler => Icons.event_busy_rounded,
      TypeDemande.commentaire => Icons.chat_bubble_outline_rounded,
      TypeDemande.infoAppartement => Icons.home_work_outlined,
    };

Color couleurTypeDemandeResident(TypeDemande t) => switch (t) {
      TypeDemande.reprogrammer => AppColors.rouge,
      TypeDemande.annuler => AppColors.refus,
      TypeDemande.commentaire => AppColors.absent,
      TypeDemande.infoAppartement => AppColors.aVerifier,
    };

/// Le résident a refusé le créneau proposé : une nouvelle proposition est
/// attendue du responsable.
bool refuseeParResident(DemandeResident d) =>
    d.repondue && d.residentAccepte == false;

/// La demande attend une action du responsable.
bool aTraiterDemande(DemandeResident d) => d.enAttente || refuseeParResident(d);

/// État lisible, plus fin que le statut brut.
(String, Color, IconData) etatDemandeResident(DemandeResident d) {
  if (d.enAttente) {
    return ('En attente', AppColors.aVerifier, Icons.hourglass_top_rounded);
  }
  if (refuseeParResident(d)) {
    return ('Refusée par le résident', AppColors.refus, Icons.undo_rounded);
  }
  if (d.repondue) {
    return ('Attend le résident', AppColors.absent, Icons.schedule_rounded);
  }
  return ('Résolue', AppColors.fait, Icons.task_alt_rounded);
}

String libelleEtatDemandeResident(DemandeResident d) =>
    etatDemandeResident(d).$1;

// ── Badges ─────────────────────────────────────────────────

class _Pastille extends StatelessWidget {
  final IconData icone;
  final String texte;
  final Color couleur;
  const _Pastille(this.icone, this.texte, this.couleur);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 13, color: couleur),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                texte,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: couleur),
              ),
            ),
          ],
        ),
      );
}

class BadgeTypeDemandeResident extends StatelessWidget {
  final TypeDemande type;
  const BadgeTypeDemandeResident({super.key, required this.type});

  @override
  Widget build(BuildContext context) => _Pastille(
        iconeTypeDemandeResident(type),
        libelleTypeDemandeResident(type),
        couleurTypeDemandeResident(type),
      );
}

class BadgeEtatDemandeResident extends StatelessWidget {
  final DemandeResident demande;
  const BadgeEtatDemandeResident({super.key, required this.demande});

  @override
  Widget build(BuildContext context) {
    final (texte, couleur, icone) = etatDemandeResident(demande);
    return _Pastille(icone, texte, couleur);
  }
}

class BadgeUrgente extends StatelessWidget {
  const BadgeUrgente({super.key});

  @override
  Widget build(BuildContext context) => const _Pastille(
      Icons.priority_high_rounded, 'Urgent', AppColors.nonAutorise);
}
