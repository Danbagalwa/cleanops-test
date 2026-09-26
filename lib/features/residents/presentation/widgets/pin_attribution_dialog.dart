import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/dialogue_app.dart';

class PinAttributionDialog extends StatefulWidget {
  final String nomComplet;
  final Future<bool> Function(String pin) onConfirmer;

  /// Le résident a déjà un PIN : il sera remplacé.
  final bool remplacement;

  const PinAttributionDialog({
    super.key,
    required this.nomComplet,
    required this.onConfirmer,
    this.remplacement = false,
  });

  @override
  State<PinAttributionDialog> createState() => _PinAttributionDialogState();
}

class _PinAttributionDialogState extends State<PinAttributionDialog> {
  final _ctrl = TextEditingController();
  String? _erreur;
  bool _loading = false;
  bool _visible = false;

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
    return DialogueApp(
      titre: widget.remplacement ? 'Modifier le PIN' : 'Attribuer un PIN',
      largeur: 420,
      libelleAction: 'Confirmer',
      libelleSecondaire: 'Annuler',
      enCours: _loading,
      onFermer: () => Navigator.pop(context, false),
      onSecondaire: () => Navigator.pop(context, false),
      onAction: _confirmer,
      contenu: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.aVerifier.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.key_rounded,
                    size: 19, color: AppColors.aVerifier),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nomComplet,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.noir,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      widget.remplacement
                          ? 'L’ancien PIN ne fonctionnera plus.'
                          : 'Code de connexion à l’espace résident.',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grisText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: !_visible,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmer(),
            onChanged: (_) {
              if (_erreur != null) setState(() => _erreur = null);
            },
            style: const TextStyle(fontSize: 18, letterSpacing: 6),
            decoration: InputDecoration(
              labelText: 'PIN — 4 chiffres',
              counterText: '',
              errorText: _erreur,
              suffixIcon: IconButton(
                tooltip: _visible ? 'Masquer' : 'Afficher',
                onPressed: () => setState(() => _visible = !_visible),
                icon: Icon(_visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
              ),
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
