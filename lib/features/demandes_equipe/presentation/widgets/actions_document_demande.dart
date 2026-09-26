import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/compression_photo.dart' show formaterTaille;
import '../../../../core/services/partage_natif.dart';
import '../../../../core/widgets/dialogue_app.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/transfert_document_demande.dart';
import '../../domain/entities/demande_equipe.dart';
import '../screens/document_demande_screen.dart';

bool estPdfDemande(DemandeEquipe d) =>
    d.documentTypeMime == 'application/pdf' ||
    (d.documentNom?.toLowerCase().endsWith('.pdf') ?? false);

/// Un fichier d'une demande : le document joint par l'employé, ou la preuve
/// de traitement jointe par le responsable. Les deux ont le même menu.
class FichierDemande {
  final DemandeEquipe demande;
  final bool preuve;

  const FichierDemande(this.demande, {this.preuve = false});

  String get nom =>
      (preuve ? demande.preuveNom : demande.documentNom) ?? 'document';
  String? get typeMime =>
      preuve ? demande.preuveTypeMime : demande.documentTypeMime;
  int? get taille => preuve ? demande.preuveTaille : demande.documentTaille;
  bool get pdf =>
      typeMime == 'application/pdf' || nom.toLowerCase().endsWith('.pdf');

  /// Emplacement dans Storage.
  String get chemin => preuve ? demande.cheminPreuve : demande.id;
  String get libelle => preuve ? 'Preuve de traitement' : 'Document joint';
}

// ══════════════════════════════════════════════════════════
// ICÔNE DE FICHIER (façon « feuille » avec étiquette PDF / IMG)
// ══════════════════════════════════════════════════════════

class IconeFichier extends StatelessWidget {
  final bool pdf;
  final double taille;

  const IconeFichier({super.key, required this.pdf, this.taille = 40});

  @override
  Widget build(BuildContext context) {
    final couleur = pdf ? const Color(0xFFD93025) : const Color(0xFF1A73E8);
    final largeur = taille * 0.8;
    return SizedBox(
      width: largeur,
      height: taille,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Feuille au coin replié.
          Positioned.fill(
            child: ClipPath(
              clipper: _CoinReplie(taille * 0.26),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F4),
                  border: Border.all(color: const Color(0xFFDADCE0)),
                  borderRadius: BorderRadius.circular(taille * 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: taille * 0.26,
              height: taille * 0.26,
              decoration: BoxDecoration(
                color: const Color(0xFFDADCE0),
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(taille * 0.06)),
              ),
            ),
          ),
          // Étiquette de type.
          Positioned(
            left: -taille * 0.08,
            bottom: taille * 0.16,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: taille * 0.08, vertical: taille * 0.02),
              decoration: BoxDecoration(
                color: couleur,
                borderRadius: BorderRadius.circular(taille * 0.06),
              ),
              child: Text(
                pdf ? 'PDF' : 'IMG',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: taille * 0.24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinReplie extends CustomClipper<Path> {
  final double coin;
  const _CoinReplie(this.coin);

  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width - coin, 0)
    ..lineTo(s.width, coin)
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();

  @override
  bool shouldReclip(_CoinReplie old) => old.coin != coin;
}

// ══════════════════════════════════════════════════════════
// MENU D'OPTIONS
// ══════════════════════════════════════════════════════════

enum _ActionDocument { ouvrir, telecharger, partagerFichier, partagerLien }

/// Bouton ⋮ des options du document. Volontairement sans InkWell : la tuile
/// qui le contient reste la seule zone « appui = ouvrir ».
class MenuDocumentDemande extends ConsumerWidget {
  final DemandeEquipe demande;
  final Widget? enfant;

  /// Menu de la preuve de traitement plutôt que du document de l'employé.
  final bool preuve;

  const MenuDocumentDemande({
    super.key,
    required this.demande,
    this.enfant,
    this.preuve = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: preuve ? 'Options de la preuve' : 'Options du document',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              _ouvrirMenu(context, ref, details.globalPosition),
          child: enfant ??
              const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.more_vert_rounded,
                    size: 20, color: AppColors.rouge),
              ),
        ),
      ),
    );
  }

  Future<void> _ouvrirMenu(
      BuildContext context, WidgetRef ref, Offset position) async {
    final fichier = FichierDemande(demande, preuve: preuve);
    final taille = fichier.taille;
    PopupMenuItem<_ActionDocument> item(
            _ActionDocument a, IconData icone, String texte,
            [String? detail]) =>
        PopupMenuItem(
          value: a,
          child: Row(
            children: [
              Icon(icone, size: 19, color: AppColors.rouge),
              const SizedBox(width: 12),
              Expanded(child: Text(texte)),
              if (detail != null) ...[
                const SizedBox(width: 12),
                Text(detail,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.grisText)),
              ],
            ],
          ),
        );

    final choix = await showMenu<_ActionDocument>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        item(_ActionDocument.ouvrir, Icons.open_in_new_rounded, 'Ouvrir'),
        item(_ActionDocument.telecharger, Icons.download_rounded, 'Télécharger',
            taille == null ? null : formaterTaille(taille)),
        item(_ActionDocument.partagerFichier, Icons.ios_share_rounded,
            fichier.pdf ? 'Partager le PDF' : 'Partager (en PDF)'),
        item(_ActionDocument.partagerLien, Icons.link_rounded,
            'Partager le lien'),
      ],
    );
    if (choix == null || !context.mounted) return;
    switch (choix) {
      case _ActionDocument.ouvrir:
        ouvrirFichierDemande(context, fichier);
      case _ActionDocument.telecharger:
        await telechargerFichierDemande(context, ref, fichier);
      case _ActionDocument.partagerFichier:
        await partagerFichierDemande(context, ref, fichier);
      case _ActionDocument.partagerLien:
        await partagerLienDocumentDemande(context, ref, demande);
    }
  }
}

