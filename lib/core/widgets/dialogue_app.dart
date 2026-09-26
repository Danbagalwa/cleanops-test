import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Dialogue standard de l'app : titre en capitales + bouton de fermeture,
/// séparateur, contenu défilant, séparateur, puis l'action principale en
/// pilule alignée à droite. Sur mobile il occupe la largeur disponible.
class DialogueApp extends StatelessWidget {
  final String titre;
  final Widget contenu;
  final String libelleAction;

  /// `null` désactive le bouton principal (saisie incomplète).
  final VoidCallback? onAction;

  /// Affiche un indicateur dans le bouton principal et bloque la fermeture.
  final bool enCours;

  /// Bouton secondaire facultatif (ex. « Annuler »), à gauche de la pilule.
  final String? libelleSecondaire;
  final VoidCallback? onSecondaire;

  /// Par défaut ferme le dialogue.
  final VoidCallback? onFermer;
  final double largeur;

  const DialogueApp({
    super.key,
    required this.titre,
    required this.contenu,
    required this.libelleAction,
    required this.onAction,
    this.enCours = false,
    this.libelleSecondaire,
    this.onSecondaire,
    this.onFermer,
    this.largeur = 480,
  });

  @override
  Widget build(BuildContext context) {
    final fermer = onFermer ?? () => Navigator.of(context).maybePop();
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largeur),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Titre ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      titre.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.noir,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: enCours ? null : fermer,
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: AppColors.grisDark),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Contenu ────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: contenu,
              ),
            ),
            const Divider(height: 1),

            // ── Pied ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (libelleSecondaire != null) ...[
                    TextButton(
                      onPressed: enCours ? null : (onSecondaire ?? fermer),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.grisDark,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        minimumSize: const Size(0, 44),
                      ),
                      child: Text(libelleSecondaire!),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton(
                    onPressed: enCours ? null : onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rouge,
                      disabledBackgroundColor:
                          AppColors.rouge.withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      minimumSize: const Size(0, 44),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: enCours
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(libelleAction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
