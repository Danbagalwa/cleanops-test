import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/compression_photo.dart' show formaterTaille;
import '../../../../core/services/partage_natif.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../data/transfert_document_demande.dart';
import '../../domain/entities/partage_demande.dart';
import '../widgets/actions_document_demande.dart'
    show FichierDemande, IconeFichier;
import '../widgets/demande_equipe_elements.dart';

/// Page ouverte par un lien de partage (/partage/{jeton}) : accessible sans
/// connexion. Elle montre l'état de la demande, la réponse du responsable, le
/// document de l'employé et la preuve de traitement (chargés avec leur
/// progression). Sur un navigateur de téléphone, elle propose d'ouvrir la
/// même page dans l'application.
class PartageDemandeScreen extends ConsumerStatefulWidget {
  final String jeton;
  const PartageDemandeScreen({super.key, required this.jeton});

  @override
  ConsumerState<PartageDemandeScreen> createState() =>
      _PartageDemandeScreenState();
}

/// Chargement d'un fichier (document ou preuve).
class _EtatFichier {
  Uint8List? octets;
  int recus = 0;
  int? total;
  String? erreur;
  bool enCours = false;
  bool lance = false;
}

class _PartageDemandeScreenState extends ConsumerState<PartageDemandeScreen> {
  late Future<PartageDemande?> _partage;
  final _etats = {false: _EtatFichier(), true: _EtatFichier()};

  /// Fichier affiché : la preuve (true) ou le document de l'employé (false).
  bool _preuveAffichee = false;

  TransfertDocumentDemande get _service =>
      ref.read(transfertDocumentDemandeProvider);

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _charger() {
    setState(() {
      _etats[false] = _EtatFichier();
      _etats[true] = _EtatFichier();
      _partage = _service.lirePartage(widget.jeton).then((p) {
        if (p != null) {
          _preuveAffichee = !p.demande.aDocument && p.demande.aPreuve;
          if (p.demande.aDocument || p.demande.aPreuve) {
            _chargerFichier(p, _preuveAffichee);
          }
        }
        return p;
      });
    });
  }

  void _afficher(PartageDemande p, bool preuve) {
    setState(() => _preuveAffichee = preuve);
    if (!_etats[preuve]!.lance) _chargerFichier(p, preuve);
  }

  Future<void> _chargerFichier(PartageDemande p, bool preuve) async {
    final etat = _etats[preuve]!;
    final fichier = FichierDemande(p.demande, preuve: preuve);
    setState(() {
      etat
        ..lance = true
        ..enCours = true
        ..erreur = null
        ..recus = 0
        ..total = fichier.taille;
    });
    try {
      // Document : lien créé au partage (sinon signé ici). Preuve : toujours
      // signée ici, pour montrer aussi une preuve ajoutée après le partage.
      final url = !preuve && p.urlDocument != null
          ? p.urlDocument!
          : await _service.lien(fichier.chemin,
              validite: const Duration(hours: 1));
      final octets = await _service.telechargerUrl(
        url,
        tailleConnue: fichier.taille,
        onProgression: (recus, total) {
          if (mounted) {
            setState(() {
              etat
                ..recus = recus
                ..total = total ?? etat.total;
            });
          }
        },
      );
      if (mounted) setState(() => etat.octets = octets);
    } catch (e) {
      if (mounted) {
        setState(() => etat.erreur = e is ErreurTransfert
            ? e.message
            : 'Le fichier n’a pas pu être chargé.');
      }
    } finally {
      if (mounted) setState(() => etat.enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = estCompact(context);
    final marge = compact ? 12.0 : 24.0;

    return PageAvecEnTete(
      chargement: _etats.values.any((e) => e.enCours),
      enTete: const EnTetePage(
        icone: Icons.share_rounded,
        titre: 'Demande partagée',
        sousTitre: 'CleanOps — Résidence Jazz Teasdale',
      ),
      contenu: FutureBuilder<PartageDemande?>(
        future: _partage,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.rouge));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: AppErrorNotice(error: snap.error!, onRetry: _charger),
              ),
            );
          }
          final p = snap.data;
          if (p == null) return const _LienInvalide();

