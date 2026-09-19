import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/appartement.dart';

typedef AppartementSaveCallback = void Function(
  String numero,
  String taille,
  int minutesBase,
  String? notes,
  bool hasAnimal,
  String? typeAnimal,
);

const List<String> _tailles = ['2 1/2', '3 1/2', '4 1/2', '5 1/2'];

int _minutesDefaut(String taille) {
  switch (taille) {
    case '2 1/2':
      return 45;
    case '3 1/2':
      return 60;
    case '4 1/2':
      return 75;
    case '5 1/2':
      return 90;
    default:
      return 60;
  }
}

class AppartementFormWidget extends StatefulWidget {
  final Appartement? appartement;
  final AppartementSaveCallback onSave;
  final bool isLoading;

  const AppartementFormWidget({
    super.key,
    this.appartement,
    required this.onSave,
    this.isLoading = false,
  });

  @override
  State<AppartementFormWidget> createState() => _AppartementFormWidgetState();
}

class _AppartementFormWidgetState extends State<AppartementFormWidget> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numeroCtrl;
  late final TextEditingController _minutesCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _typeAnimalCtrl;
  late String _taille;
  late bool _hasAnimal;

  bool get _isEdit => widget.appartement != null;

  @override
  void initState() {
    super.initState();
    _taille = widget.appartement?.taille ?? '3 1/2';
    _hasAnimal = widget.appartement?.hasAnimal ?? false;
    _numeroCtrl = TextEditingController(
      text: widget.appartement?.numero ?? '',
    );
    _minutesCtrl = TextEditingController(
      text: (widget.appartement?.minutesBase ?? _minutesDefaut(_taille))
          .toString(),
    );
    _notesCtrl = TextEditingController(text: widget.appartement?.notes ?? '');
    _typeAnimalCtrl = TextEditingController(
      text: widget.appartement?.typeAnimal ?? '',
    );
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _minutesCtrl.dispose();
    _notesCtrl.dispose();
    _typeAnimalCtrl.dispose();
    super.dispose();
  }

  void _onTailleChanged(String t) {
    setState(() {
      _taille = t;
      _minutesCtrl.text = _minutesDefaut(t).toString();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final minutes =
        int.tryParse(_minutesCtrl.text.trim()) ?? _minutesDefaut(_taille);
    final notes = _notesCtrl.text.trim();
    final typeAnimal = _typeAnimalCtrl.text.trim();
    widget.onSave(
      _numeroCtrl.text.trim(),
      _taille,
      minutes,
      notes.isEmpty ? null : notes,
      _hasAnimal,
      _hasAnimal && typeAnimal.isNotEmpty ? typeAnimal : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.md,
            AppSizes.md,
            AppSizes.lg,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Titre ───────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.rouge.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: AppColors.rouge,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Text(
                      _isEdit
                          ? 'Modifier l\'appartement'
                          : 'Nouvel appartement',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.noir,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                      color: AppColors.grisDark,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Fermer',
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.md),

                // ── Numéro ───────────────────────────────
                TextFormField(
                  controller: _numeroCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Numéro d\'appartement',
                    hintText: 'Ex: 101, 2B, RDC...',
                    prefixIcon: Icon(Icons.tag_rounded, size: 19),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),

                const SizedBox(height: AppSizes.md),

                // ── Taille ───────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Taille',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grisDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tailles.map((t) {
                        final selected = _taille == t;
                        return ChoiceChip(
                          label: Text(t),
                          selected: selected,
                          onSelected: (_) => _onTailleChanged(t),
                          visualDensity: VisualDensity.compact,
                          selectedColor:
                              AppColors.rouge.withValues(alpha: 0.12),
                          checkmarkColor: AppColors.rouge,
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            color:
                                selected ? AppColors.rouge : AppColors.grisDark,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: selected
                                ? AppColors.rouge
                                : AppColors.grisMedium,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.md),

                // ── Minutes de base ──────────────────────
                TextFormField(
                  controller: _minutesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Durée de base (minutes)',
                    hintText: 'Ex: 60',
                    prefixIcon: Icon(Icons.schedule_rounded, size: 19),
                    suffixText: 'min',
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Obligatoire';
                    final n = int.tryParse(v);
                    if (n == null || n <= 0) return 'Valeur invalide';
                    return null;
                  },
                ),

                const SizedBox(height: AppSizes.md),

                // ── Animal ───────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.grisLight,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _hasAnimal,
                        onChanged: (v) => setState(() {
                          _hasAnimal = v;
                          if (!v) _typeAnimalCtrl.clear();
                        }),
                        title: const Text(
                          'Présence d\'un animal',
                          style: TextStyle(fontSize: 13.5),
                        ),
                        secondary: const Icon(Icons.pets_rounded, size: 20),
                        activeThumbColor: AppColors.rouge,
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sm,
                        ),
                      ),
                      if (_hasAnimal)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSizes.sm,
                            0,
                            AppSizes.sm,
                            AppSizes.sm,
                          ),
                          child: TextFormField(
                            controller: _typeAnimalCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Type d\'animal',
                              hintText: 'Ex: Chat, Chien...',
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.md),

                // ── Notes ────────────────────────────────
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Informations complémentaires...',
                    prefixIcon: Icon(Icons.notes_rounded, size: 19),
                    isDense: true,
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                ),

                const SizedBox(height: AppSizes.lg),

                // ── Boutons ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    FilledButton.icon(
                      onPressed: widget.isLoading ? null : _submit,
                      icon: widget.isLoading
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 17),
                      label: Text(_isEdit ? 'Modifier' : 'Ajouter'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rouge,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.md,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
