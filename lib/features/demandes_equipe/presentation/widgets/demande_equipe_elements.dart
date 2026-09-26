import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/demande_equipe.dart';

IconData iconeTypeDemande(TypeDemandeEquipe type) => switch (type) {
      TypeDemandeEquipe.conge => Icons.beach_access_rounded,
      TypeDemandeEquipe.absencePlanifiee => Icons.event_busy_rounded,
      TypeDemandeEquipe.autre => Icons.more_horiz_rounded,
    };

Color couleurTypeDemande(TypeDemandeEquipe type) => switch (type) {
      TypeDemandeEquipe.conge => const Color(0xFF00897B),
      TypeDemandeEquipe.absencePlanifiee => AppColors.absent,
      TypeDemandeEquipe.autre => AppColors.grisDark,
    };

/// Statut lisible : En attente, Approuvée, Refusée ou Vue (« Autre »).
String libelleStatutDemande(DemandeEquipe d) {
  if (d.estApprouvee) return 'Approuvée';
  if (d.estRefusee) return 'Refusée';
  if (d.estVue) return 'Vue';
  return 'En attente';
}

Color couleurStatutDemande(DemandeEquipe d) {
  if (d.estApprouvee) return AppColors.fait;
  if (d.estRefusee) return AppColors.refus;
  if (d.estVue) return AppColors.grisDark;
  return AppColors.aVerifier;
}

String _jour(DateTime d) => DateFormat('d MMM yyyy', 'fr_FR').format(d);

/// Période demandée ; `null` pour une demande « Autre » (sans date).
String? periodeDemande(DemandeEquipe d) {
  if (d.type == TypeDemandeEquipe.autre) return null;
  if (d.dateFin == null || d.dateFin == d.dateDebut) return _jour(d.dateDebut);
  return '${_jour(d.dateDebut)} → ${_jour(d.dateFin!)}';
}

/// Nombre de jours couverts (dates incluses) ; `null` sans période.
int? joursDemande(DemandeEquipe d) {
  if (d.type == TypeDemandeEquipe.autre) return null;
  final fin = d.dateFin ?? d.dateDebut;
  return fin.difference(d.dateDebut).inDays + 1;
}

String dateEnvoiDemande(DemandeEquipe d) =>
    DateFormat('d MMM yyyy', 'fr_FR').format(d.createdAt.toLocal());

String nomDemandeur(DemandeEquipe d) {
  final e = d.employee;
  final nom = e == null ? '' : '${e.prenom} ${e.nom}'.trim();
  return nom.isEmpty ? 'Employé·e' : nom;
}

class BadgeStatutDemande extends StatelessWidget {
  final DemandeEquipe demande;
  const BadgeStatutDemande({super.key, required this.demande});

  @override
  Widget build(BuildContext context) {
    final couleur = couleurStatutDemande(demande);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        libelleStatutDemande(demande),
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w600, color: couleur),
      ),
    );
  }
}

class BadgeTypeDemande extends StatelessWidget {
  final TypeDemandeEquipe type;
  const BadgeTypeDemande({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final couleur = couleurTypeDemande(type);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(iconeTypeDemande(type), size: 15, color: couleur),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            type.libelle,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: couleur),
          ),
        ),
      ],
    );
  }
}

/// Note du responsable (réponse) affichée sous une demande traitée.
class NoteResponsableDemande extends StatelessWidget {
  final DemandeEquipe demande;
  const NoteResponsableDemande({super.key, required this.demande});

  @override
  Widget build(BuildContext context) {
    final note = demande.noteResponsable;
    if (note == null || note.trim().isEmpty) return const SizedBox.shrink();
    final auteur = demande.traitePar?.prenom;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: couleurStatutDemande(demande), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            auteur == null ? 'Réponse' : 'Réponse de $auteur',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.grisDark),
          ),
          const SizedBox(height: 2),
          Text(note,
              style: const TextStyle(fontSize: 12.5, color: AppColors.noir)),
        ],
      ),
    );
  }
}