// ══════════════════════════════════════════════════════════
// ACTIONS
// ══════════════════════════════════════════════════════════

void ouvrirFichierDemande(BuildContext context, FichierDemande fichier) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => DocumentDemandeScreen(
      demandeId: fichier.demande.id,
      nom: fichier.nom,
      preuve: fichier.preuve ? fichier.demande : null,
    ),
  ));
}

/// Récupère le fichier en affichant la progression ; `null` si annulé ou en
/// échec (le dialogue a déjà informé l'utilisateur).
Future<Uint8List?> _recuperer(
    BuildContext context, WidgetRef ref, FichierDemande fichier,
    {required String titre}) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogueTelechargement(
      fichier: fichier,
      titre: titre,
      transfert: ref.read(transfertDocumentDemandeProvider),
    ),
  );
}

Future<void> telechargerFichierDemande(
    BuildContext context, WidgetRef ref, FichierDemande fichier) async {
  final octets = await _recuperer(context, ref, fichier,
      titre: fichier.preuve
          ? 'Téléchargement de la preuve'
          : 'Téléchargement du document');
  if (octets == null || !context.mounted) return;
  // Web : enregistre le fichier ; mobile : feuille « Enregistrer / Partager ».
  await Printing.sharePdf(bytes: octets, filename: fichier.nom);
  if (context.mounted && kIsWeb) {
    NotificationApp.succes(
      context,
      '${fichier.nom} a été téléchargé (${formaterTaille(octets.length)}).',
      titre: 'Téléchargement terminé',
    );
  }
}

