import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Charte commune des documents PDF de CleanOps.
///
/// Police Inter embarquée (assets/fonts) : la police par défaut du paquet
/// `pdf` (Helvetica) n'a pas les caractères au-delà du Latin-1 — tirets
/// « — », apostrophes « ’ », « œ »… — qui s'affichaient en carrés.
class ModelePdf {
  ModelePdf._();

  static final primaire = PdfColor.fromHex('#3732C9');
  static final primaireClair = PdfColor.fromHex('#EEF0FF');
  static final bordure = PdfColor.fromHex('#E1E4EC');
  static final attenue = PdfColor.fromHex('#667085');
  static final discret = PdfColor.fromHex('#B4BAC6');
  static final fond = PdfColor.fromHex('#F7F8FA');
  static final encre = PdfColor.fromHex('#1D2433');

  static const residence = 'Résidence Jazz Teasdale';

  /// Case sans valeur : un tiret discret, jamais une case blanche.
  static const vide = '—';

  static pw.ThemeData? _theme;
  static pw.Font? _semiGras;
  static pw.MemoryImage? _logo;

  static Future<pw.Font> _police(String nom) async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/$nom.ttf'));

  static Future<void> _preparer() async {
    if (_theme != null) return;
    final gras = await _police('Inter-Bold');
    _semiGras = await _police('Inter-SemiBold');
    _logo = pw.MemoryImage(
      (await rootBundle.load('assets/icon/app_icon.png')).buffer.asUint8List(),
    );
    _theme = pw.ThemeData.withFont(
      base: await _police('Inter-Regular'),
      bold: gras,
      italic: await _police('Inter-Italic'),
      boldItalic: gras,
    );
  }

  /// Document vierge à la charte (police, métadonnées).
  static Future<pw.Document> document({
    required String titre,
    required String auteur,
  }) async {
    await _preparer();
    return pw.Document(
      title: titre,
      author: auteur,
      creator: 'CleanOps',
      theme: _theme,
    );
  }

  static String dateGeneration() =>
      DateFormat("dd/MM/yyyy 'à' HH:mm", 'fr_FR').format(DateTime.now());

  /// Informations du bandeau de l'en-tête : date et auteur de l'édition.
  static List<(String, String)> infosGeneration(
    String auteur, [
    List<(String, String)> autres = const [],
  ]) =>
      [('Édité le', dateGeneration()), ('Par', auteur), ...autres];

  // ── En-tête et pied de page ─────────────────────────────