          final aFichier = p.demande.aDocument || p.demande.aPreuve;
          final resume = _Resume(
            partage: p,
            onVoirPreuve: p.demande.aPreuve ? () => _afficher(p, true) : null,
          );
          final visionneuse = _Visionneuse(
            partage: p,
            preuve: _preuveAffichee,
            etat: _etats[_preuveAffichee]!,
            onChoisir: (preuve) => _afficher(p, preuve),
            onReessayer: () => _chargerFichier(p, _preuveAffichee),
          );
          final bandeau = kIsWeb && navigateurMobile
              ? _BandeauApplication(jeton: widget.jeton)
              : null;

          return LayoutBuilder(builder: (context, c) {
            if (c.maxWidth >= 980) {
              return Padding(
                padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, marge),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 380,
                      child: SingleChildScrollView(child: resume),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(child: visionneuse),
                  ],
                ),
              );
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(marge, AppSizes.md, marge, marge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (bandeau != null) ...[
                    bandeau,
                    const SizedBox(height: AppSizes.sm),
                  ],
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: aFichier
                            ? c.maxHeight * 0.42
                            : c.maxHeight - marge * 2),
                    child: SingleChildScrollView(child: resume),
                  ),
                  if (aFichier) ...[
                    const SizedBox(height: AppSizes.md),
                    Expanded(child: visionneuse),
                  ],
                ],
              ),
            );
          });
        },
      ),
    );
  }
}

/// Navigateur de téléphone : ouvrir la même page dans l'application mobile
/// (lien cleanops://, qui fonctionne même sans vérification de domaine).
class _BandeauApplication extends StatelessWidget {
  final String jeton;
  const _BandeauApplication({required this.jeton});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.rouge.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_iphone_rounded, color: AppColors.rouge),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Vous avez l’application CleanOps ?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.noir,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => ouvrirLienExterne(lienApplicationPartage(jeton)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rouge,
              shape: const StadiumBorder(),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Ouvrir'),
          ),
        ],
      ),
    );
  }
}

// ── Résumé : état, réponse, informations ───────────────────

class _Resume extends StatelessWidget {
  final PartageDemande partage;

  /// Affiche la preuve de traitement dans la visionneuse (si elle existe).
  final VoidCallback? onVoirPreuve;

  const _Resume({required this.partage, this.onVoirPreuve});

