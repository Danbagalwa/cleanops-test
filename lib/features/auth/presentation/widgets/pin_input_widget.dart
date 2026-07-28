import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Pour HapticFeedback
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class PinInputWidget extends StatefulWidget {
  final String slug;
  final bool isLoading;
  final String? error;
  final int pinLength;
  final Function(String pin) onPinComplete;

  const PinInputWidget({
    super.key,
    required this.slug,
    required this.isLoading,
    required this.onPinComplete,
    this.error,
    this.pinLength = 4,
  });

  @override
  State<PinInputWidget> createState() => _PinInputWidgetState();
}

class _PinInputWidgetState extends State<PinInputWidget> {
  final List<String> _pin = [];

  void _onDigit(String digit) {
    if (_pin.length >= widget.pinLength || widget.isLoading) return;

    HapticFeedback.lightImpact();
    setState(() => _pin.add(digit));

    if (_pin.length == widget.pinLength) {
      Future.delayed(const Duration(milliseconds: 250), () {
        widget.onPinComplete(_pin.join());
      });
    }
  }

  void _onDelete() {
    if (_pin.isEmpty || widget.isLoading) return;
    HapticFeedback.selectionClick();
    setState(() => _pin.removeLast());
  }

  void _onClear() {
    if (widget.isLoading || _pin.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _pin.clear());
  }

  @override
  void didUpdateWidget(PinInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error != null && oldWidget.error == null) {
      HapticFeedback.vibrate();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _pin.clear());
      });
    }
    // Si pinLength change (changement de rôle), on reset le PIN
    if (widget.pinLength != oldWidget.pinLength) {
      _pin.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Indicateurs PIN ──────────────────────────────
        _PinDots(
          filled: _pin.length,
          total: widget.pinLength,
          hasError: widget.error != null,
        )
            .animate(target: widget.error != null ? 1 : 0)
            .shakeX(amount: 6, hz: 4),

        const SizedBox(height: AppSizes.md),

        // ── Message erreur ───────────────────────────────
        SizedBox(
          height: 20,
          child: AnimatedSwitcher(
            duration: 200.ms,
            child: widget.error != null
                ? Text(
                    widget.error!,
                    key: ValueKey(widget.error),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),

        const SizedBox(height: AppSizes.xl),

        // ── Clavier numérique ────────────────────────────
        _NumericKeyboard(
          onDigit: _onDigit,
          onDelete: _onDelete,
          onClear: _onClear,
          isLoading: widget.isLoading,
        ),
      ],
    );
  }
}

// ── Points PIN ────────────────────────────────────────────
class _PinDots extends StatelessWidget {
  final int filled;
  final int total;
  final bool hasError;

  const _PinDots({
    required this.filled,
    required this.total,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    // Pour PIN long (8 chiffres), réduire la taille et l'espacement
    final isLong = total > 6;
    final dotSizeFilled = isLong ? 14.0 : 20.0;
    final dotSizeEmpty = isLong ? 11.0 : 16.0;
    final spacing = isLong ? 6.0 : 12.0;

    return Wrap(
      alignment: WrapAlignment.center,
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: 250.ms,
          curve: Curves.easeOut,
          margin: EdgeInsets.symmetric(horizontal: spacing / 2, vertical: 4),
          width: isFilled ? dotSizeFilled : dotSizeEmpty,
          height: isFilled ? dotSizeFilled : dotSizeEmpty,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasError
                ? Colors.redAccent
                : (isFilled ? AppColors.rouge : Colors.transparent),
            border: Border.all(
              color: hasError
                  ? Colors.redAccent
                  : (isFilled ? AppColors.rouge : AppColors.grisMedium),
              width: 2.5,
            ),
            boxShadow: isFilled && !hasError
                ? [
                    BoxShadow(
                      color: AppColors.rouge.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

// ── Clavier numérique ─────────────────────────────────────
class _NumericKeyboard extends StatelessWidget {
  final Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final bool isLoading;

  const _NumericKeyboard({
    required this.onDigit,
    required this.onDelete,
    required this.onClear,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonSize = (constraints.maxWidth / 3) - AppSizes.md;
        final size = buttonSize.clamp(56.0, 75.0);

        return Column(
          children: keys.map((row) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                return _KeyButton(
                  label: key,
                  isLoading: isLoading,
                  size: size,
                  onTap: () {
                    if (key == '⌫') {
                      onDelete();
                    } else if (key == 'C') {
                      onClear();
                    } else {
                      onDigit(key);
                    }
                  },
                  isSpecial: key == '⌫' || key == 'C',
                );
              }).toList(),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Touche du clavier ─────────────────────────────────────
class _KeyButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isSpecial;
  final double size;

  const _KeyButton({
    required this.label,
    required this.onTap,
    required this.isLoading,
    required this.size,
    this.isSpecial = false,
  });

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSizes.sm,
        horizontal: AppSizes.xs,
      ),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: 100.ms,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color,
            boxShadow: _isPressed
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: widget.label == '⌫'
                ? Icon(
                    Icons.backspace_outlined,
                    color: AppColors.rouge,
                    size: widget.size * 0.32,
                  )
                : Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: widget.isSpecial
                          ? widget.size * 0.24
                          : widget.size * 0.36,
                      fontWeight: FontWeight.w600,
                      color:
                          widget.isSpecial ? AppColors.rouge : AppColors.noir,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Color get _color {
    if (widget.isLoading) return AppColors.grisLight;
    if (_isPressed) return AppColors.grisMedium.withValues(alpha:0.5);
    return widget.isSpecial
        ? AppColors.grisLight.withValues(alpha:0.3)
        : Colors.white;
  }
}
