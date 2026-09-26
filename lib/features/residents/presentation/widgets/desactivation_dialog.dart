import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/dialogue_app.dart';

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
    return DialogueApp(
      titre: 'Désactiver le résident',
      largeur: 460,
      libelleAction: 'Désactiver',
      libelleSecondaire: 'Annuler',
      enCours: _loading,
      onFermer: () => Navigator.pop(context, false),
      onSecondaire: () => Navigator.pop(context, false),
      onAction: _confirmer,
      contenu: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.nomComplet,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.noir,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.refus.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.refus.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 17, color: AppColors.refus),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Le PIN sera invalidé immédiatement : le résident ne '
                    'pourra plus se connecter.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.refus,
                      fontWeight: FontWeight.w500,
                    ),
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
              errorText: _erreur,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