  @override
  Widget build(BuildContext context) {
    final d = partage.demande;
    final couleur = couleurStatutDemande(d);
    final (icone, titre) = switch (d) {
      _ when d.estApprouvee => (
          Icons.check_circle_rounded,
          'Demande approuvée'
        ),
      _ when d.estRefusee => (Icons.cancel_rounded, 'Demande refusée'),
      _ when d.estVue => (
          Icons.visibility_rounded,
          'Demande vue par la direction'
        ),
      _ => (Icons.hourglass_top_rounded, 'En attente de réponse'),
    };
    final traiteLe = d.dateTraitement == null
        ? null
        : DateFormat('d MMMM yyyy à HH:mm', 'fr_FR')
            .format(d.dateTraitement!.toLocal());
    final periode = periodeDemande(d);
    final jours = joursDemande(d);
    const style = TextStyle(fontSize: 13.5, color: AppColors.noir);

    Widget info(String libelle, Widget valeur) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                child: Text(libelle,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.grisText)),
              ),
              Expanded(child: valeur),
            ],
          ),
        );

    return CarteContenu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── État de la demande ─────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: couleur.withValues(alpha: 0.09),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icone, color: couleur, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: couleur,
                        ),
                      ),
                      if (traiteLe != null)
                        Text(
                          partage.traitePar == null
                              ? 'Le $traiteLe'
                              : 'Le $traiteLe par ${partage.traitePar}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.grisDark),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Réponse du responsable ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'RÉPONSE DU RESPONSABLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.grisDark,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.grisLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: couleur, width: 3)),
                  ),
                  child: Text(
                    d.noteResponsable?.trim().isNotEmpty == true
                        ? d.noteResponsable!
                        : d.enAttente
                            ? 'La direction n’a pas encore répondu à cette '
                                'demande.'
                            : 'Aucun commentaire ajouté.',
                    style: style.copyWith(
                      height: 1.4,
                      fontStyle: d.noteResponsable?.trim().isNotEmpty == true
                          ? FontStyle.normal
                          : FontStyle.italic,
                      color: d.noteResponsable?.trim().isNotEmpty == true
                          ? AppColors.noir
                          : AppColors.grisText,
                    ),
                  ),
                ),
                if (d.aPreuve) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.fait.withValues(alpha: 0.07),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                          color: AppColors.fait.withValues(alpha: 0.35)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onVoirPreuve,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded,
                                size: 20, color: AppColors.fait),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Preuve de traitement jointe',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.fait,
                                    ),
                                  ),
                                  Text(
                                    [
                                      d.preuveNom!,
                                      if (d.preuveTaille != null)
                                        formaterTaille(d.preuveTaille!),
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.grisDark),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.fait),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Informations ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info(
                    'Demandeur',
                    Text(
                        partage.demandeur.isEmpty
                            ? 'Membre de l’équipe'
                            : partage.demandeur,
                        style: style.copyWith(fontWeight: FontWeight.w700))),
                info('Type', BadgeTypeDemande(type: d.type)),
                if (periode != null)
                  info(
                      'Période',
                      Text(
                          jours != null && jours > 1
                              ? '$periode · $jours jours'
                              : periode,
                          style: style)),
                info('Envoyée le', Text(dateEnvoiDemande(d), style: style)),
                if (d.motif.trim().isNotEmpty)
                  info('Motif',
                      Text(d.motif, style: style.copyWith(height: 1.4))),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.grisMedium),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_outlined,
                    size: 15, color: AppColors.grisText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lien de partage valable jusqu’au '
                    '${DateFormat('d MMMM yyyy', 'fr_FR').format(partage.expireLe.toLocal())}.',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.grisText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Visionneuse (document de l'employé ou preuve) ──────────

class _Visionneuse extends StatelessWidget {
  final PartageDemande partage;
  final bool preuve;
  final _EtatFichier etat;
  final ValueChanged<bool> onChoisir;
  final VoidCallback onReessayer;

  const _Visionneuse({
    required this.partage,
    required this.preuve,
    required this.etat,
    required this.onChoisir,
    required this.onReessayer,
  });

  FichierDemande get _fichier =>
      FichierDemande(partage.demande, preuve: preuve);

  Future<void> _telecharger(BuildContext context) async {
    try {
      await Printing.sharePdf(bytes: etat.octets!, filename: _fichier.nom);
    } catch (e) {
      if (context.mounted) AppFeedback.showError(context, e);
    }
  }

  Future<void> _imprimer(BuildContext context) async {
    try {
      await Printing.layoutPdf(
        onLayout: (_) async => etat.octets!,
        name: _fichier.nom,
      );
    } catch (e) {
      if (context.mounted) AppFeedback.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = partage.demande;
    if (!d.aDocument && !d.aPreuve) {
      return const CarteContenu(
        padding: EdgeInsets.all(AppSizes.xl),
        child: Center(
          child: Text('Aucun fichier n’est joint à cette demande.',
              style: TextStyle(color: AppColors.grisDark)),
        ),
      );
    }

    final fichier = _fichier;
    final octets = etat.octets;
    Widget corps;
    if (etat.erreur != null) {
      corps = _Message(
        icone: Icons.error_outline_rounded,
        texte: etat.erreur!,
        onReessayer: onReessayer,
      );
    } else if (octets == null) {
      corps = _Progression(
        pdf: fichier.pdf,
        nom: fichier.nom,
        recus: etat.recus,
        total: etat.total,
      );
    } else if (fichier.pdf) {
      corps = PdfPreview(
        key: ValueKey(preuve),
        build: (_) async => octets,
        useActions: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: fichier.nom,
        maxPageWidth: 820,
        scrollViewDecoration: const BoxDecoration(color: AppColors.grisLight),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        previewPageMargin: const EdgeInsets.only(bottom: AppSizes.lg),
        padding: const EdgeInsets.all(AppSizes.md),
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: AppColors.rouge),
        ),
      );
    } else {
      corps = ColoredBox(
        color: AppColors.grisLight,
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.memory(octets)),
        ),
      );
    }

    return CarteContenu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Onglets quand la demande a les deux fichiers.
          if (d.aDocument && d.aPreuve)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: _Onglets(preuve: preuve, onChoisir: onChoisir),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                IconeFichier(pdf: fichier.pdf, taille: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fichier.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.noir,
                        ),
                      ),
                      Text(
                        [
                          fichier.libelle,
                          fichier.pdf ? 'PDF' : 'Image',
                          if (fichier.taille != null)
                            formaterTaille(fichier.taille!),
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: preuve ? AppColors.fait : AppColors.grisText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (fichier.pdf)
                  IconButton(
                    tooltip: 'Imprimer',
                    onPressed: octets == null ? null : () => _imprimer(context),
                    icon: const Icon(Icons.print_rounded),
                    color: AppColors.rouge,
                  ),
                IconButton(
                  tooltip: 'Télécharger',
                  onPressed:
                      octets == null ? null : () => _telecharger(context),
                  icon: const Icon(Icons.download_rounded),
                  color: AppColors.rouge,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.grisMedium),
          Expanded(child: corps),
        ],
      ),
    );
  }
}

