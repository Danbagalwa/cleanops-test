import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'error_widget.dart';
import 'espace_barre_mobile.dart';
import 'mise_en_page.dart';

/// Lecteur PDF de l'app : en-tête fixe, barre de section (Retour,
/// Imprimer, Télécharger), pages posées comme des feuilles sur fond gris.
/// Double-appui sur une page pour zoomer.
///
/// Le document est généré une seule fois, puis réutilisé pour l'aperçu,
/// l'impression et le téléchargement. Tant que [chargement] est vrai ou
/// qu'une [erreur] est présente (données préalables), rien n'est généré.
class LecteurPdf extends StatefulWidget {
  final String titre;
  final String? sousTitre;
  final IconData icone;
  final String nomFichier;
  final Future<Uint8List> Function() generer;
  final PdfPageFormat format;
  final bool chargement;
  final Object? erreur;
  final VoidCallback? onReessayer;

  const LecteurPdf({
    super.key,
    required this.titre,
    required this.nomFichier,
    required this.generer,
    this.sousTitre,
    this.icone = Icons.picture_as_pdf_rounded,
    this.format = PdfPageFormat.a4,
    this.chargement = false,
    this.erreur,
    this.onReessayer,
  });

  @override
  State<LecteurPdf> createState() => _LecteurPdfState();
}

class _LecteurPdfState extends State<LecteurPdf> {
  Future<Uint8List>? _document;
  bool _occupe = false;

  bool get _pret => !widget.chargement && widget.erreur == null;

  Future<Uint8List> get _doc => _document ??= widget.generer();

  Future<void> _imprimer() async {
    setState(() => _occupe = true);
    try {
      await Printing.layoutPdf(
        onLayout: (_) => _doc,
        name: widget.nomFichier,
        format: widget.format,
      );
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _telecharger() async {
    setState(() => _occupe = true);
    try {
      await Printing.sharePdf(bytes: await _doc, filename: widget.nomFichier);
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  void _regenerer() => setState(() => _document = null);

  @override
  Widget build(BuildContext context) {
    final compact = estCompact(context);
    final marge = compact ? 12.0 : 24.0;
    final actif = _pret && !_occupe;

    Widget apercu;
    if (widget.chargement) {
      apercu = const Center(
          child: CircularProgressIndicator(color: AppColors.rouge));
    } else if (widget.erreur != null) {
      apercu = _Erreur(erreur: widget.erreur!, onReessayer: widget.onReessayer);
    } else {
      apercu = PdfPreview(
        build: (_) => _doc,
        initialPageFormat: widget.format,
        useActions: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: widget.nomFichier,
        maxPageWidth: 860,
        scrollViewDecoration: const BoxDecoration(color: AppColors.grisLight),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        previewPageMargin: const EdgeInsets.only(bottom: AppSizes.lg),
        padding: EdgeInsets.fromLTRB(marge, 4, marge, AppSizes.lg)
            .plusBarre(context),
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: AppColors.rouge),
        ),
        onError: (_, e) => _Erreur(erreur: e, onReessayer: _regenerer),
      );
    }

    return PageAvecEnTete(
      chargement: _occupe,
      enTete: EnTetePage(
        icone: widget.icone,
        titre: widget.titre,
        sousTitre: widget.sousTitre,
      ),
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
                EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.md),
            child: BarreSection(
              titre: 'Aperçu avant impression',
              onRetour: () => Navigator.of(context).maybePop(),
              actions: [
                ActionSection(
                  icone: Icons.print_rounded,
                  infoBulle: 'Imprimer',
                  onPressed: actif ? _imprimer : null,
                ),
                ActionSection(
                  icone: Icons.download_rounded,
                  infoBulle: 'Télécharger le PDF',
                  onPressed: actif ? _telecharger : null,
                ),
              ],
            ),
          ),
          Expanded(child: apercu),
        ],
      ),
    );
  }
}

class _Erreur extends StatelessWidget {
  final Object erreur;
  final VoidCallback? onReessayer;

  const _Erreur({required this.erreur, this.onReessayer});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: AppErrorNotice(error: erreur, onRetry: onReessayer),
        ),
      );
}
