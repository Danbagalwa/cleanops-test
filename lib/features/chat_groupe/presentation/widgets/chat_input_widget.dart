import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

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
    super.dispose();
  }

  void _envoyer() {
    final texte = _controller.text.trim();
    if (texte.isEmpty || widget.isSending) return;
    widget.onEnvoyer(texte);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 8, 8 + bottomPad),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            offset: const Offset(0, -1),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Champ de texte ──────────────────────────────
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                enabled: !widget.isSending,
                maxLines: 5,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14.5, color: Color(0xFF111B21)),
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  hintStyle: TextStyle(
                    color: Color(0xFFADB5BD),
                    fontSize: 14.5,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onSubmitted: (_) => _envoyer(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── Bouton envoyer ──────────────────────────────
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: enabled ? AppColors.rouge : const Color(0xFFCDD6E0),
        shape: BoxShape.circle,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.rouge.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
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
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
          ),
        ),
      ),
    );
  }
}