Future<void> partagerFichierDemande(
    BuildContext context, WidgetRef ref, FichierDemande fichier) async {
  final octets =
      await _recuperer(context, ref, fichier, titre: 'Préparation du partage');
  if (octets == null || !context.mounted) return;

  // Une image est partagée sous forme de PDF d'une page.
  final pdf = fichier.pdf;
  final nomBase = fichier.nom.replaceFirst(RegExp(r'\.[^.]+$'), '');
  final nom = pdf ? fichier.nom : '$nomBase.pdf';
  final contenu = pdf ? octets : await _imageEnPdf(octets);
  if (!context.mounted) return;

  // Web : le navigateur n'accepte le partage qu'au moment d'un clic. Le
  // téléchargement ayant pris du temps, on demande ce clic dans un dialogue.
  if (kIsWeb && peutPartagerFichierNatif('application/pdf')) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => DialogueApp(
        titre: 'Document prêt',
        largeur: 440,
        libelleAction: 'Partager',
        libelleSecondaire: 'Télécharger',
        onAction: () async {
          final ok =
              await partagerFichierNatif(contenu, nom, 'application/pdf');
          if (!ctx.mounted) return;
          Navigator.of(ctx).pop();
          if (!ok) await Printing.sharePdf(bytes: contenu, filename: nom);
        },
        onSecondaire: () async {
          Navigator.of(ctx).pop();
          await Printing.sharePdf(bytes: contenu, filename: nom);
        },
        contenu: _ResumeFichier(
          pdf: true,
          nom: nom,
          detail: 'PDF · ${formaterTaille(contenu.length)}',
        ),
      ),
    );
    return;
  }

  // Mobile : feuille système de partage. Web sans partage : téléchargement.
  await Printing.sharePdf(bytes: contenu, filename: nom);
  if (context.mounted && kIsWeb) {
    NotificationApp.info(
      context,
      'Ce navigateur ne permet pas le partage direct : le PDF a été '
      'téléchargé pour que vous puissiez l’envoyer.',
    );
  }
}

/// Ouvre le dialogue du lien de partage : le lien est créé, puis affiché
/// avec « Copier » et, si le navigateur le permet, « Partager… ».
Future<void> partagerLienDocumentDemande(
    BuildContext context, WidgetRef ref, DemandeEquipe demande) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DialogueLienPartage(demande: demande),
  );
}

class _ResumeFichier extends StatelessWidget {
  final bool pdf;
  final String nom;
  final String detail;

  const _ResumeFichier({
    required this.pdf,
    required this.nom,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconeFichier(pdf: pdf, taille: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nom,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.noir,
                ),
              ),
              Text(detail,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.grisText)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialogueLienPartage extends ConsumerStatefulWidget {
  final DemandeEquipe demande;
  const _DialogueLienPartage({required this.demande});

  @override
  ConsumerState<_DialogueLienPartage> createState() =>
      _DialogueLienPartageState();
}

class _DialogueLienPartageState extends ConsumerState<_DialogueLienPartage> {
  String? _url;
  String? _erreur;
  bool _copie = false;

  @override
  void initState() {
    super.initState();
    _creer();
  }

  Future<void> _creer() async {
    setState(() {
      _erreur = null;
      _url = null;
    });
    try {
      final url = await ref
          .read(transfertDocumentDemandeProvider)
          .creerLienPartage(
              widget.demande, ref.read(employeeCourantProvider)?.id ?? '');
      if (mounted) setState(() => _url = url);
    } on ErreurTransfert catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _erreur =
            'Le lien de partage n’a pas pu être créé. Vérifiez votre connexion.');
      }
    }
  }

  Future<void> _copier() async {
    await Clipboard.setData(ClipboardData(text: _url!));
    if (!mounted) return;
    setState(() => _copie = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copie = false);
    });
  }

  Future<void> _partager() async {
    final ok = await partagerLienNatif(
        _url!, 'Demande — ${widget.demande.documentNom ?? 'document'}');
    if (!ok) await _copier();
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    final natif = peutPartagerLienNatif();
    final expire = DateFormat('d MMMM yyyy', 'fr_FR')
        .format(DateTime.now().add(TransfertDocumentDemande.dureePartage));

    final Widget contenu;
    if (_erreur != null) {
      contenu = Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 20, color: AppColors.refus),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_erreur!,
                style: const TextStyle(fontSize: 13.5, color: AppColors.refus)),
          ),
        ],
      );
    } else if (url == null) {
      contenu = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.rouge),
            SizedBox(height: 12),
            Text('Création du lien…',
                style: TextStyle(fontSize: 13, color: AppColors.grisDark)),
          ],
        ),
      );
    } else {
      contenu = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ce lien ouvre une page avec le document, l’état de la demande '
            'et la réponse du responsable. Aucune connexion n’est nécessaire.',
            style: TextStyle(
                fontSize: 13.5, height: 1.4, color: AppColors.grisDark),
          ),
          const SizedBox(height: 14),
          // Lien sélectionnable + bouton copier.
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              color: AppColors.grisLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _copie ? AppColors.fait : AppColors.grisMedium,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded,
                    size: 18, color: AppColors.grisDark),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    url,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 13, color: AppColors.noir),
                  ),
                ),
                TextButton.icon(
                  onPressed: _copier,
                  style: TextButton.styleFrom(
                    foregroundColor: _copie ? AppColors.fait : AppColors.rouge,
                  ),
                  icon: Icon(
                    _copie ? Icons.check_rounded : Icons.copy_rounded,
                    size: 17,
                  ),
                  label: Text(_copie ? 'Copié' : 'Copier'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.lock_clock_outlined,
                  size: 15, color: AppColors.grisText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Valable 7 jours, jusqu’au $expire.',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.grisText),
                ),
              ),
              if (kIsWeb)
                TextButton.icon(
                  onPressed: () => ouvrirDansNouvelOnglet(url),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Aperçu'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.rouge,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return DialogueApp(
      titre: 'Partager le lien',
      largeur: 520,
      libelleAction: _erreur != null
          ? 'Réessayer'
          : natif
              ? 'Partager…'
              : (_copie ? 'Lien copié' : 'Copier le lien'),
      onAction: _erreur != null
          ? _creer
          : url == null
              ? null
              : (natif ? _partager : _copier),
      libelleSecondaire: 'Fermer',
      contenu: contenu,
    );
  }
}

