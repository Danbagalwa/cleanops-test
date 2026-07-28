import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class PinAttributionDialog extends StatefulWidget {
  final String nomComplet;
  final Future<bool> Function(String pin) onConfirmer;

  const PinAttributionDialog({
    super.key,
    required this.nomComplet,
    required this.onConfirmer,
  });

  @override
  State<PinAttributionDialog> createState() => _PinAttributionDialogState();
}

class _PinAttributionDialogState extends State<PinAttributionDialog> {
  final _ctrl = TextEditingController();
  String? _erreur;
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirmer() async {
    final pin = _ctrl.text.trim();
    if (pin.length != 4) {
      setState(() => _erreur = 'Le PIN doit contenir exactement 4 chiffres.');
      return;
    }
    setState(() {
      _erreur = null;
      _loading = true;
    });
    final ok = await widget.onConfirmer(pin);
    if (mounted) {
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
      title: const Text(
        'Attribuer un PIN',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.nomComplet,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                fontSize: 14),
          ),
          const SizedBox(height: AppSizes.md),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmer(),
            onChanged: (_) {
              if (_erreur != null) setState(() => _erreur = null);
            },
            decoration: InputDecoration(
              labelText: 'PIN 4 chiffres',
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF7F7F8),
              errorText: _erreur,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                borderSide:
                    const BorderSide(color: AppColors.rouge, width: 1.5),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _confirmer,
          style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('Confirmer'),
        ),
      ],
    );
  }
}
