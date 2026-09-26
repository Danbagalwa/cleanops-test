import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';

/// Zone de saisie du chat. Sur ordinateur, Entrée envoie et Maj+Entrée
/// passe à la ligne.
class ChatInputWidget extends StatefulWidget {
  final bool isSending;
  final void Function(String) onEnvoyer;

  const ChatInputWidget({
    super.key,
    required this.isSending,
    required this.onEnvoyer,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final _controller = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _clavier);
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _clavier(FocusNode _, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _envoyer();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _envoyer() {
    final texte = _controller.text.trim();
    if (texte.isEmpty || widget.isSending) return;
    widget.onEnvoyer(texte);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: !widget.isSending,
              maxLines: 5,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 14.5, color: AppColors.noir),
              decoration: InputDecoration(
                hintText: 'Écrire un message à l’équipe…',
                hintStyle:
                    const TextStyle(color: AppColors.grisText, fontSize: 14),
                filled: true,
                fillColor: AppColors.grisLight,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide:
                      const BorderSide(color: AppColors.rouge, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(
            enabled: _hasText && !widget.isSending,
            isSending: widget.isSending,
            onTap: _envoyer,
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool isSending;
  final VoidCallback onTap;

  const _SendButton({
    required this.enabled,
    required this.isSending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Envoyer',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? AppColors.rouge : AppColors.grisMedium,
          shape: BoxShape.circle,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: const CircleBorder(),
            child: Center(
              child: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      size: 19, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
