import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class DesactivationDialog extends StatefulWidget {
  final String nomComplet;
  final Future<bool> Function() onConfirmer;

  const DesactivationDialog({
    super.key,
    required this.nomComplet,
    required this.onConfirmer,
  });

  @override
  State<DesactivationDialog> createState() => _DesactivationDialogState();
}

class _DesactivationDialogState extends State<DesactivationDialog> {
  final _motifCtrl = TextEditingController();
  String? _erreur;
  bool _loading = false;

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmer() async {
    final motif = _motifCtrl.text.trim();
    if (motif.length < 10) {
      setState(
          () => _erreur = 'Le motif doit contenir au moins 10 caractères.');
      return;
    }
    setState(() {
      _erreur = null;
      _loading = true;
    });
    final ok = await widget.onConfirmer();
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
        'Désactiver le résident',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.nomComplet,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: AppSizes.sm),

          // Warning PIN
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.rouge.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              border: Border.all(
                  color: AppColors.rouge.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 15, color: AppColors.rouge),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Le PIN sera invalidé immédiatement.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.rouge,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),

          TextField(
            controller: _motifCtrl,
            autofocus: true,
            maxLines: 2,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_erreur != null) setState(() => _erreur = null);
            },
            decoration: InputDecoration(
              labelText: 'Motif (obligatoire)',
              hintText: 'Raison de la désactivation...',
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
              : const Text('Désactiver'),
        ),
      ],
    );
  }
}