  /// Logo et résidence à gauche, titre du document à droite, double filet ;
  /// sur la première page seulement, un bandeau d'[infos].
  static pw.Widget enTete(
    pw.Context context, {
    required String titre,
    String? sousTitre,
    List<(String, String)> infos = const [],
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(_logo!, width: 30, height: 30),
              pw.SizedBox(width: 9),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CleanOps',
                    style: pw.TextStyle(
                        font: _semiGras, fontSize: 12.5, color: encre),
                  ),
                  pw.Text(
                    residence,
                    style: pw.TextStyle(fontSize: 8, color: attenue),
                  ),
                ],
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      titre.toUpperCase(),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                        color: primaire,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (sousTitre != null && sousTitre.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        sousTitre,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 9, color: attenue),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 2, color: primaire),
          pw.SizedBox(height: 1.2),
          pw.Container(height: 0.6, color: bordure),
          if (context.pageNumber == 1 && infos.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _bandeauInfos(infos),
          ],
        ],
      ),
    );
  }

  static pw.Widget _bandeauInfos(List<(String, String)> infos) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: pw.BoxDecoration(
        color: fond,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: bordure, width: 0.6),
      ),
      child: pw.Row(
        children: [
          for (final (i, (libelle, valeur)) in infos.indexed) ...[
            if (i > 0)
              pw.Container(
                width: 0.6,
                height: 20,
                margin: const pw.EdgeInsets.symmetric(horizontal: 12),
                color: bordure,
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    libelle.toUpperCase(),
                    style: pw.TextStyle(
                        fontSize: 6.5, color: attenue, letterSpacing: 0.5),
                  ),
                  pw.SizedBox(height: 1.5),
                  pw.Text(
                    valeur.trim().isEmpty ? vide : valeur,
                    style: pw.TextStyle(
                        font: _semiGras, fontSize: 9, color: encre),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget piedDePage(pw.Context context) {
    final style = pw.TextStyle(fontSize: 7.5, color: attenue);
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: bordure, width: 0.6)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text('CleanOps · $residence · Document interne',
                style: style),
          ),
          pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: style.copyWith(font: _semiGras),
          ),
        ],
      ),
    );
  }

  // ── Blocs de contenu ────────────────────────────────────

  /// Chiffres clés en cartes côte à côte.
  static pw.Widget chiffresCles(List<(String, String)> valeurs) {
    return pw.Row(
      children: [
        for (final (i, (libelle, valeur)) in valeurs.indexed) ...[
          if (i > 0) pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              // Bordure uniforme : le paquet `pdf` refuse des coins arrondis
              // sur une bordure dont les côtés diffèrent. L'accent bleu est
              // donc une barre à l'intérieur de la carte.
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(5),
                border: pw.Border.all(color: bordure, width: 0.6),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 2.5,
                    height: 26,
                    decoration: pw.BoxDecoration(
                      color: primaire,
                      borderRadius: pw.BorderRadius.circular(1.25),
                    ),
                  ),
                  pw.SizedBox(width: 9),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          libelle.toUpperCase(),
                          style: pw.TextStyle(
                              fontSize: 6.5,
                              color: attenue,
                              letterSpacing: 0.5),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          valeur.trim().isEmpty ? vide : valeur,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13,
                            color: encre,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget titreSection(String titre) {
    return pw.Row(
      children: [
        pw.Container(width: 3, height: 13, color: primaire),
        pw.SizedBox(width: 7),
        pw.Text(
          titre.toUpperCase(),
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
            color: encre,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  /// Remarque en bas de document (légende, précision…).
  static pw.Widget note(String texte) {
    return pw.Text(
      texte,
      style: pw.TextStyle(
        fontSize: 7.5,
        color: attenue,
        fontStyle: pw.FontStyle.italic,
      ),
    );
  }

  static pw.Widget etatVide(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(24),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: fond,
        border: pw.Border.all(color: bordure, width: 0.6),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        message,
        style: pw.TextStyle(fontSize: 10, color: attenue),
      ),
    );
  }

  // ── Tableaux ────────────────────────────────────────────

  /// Tableau à la charte : en-tête coloré répété à chaque page, lignes
  /// alternées, filets fins. Une valeur nulle ou vide s'affiche en tiret
  /// discret. [accentuees] : colonnes mises en valeur (couleur, semi-gras).
  static pw.Widget tableau({
    required List<String> entetes,
    required List<List<String?>> lignes,
    Map<int, pw.TableColumnWidth> largeurs = const {},
    Set<int> centrees = const {},
    Set<int> accentuees = const {},
    Set<int> grasses = const {},
    double taille = 8.5,
  }) {
    final filet = pw.BorderSide(color: bordure, width: 0.6);
    return pw.Table(
      columnWidths: largeurs,
      defaultColumnWidth: const pw.FlexColumnWidth(),
      border: pw.TableBorder(
        top: filet,
        bottom: filet,
        left: filet,
        right: filet,
        horizontalInside: filet,
      ),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: primaire),
          children: [
            for (final (i, entete) in entetes.indexed)
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: pw.Text(
                  entete,
                  textAlign: centrees.contains(i)
                      ? pw.TextAlign.center
                      : pw.TextAlign.left,
                  style: pw.TextStyle(
                    font: _semiGras,
                    fontSize: taille,
                    color: PdfColors.white,
                  ),
                ),
              ),
          ],
        ),
        for (final (n, ligne) in lignes.indexed)
          pw.TableRow(
            decoration:
                pw.BoxDecoration(color: n.isOdd ? fond : PdfColors.white),
            children: [
              for (final (i, valeur) in ligne.indexed)
                cellule(
                  valeur,
                  centree: centrees.contains(i),
                  accentuee: accentuees.contains(i),
                  grasse: grasses.contains(i),
                  taille: taille,
                ),
            ],
          ),
      ],
    );
  }

  static pw.Widget cellule(
    String? valeur, {
    bool centree = false,
    bool accentuee = false,
    bool grasse = false,
    double taille = 8.5,
  }) {
    final estVide = valeur == null || valeur.trim().isEmpty;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        estVide ? vide : valeur,
        textAlign: estVide || centree ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: taille,
          lineSpacing: 1.8,
          font: !estVide && (accentuee || grasse) ? _semiGras : null,
          color: estVide
              ? discret
              : accentuee
                  ? primaire
                  : encre,
        ),
      ),
    );
  }

  // ── Mise en forme des valeurs ───────────────────────────

  /// « 1h30 », « 45 min » ; `null` (case vide) pour zéro.
  static String? duree(int minutes) {
    if (minutes <= 0) return null;
    final heures = minutes ~/ 60;
    final reste = minutes % 60;
    if (heures == 0) return '$reste min';
    if (reste == 0) return '${heures}h';
    return '${heures}h${reste.toString().padLeft(2, '0')}';
  }
}
