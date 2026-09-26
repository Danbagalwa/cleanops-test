import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';
import '../../domain/entities/chat_message.dart';

/// Couleur stable d'un auteur (prénom et avatar sans photo).
Color couleurAuteur(String prenom) {
  const palette = [
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFF00838F),
    Color(0xFFAD1457),
    Color(0xFF4527A0),
    Color(0xFF558B2F),
    Color(0xFFE65100),
  ];
  final hash = prenom.codeUnits.fold(0, (a, b) => a + b);
  return palette[hash % palette.length];
}

const couleurEpingle = Color(0xFFE08A00);

class ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMine;

  /// Premier message de la série de cet auteur (affiche le prénom).
  final bool isStreakStart;

  /// Dernier message de la série (affiche l'avatar et la « queue »).
  final bool isStreakEnd;

  /// Options du message (responsable) : appui long sur mobile, clic droit
  /// ou bouton ⋮ au survol sur ordinateur.
  final VoidCallback? onLongPress;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.isStreakStart = true,
    this.isStreakEnd = true,
    this.onLongPress,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _survol = false;

  String get _initiale => widget.message.prenomAuteur.isNotEmpty
      ? widget.message.prenomAuteur[0].toUpperCase()
      : '?';

  String _heure(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final isMine = widget.isMine;
    final debut = widget.isStreakStart;
    final fin = widget.isStreakEnd;
    final largeur = MediaQuery.sizeOf(context).width;
    final maxBulle = (largeur * 0.72).clamp(200.0, 520.0);
    final couleur = couleurAuteur(m.prenomAuteur);

    final fond = isMine ? AppColors.rouge : Colors.white;
    final encre = isMine ? Colors.white : AppColors.noir;
    final discret =
        isMine ? Colors.white.withValues(alpha: 0.72) : AppColors.grisText;

    final radius = isMine
        ? BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: const Radius.circular(16),
            bottomRight: Radius.circular(fin ? 4 : 16),
          )
        : BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fin ? 4 : 16),
            bottomRight: const Radius.circular(16),
          );

    final bulle = GestureDetector(
      onLongPress: widget.onLongPress,
      onSecondaryTap: widget.onLongPress,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBulle),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: fond,
            borderRadius: radius,
            border: m.estEpingle
                ? Border.all(color: couleurEpingle, width: 1.5)
                : isMine
                    ? null
                    : Border.all(color: AppColors.grisMedium),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.estEpingle)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_rounded,
                            size: 11,
                            color: isMine ? Colors.white : couleurEpingle),
                        const SizedBox(width: 3),
                        Text(
                          'Épinglé',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isMine ? Colors.white : couleurEpingle,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!isMine && debut)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      m.prenomAuteur,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: couleur,
                      ),
                    ),
                  ),
                Text(
                  m.message,
                  style: TextStyle(fontSize: 14.5, color: encre, height: 1.4),
                ),
                const SizedBox(height: 2),
                Text(
                  _heure(m.dateEnvoi),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10.5, color: discret),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Bouton ⋮ discret au survol (souris), pour les responsables.
    final options = widget.onLongPress == null
        ? null
        : AnimatedOpacity(
            opacity: _survol ? 1 : 0,
            duration: const Duration(milliseconds: 120),
            child: IconButton(
              tooltip: 'Options du message',
              onPressed: _survol ? widget.onLongPress : null,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              color: AppColors.grisDark,
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          );

    final Widget ligne;
    if (isMine) {
      ligne = Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (options != null) options,
          Flexible(child: bulle),
        ],
      );
    } else {
      ligne = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: fin
                ? AvatarProfil(
                    proprietaire: ProprietairePhoto(
                        TypeProprietairePhoto.employe, m.auteurId),
                    initiales: _initiale,
                    rayon: 16,
                    couleurFond: couleur,
                    tailleTexte: 13,
                    poidsTexte: FontWeight.w600,
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Flexible(child: bulle),
          if (options != null) options,
        ],
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      child: Padding(
        padding: EdgeInsets.only(
          top: debut ? 6 : 1,
          bottom: fin ? 3 : 1,
          left: isMine ? 56 : 12,
          right: isMine ? 12 : 56,
        ),
        child: ligne,
      ),
    );
  }
}