class _Onglets extends StatelessWidget {
  final bool preuve;
  final ValueChanged<bool> onChoisir;

  const _Onglets({required this.preuve, required this.onChoisir});

  @override
  Widget build(BuildContext context) {
    Widget onglet(bool p, IconData icone, String texte) {
      final actif = preuve == p;
      return Expanded(
        child: Material(
          color: actif ? AppColors.rouge : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: actif ? null : () => onChoisir(p),
            child: SizedBox(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icone,
                      size: 16,
                      color: actif ? Colors.white : AppColors.grisDark),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      texte,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: actif ? Colors.white : AppColors.grisDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Row(
        children: [
          onglet(false, Icons.description_outlined, 'Document de la demande'),
          const SizedBox(width: 3),
          onglet(true, Icons.verified_outlined, 'Preuve de traitement'),
        ],
      ),
    );
  }
}

class _Progression extends StatelessWidget {
  final bool pdf;
  final String nom;
  final int recus;
  final int? total;

  const _Progression({
    required this.pdf,
    required this.nom,
    required this.recus,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final t = total;
    final ratio = t == null || t == 0 ? null : (recus / t).clamp(0.0, 1.0);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconeFichier(pdf: pdf, taille: 56),
              const SizedBox(height: 14),
              const Text(
                'Chargement du document…',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.noir,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  color: AppColors.rouge,
                  backgroundColor: AppColors.grisMedium,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t == null
                          ? formaterTaille(recus)
                          : '${formaterTaille(recus)} sur ${formaterTaille(t)}',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.grisDark),
                    ),
                  ),
                  Text(
                    ratio == null ? '…' : '${(ratio * 100).round()} %',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.rouge,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icone;
  final String texte;
  final VoidCallback? onReessayer;

  const _Message({required this.icone, required this.texte, this.onReessayer});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 40, color: AppColors.grisText),
            const SizedBox(height: 10),
            Text(texte,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grisDark)),
            if (onReessayer != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onReessayer,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LienInvalide extends StatelessWidget {
  const _LienInvalide();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: const CarteContenu(
            padding: EdgeInsets.all(AppSizes.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_off_rounded,
                    size: 48, color: AppColors.grisText),
                SizedBox(height: 12),
                Text(
                  'Ce lien n’est plus valable',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.noir,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Un lien de partage reste valable 7 jours. Demandez un '
                  'nouveau lien à la personne qui vous l’a envoyé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.grisDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
