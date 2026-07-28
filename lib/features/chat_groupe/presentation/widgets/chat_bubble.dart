import 'package:flutter/material.dart';
import '../../domain/entities/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  /// Premier message de la série de cet auteur (affiche prénom + coin supérieur pointu)
  final bool isStreakStart;

  /// Dernier message de la série (affiche avatar + coin inférieur pointu = queue)
  final bool isStreakEnd;

  final VoidCallback? onLongPress;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.isStreakStart = true,
    this.isStreakEnd = true,
    this.onLongPress,
  });

  // Palette de couleurs pour identifier les auteurs
  static const _palette = [
    Color(0xFF1565C0), // bleu
    Color(0xFF2E7D32), // vert
    Color(0xFF6A1B9A), // violet
    Color(0xFF00838F), // cyan
    Color(0xFFAD1457), // rose
    Color(0xFF4527A0), // indigo
    Color(0xFF558B2F), // vert olive
    Color(0xFFE65100), // orange
  ];

  Color _prenomColor() {
    final hash = message.prenomAuteur.codeUnits.fold(0, (a, b) => a + b);
    return _palette[hash % _palette.length];
  }

  String get _initiale =>
      message.prenomAuteur.isNotEmpty
          ? message.prenomAuteur[0].toUpperCase()
          : '?';

  String _heure(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Max ~72% de la largeur, entre 200 et 500px
    final maxBubbleWidth = (screenWidth * 0.72).clamp(200.0, 500.0);
    final isEpingle = message.estEpingle;
    final prenomColor = _prenomColor();

    // ── Couleurs de bulle ──────────────────────────────────
    final bubbleColor = isEpingle
        ? const Color(0xFFFFF9C4)
        : isMine
            ? const Color(0xFFEAEAFF) // indigo très clair pour mes messages
            : Colors.white;

    // ── Rayons style WhatsApp ──────────────────────────────
    // Queue pointue en bas à l'extérieur pour le dernier d'une série
    final BorderRadius radius;
    if (isMine) {
      radius = BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: const Radius.circular(18),
        bottomRight: Radius.circular(isStreakEnd ? 4 : 18),
      );
    } else {
      radius = BorderRadius.only(
        topLeft: Radius.circular(isStreakStart ? 4 : 18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(isStreakEnd ? 4 : 18),
        bottomRight: const Radius.circular(18),
      );
    }

    // ── Contenu de la bulle ────────────────────────────────
    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
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
                // Indicateur épinglé
                if (isEpingle)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_rounded,
                            size: 10, color: Color(0xFFE65100)),
                        SizedBox(width: 3),
                        Text(
                          'Épinglé',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Prénom auteur (premier message de la série)
                if (!isMine && isStreakStart)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      message.prenomAuteur,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: prenomColor,
                      ),
                    ),
                  ),

                // Texte du message
                Text(
                  message.message,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF111B21),
                    height: 1.4,
                  ),
                ),

                // Heure en bas-droite dans la bulle
                const SizedBox(height: 2),
                Text(
                  _heure(message.dateEnvoi),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0x88111B21),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // ── Mise en page (avec avatar pour les autres) ─────────
    if (isMine) {
      return Padding(
        padding: EdgeInsets.only(
          top: isStreakStart ? 6 : 1,
          bottom: isStreakEnd ? 3 : 1,
          left: 56,
          right: 10,
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: bubble,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: isStreakStart ? 6 : 1,
        bottom: isStreakEnd ? 3 : 1,
        left: 10,
        right: 56,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar visible uniquement sur le dernier de la série
          SizedBox(
            width: 32,
            height: 32,
            child: isStreakEnd
                ? CircleAvatar(
                    radius: 16,
                    backgroundColor: prenomColor,
                    child: Text(
                      _initiale,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 4),
          bubble,
        ],
      ),
    );
  }
}