Future<Uint8List> _imageEnPdf(Uint8List image) async {
  final doc = pw.Document();
  final img = pw.MemoryImage(image);
  doc.addPage(pw.Page(
    build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
  ));
  return doc.save();
}

// ══════════════════════════════════════════════════════════
// DIALOGUE DE TÉLÉCHARGEMENT (progression + taille)
// ══════════════════════════════════════════════════════════

class _DialogueTelechargement extends StatefulWidget {
  final FichierDemande fichier;
  final String titre;
  final TransfertDocumentDemande transfert;

  const _DialogueTelechargement({
    required this.fichier,
    required this.titre,
    required this.transfert,
  });

  @override
  State<_DialogueTelechargement> createState() =>
      _DialogueTelechargementState();
}

class _DialogueTelechargementState extends State<_DialogueTelechargement> {
  final _annulation = AnnulationTransfert();
  int _recus = 0;
  int? _total;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _total = widget.fichier.taille;
    _lancer();
  }

  Future<void> _lancer() async {
    setState(() {
      _erreur = null;
      _recus = 0;
    });
    try {
      final octets = await widget.transfert.telecharger(
        widget.fichier.chemin,
        tailleConnue: widget.fichier.taille,
        annulation: _annulation,
        onProgression: (recus, total) {
          if (!mounted) return;
          setState(() {
            _recus = recus;
            _total = total ?? _total;
          });
        },
      );
      if (mounted) Navigator.of(context).pop(octets);
    } catch (e) {
      if (!mounted || _annulation.annule) return;
      setState(() => _erreur = e.toString());
    }
  }

  void _annuler() {
    _annulation.annuler();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final ratio =
        total == null || total == 0 ? null : (_recus / total).clamp(0.0, 1.0);
    final texteTaille = total == null
        ? formaterTaille(_recus)
        : '${formaterTaille(_recus)} sur ${formaterTaille(total)}';

    return DialogueApp(
      titre: widget.titre,
      largeur: 440,
      libelleAction: _erreur == null ? 'Annuler' : 'Réessayer',
      onAction: _erreur == null ? _annuler : _lancer,
      libelleSecondaire: _erreur == null ? null : 'Fermer',
      onFermer: _annuler,
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconeFichier(pdf: widget.fichier.pdf, taille: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.fichier.nom,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.noir,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.fichier.taille == null
                          ? widget.fichier.libelle
                          : '${widget.fichier.libelle} · '
                              '${formaterTaille(widget.fichier.taille!)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grisText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_erreur != null)
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 18, color: AppColors.refus),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _erreur!,
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.refus),
                  ),
                ),
              ],
            )
          else ...[
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
                    texteTaille,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.grisDark),
                  ),
                ),
                Text(
                  ratio == null ? 'En cours…' : '${(ratio * 100).round()} %',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.rouge,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
