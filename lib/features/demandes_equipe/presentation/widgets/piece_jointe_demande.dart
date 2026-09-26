import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/compression_photo.dart' show formaterTaille;
import '../../domain/entities/demande_equipe.dart';
import 'actions_document_demande.dart';

/// Tuile d'un fichier de demande : icône PDF / image, nom, taille et menu
/// d'options (ouvrir, télécharger, partager le fichier ou le lien). Un appui
/// sur la tuile ouvre la visionneuse. Vide (aucune taille prise) s'il n'y a
/// pas de fichier.
///
/// Par défaut : le document joint par l'employé. Avec [preuve] : la preuve
/// de traitement jointe par le responsable.
class PieceJointeDemande extends StatelessWidget {
  final DemandeEquipe demande;
  final bool preuve;

  const PieceJointeDemande({
    super.key,
    required this.demande,
    this.preuve = false,
  });

  @override
  Widget build(BuildContext context) {
    if (preuve ? !demande.aPreuve : !demande.aDocument) {
      return const SizedBox.shrink();
    }
    final fichier = FichierDemande(demande, preuve: preuve);
    final taille = fichier.taille;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(
        color: preuve
            ? AppColors.fait.withValues(alpha: 0.06)
            : AppColors.grisLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: preuve
                ? AppColors.fait.withValues(alpha: 0.35)
                : AppColors.grisMedium,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ouvrirFichierDemande(context, fichier),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 2, 8),
            child: Row(
              children: [
                IconeFichier(pdf: fichier.pdf, taille: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fichier.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.noir,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            preuve
                                ? Icons.verified_rounded
                                : Icons.attach_file_rounded,
                            size: 13,
                            color: preuve ? AppColors.fait : AppColors.grisText,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              [
                                if (preuve) 'Preuve de traitement',
                                fichier.pdf ? 'PDF' : 'Image',
                                if (taille != null) formaterTaille(taille),
                              ].join(' · '),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: preuve
                                    ? AppColors.fait
                                    : AppColors.grisText,
                                fontWeight:
                                    preuve ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                MenuDocumentDemande(demande: demande, preuve: preuve),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
