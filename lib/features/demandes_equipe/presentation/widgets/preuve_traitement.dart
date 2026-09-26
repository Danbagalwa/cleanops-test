import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/compression_photo.dart' show formaterTaille;
import '../../../../core/widgets/dialogue_app.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/transfert_document_demande.dart';
import '../../domain/entities/demande_equipe.dart';
import '../../domain/entities/fichier_choisi.dart';
import '../providers/demande_equipe_provider.dart';
import 'actions_document_demande.dart' show IconeFichier;
import 'nouvelle_demande_equipe_sheet.dart'
    show
        signatureDocumentValide,
        tailleMaxDocumentDemande,
        typeMimeDocumentDemande;

/// Fichier de preuve choisi et validé, prêt à être envoyé.
class FichierPreuve {
  final Uint8List octets;
  final String nom;
  final String typeMime;

  const FichierPreuve({
    required this.octets,
    required this.nom,
    required this.typeMime,
  });

  bool get pdf => typeMime == 'application/pdf';
}

/// Champ « Preuve de traitement (facultatif) » : choix d'un PDF ou d'une
/// image, avec les mêmes contrôles que le document d'une demande (5 Mo max,
/// format réel vérifié).
class ChampPreuveTraitement extends ConsumerStatefulWidget {
  final FichierPreuve? valeur;
  final ValueChanged<FichierPreuve?> onChanged;
  final bool enEnvoi;

  const ChampPreuveTraitement({
    super.key,
    required this.valeur,
    required this.onChanged,
    this.enEnvoi = false,
  });

  @override
  ConsumerState<ChampPreuveTraitement> createState() =>
      _ChampPreuveTraitementState();
}

class _ChampPreuveTraitementState extends ConsumerState<ChampPreuveTraitement> {
  String? _erreur;

  Future<void> _choisir() async {
    setState(() => _erreur = null);
    FichierChoisi? fichier;
    try {
      fichier = await ref
          .read(selecteurDocumentProvider)
          .choisir(extensions: const ['pdf', 'jpg', 'jpeg', 'png']);
    } catch (_) {
      setState(() => _erreur = 'Impossible d’ouvrir le sélecteur de fichier.');
      return;
    }
    if (!mounted || fichier == null) return;

    final octets = fichier.octets;
    if (octets.length > tailleMaxDocumentDemande) {
      setState(() => _erreur = 'Ce fichier est trop volumineux '
          '(${formaterTaille(tailleMaxDocumentDemande)} maximum).');
      return;
    }
    final typeMime = typeMimeDocumentDemande(fichier.extension);
    if (typeMime == null) {
      setState(() => _erreur = 'Formats acceptés : PDF, JPEG ou PNG.');
      return;
    }
    if (!signatureDocumentValide(octets, typeMime)) {
      setState(() => _erreur =
          'Ce fichier ne semble pas être un ${fichier!.extension} valide.');
      return;
    }
    widget.onChanged(
        FichierPreuve(octets: octets, nom: fichier.nom, typeMime: typeMime));
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.valeur;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            Icon(Icons.verified_outlined, size: 16, color: AppColors.fait),
            SizedBox(width: 6),
            Text(
              'Preuve de traitement',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.noir,
              ),
            ),
            SizedBox(width: 6),
            Text('(facultatif)',
                style: TextStyle(fontSize: 12, color: AppColors.grisText)),
          ],
        ),
        const SizedBox(height: 8),
        if (v == null)
          OutlinedButton.icon(
            onPressed: widget.enEnvoi ? null : _choisir,
            icon: const Icon(Icons.attach_file_rounded, size: 18),
            label: const Text('Joindre une preuve (PDF ou image)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.rouge,
              side: const BorderSide(color: AppColors.grisMedium),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              color: AppColors.fait.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.fait.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                IconeFichier(pdf: v.pdf, taille: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.noir,
                        ),
                      ),
                      Text(
                        widget.enEnvoi
                            ? 'Envoi de la preuve… '
                                '(${formaterTaille(v.octets.length)})'
                            : '${v.pdf ? 'PDF' : 'Image'} · '
                                '${formaterTaille(v.octets.length)}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.grisDark),
                      ),
                    ],
                  ),
                ),
                if (widget.enEnvoi)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.fait),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Retirer la preuve',
                    onPressed: () => widget.onChanged(null),
                    icon: const Icon(Icons.close_rounded, size: 19),
                  ),
              ],
            ),
          ),
        if (_erreur != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 15, color: AppColors.refus),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_erreur!,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.refus)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Envoie la preuve de [demande] et met la liste à jour. `null` si tout
/// s'est bien passé, sinon le message d'erreur (la demande, elle, reste
/// traitée : la preuve est facultative).
Future<String?> envoyerPreuveTraitement(
  WidgetRef ref,
  DemandeEquipe demande,
  FichierPreuve fichier,
) async {
  try {
    await ref.read(transfertDocumentDemandeProvider).joindrePreuve(
          demandeId: demande.id,
          responsableId: ref.read(employeeCourantProvider)?.id ?? '',
          nom: fichier.nom,
          typeMime: fichier.typeMime,
          octets: fichier.octets,
        );
  } on ErreurTransfert catch (e) {
    return e.message;
  } catch (_) {
    return 'La preuve n’a pas pu être jointe.';
  }
  ref.read(demandesEquipeResponsableProvider.notifier).marquerPreuve(
        demande.id,
        nom: fichier.nom,
        typeMime: fichier.typeMime,
        taille: fichier.octets.length,
      );
  return null;
}

/// Joindre (ou remplacer) la preuve d'une demande déjà traitée.
Future<void> ouvrirAjoutPreuve(BuildContext context, DemandeEquipe demande) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DialogueAjoutPreuve(demande: demande),
  );
}

class _DialogueAjoutPreuve extends ConsumerStatefulWidget {
  final DemandeEquipe demande;
  const _DialogueAjoutPreuve({required this.demande});

  @override
  ConsumerState<_DialogueAjoutPreuve> createState() =>
      _DialogueAjoutPreuveState();
}

class _DialogueAjoutPreuveState extends ConsumerState<_DialogueAjoutPreuve> {
  FichierPreuve? _fichier;
  bool _envoi = false;

  Future<void> _envoyer() async {
    setState(() => _envoi = true);
    final erreur =
        await envoyerPreuveTraitement(ref, widget.demande, _fichier!);
    if (!mounted) return;
    setState(() => _envoi = false);
    if (erreur != null) {
      NotificationApp.erreur(context, erreur);
      return;
    }
    Navigator.of(context).pop();
    NotificationApp.succes(context, 'La preuve de traitement a été jointe.');
  }

  @override
  Widget build(BuildContext context) {
    return DialogueApp(
      titre: widget.demande.aPreuve
          ? 'Remplacer la preuve'
          : 'Joindre une preuve de traitement',
      largeur: 480,
      libelleAction: 'Joindre',
      libelleSecondaire: 'Annuler',
      enCours: _envoi,
      onAction: _fichier == null ? null : _envoyer,
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Formulaire signé, confirmation, capture… La preuve sera visible '
            'par l’employé et sur la page d’un lien de partage.',
            style: TextStyle(
                fontSize: 13.5, height: 1.4, color: AppColors.grisDark),
          ),
          const SizedBox(height: 14),
          ChampPreuveTraitement(
            valeur: _fichier,
            enEnvoi: _envoi,
            onChanged: (f) => setState(() => _fichier = f),
          ),
        ],
      ),
    );
  }
}
