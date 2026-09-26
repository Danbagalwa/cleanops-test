import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../errors/user_friendly_error.dart';

enum TypeNotification { succes, erreur, avertissement, info }

extension on TypeNotification {
  Color get couleur => switch (this) {
        TypeNotification.succes => AppColors.fait,
        TypeNotification.erreur => AppColors.nonAutorise,
        TypeNotification.avertissement => const Color(0xFFD9900B),
        TypeNotification.info => AppColors.rouge,
      };

  IconData get icone => switch (this) {
        TypeNotification.succes => Icons.check_circle_rounded,
        TypeNotification.erreur => Icons.error_rounded,
        TypeNotification.avertissement => Icons.warning_amber_rounded,
        TypeNotification.info => Icons.info_rounded,
      };
}

/// Notification unique de l'app (remplace les SnackBar faits à la main) :
/// carte blanche flottante, barre et icône de la couleur du [TypeNotification],
/// titre facultatif, fermeture manuelle. Sur grand écran elle garde une
/// largeur de lecture ; sur mobile elle se pose au-dessus de la barre en verre.
class NotificationApp {
  NotificationApp._();

  static void succes(
    BuildContext context,
    String message, {
    String? titre,
    String? libelleAction,
    VoidCallback? onAction,
  }) =>
      afficher(
        context,
        message,
        titre: titre,
        type: TypeNotification.succes,
        libelleAction: libelleAction,
        onAction: onAction,
      );

  static void erreur(BuildContext context, String message, {String? titre}) =>
      afficher(context, message, titre: titre, type: TypeNotification.erreur);

  static void avertissement(BuildContext context, String message,
          {String? titre}) =>
      afficher(context, message,
          titre: titre, type: TypeNotification.avertissement);

  static void info(BuildContext context, String message, {String? titre}) =>
      afficher(context, message, titre: titre, type: TypeNotification.info);

  /// Erreur technique traduite pour l'utilisateur (titre et message clairs,
  /// jamais de détail technique). Connexion ou service lent → avertissement.
  static void depuisErreur(BuildContext context, Object? erreur) {
    final e = UserFriendlyError.from(erreur);
    final passager = e.kind == UserErrorKind.connection ||
        e.kind == UserErrorKind.unavailable ||
        e.kind == UserErrorKind.session;
    afficher(
      context,
      e.message,
      titre: e.title,
      type: passager ? TypeNotification.avertissement : TypeNotification.erreur,
    );
  }

  static void afficher(
    BuildContext context,
    String message, {
    TypeNotification type = TypeNotification.info,
    String? titre,
    Duration? duree,
    String? libelleAction,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final large = MediaQuery.sizeOf(context).width >= 600;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          width: large ? 420 : null,
          margin: large ? null : const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: EdgeInsets.zero,
          elevation: 0,
          backgroundColor: Colors.transparent,
          duration: duree ??
              (type == TypeNotification.erreur
                  ? const Duration(seconds: 6)
                  : const Duration(seconds: 4)),
          content: _CarteNotification(
            type: type,
            titre: titre,
            message: message,
            libelleAction: libelleAction,
            onAction: onAction == null
                ? null
                : () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
            onFermer: messenger.hideCurrentSnackBar,
          ),
        ),
      );
  }
}

class _CarteNotification extends StatelessWidget {
  final TypeNotification type;
  final String? titre;
  final String message;
  final String? libelleAction;
  final VoidCallback? onAction;
  final VoidCallback onFermer;

  const _CarteNotification({
    required this.type,
    required this.titre,
    required this.message,
    required this.libelleAction,
    required this.onAction,
    required this.onFermer,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = type.couleur;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: couleur),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: couleur.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(type.icone, color: couleur, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (titre != null)
                              Text(
                                titre!,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.noir,
                                ),
                              ),
                            Text(
                              message,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: titre == null
                                    ? AppColors.noir
                                    : AppColors.grisDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onAction != null)
                        TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.rouge,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(libelleAction ?? 'Annuler'),
                        ),
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: onFermer,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.grisText),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
