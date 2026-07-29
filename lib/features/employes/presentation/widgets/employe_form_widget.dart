import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/domain/entities/employee.dart';
import 'employe_list_item.dart';

typedef EmployeSaveCallback = void Function({
  required String nom,
  required String prenom,
  required RoleType role,
  String? numeroPointeuse,
  String? motDePasse,
  required bool isActif,
});

// Rôles proposés dans le formulaire (admin exclu)
const _roles = [
  RoleType.employe,
  RoleType.superviseurMenage,
  RoleType.reception,
  RoleType.direction,
];

class EmployeFormWidget extends StatefulWidget {
  final Employee? employe;
  final EmployeSaveCallback onSave;
  final bool isLoading;
  final bool canEditNumeroPointeuse;

  const EmployeFormWidget({
    super.key,
    this.employe,
    required this.onSave,
    this.isLoading = false,
    this.canEditNumeroPointeuse = false,
  });

  @override
  State<EmployeFormWidget> createState() => _EmployeFormWidgetState();
}

class _EmployeFormWidgetState extends State<EmployeFormWidget> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _nomCtrl;
  late final TextEditingController _pointeuseCtrl;
  late final TextEditingController _mdpCtrl;

  late RoleType _role;
  late bool _isActif;
  bool _showMdp = false;

  bool get _isEdit => widget.employe != null;
  bool get _isPreposee => _role == RoleType.employe;

  @override
  void initState() {
    super.initState();
    final e = widget.employe;
    _role = e?.role ?? RoleType.employe;
    _isActif = e?.isActif ?? true;
    _prenomCtrl = TextEditingController(text: e?.prenom ?? '');
    _nomCtrl = TextEditingController(text: e?.nom ?? '');
    _pointeuseCtrl = TextEditingController(text: e?.numeroPointeuse ?? '');
    _mdpCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _pointeuseCtrl.dispose();
    _mdpCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSave(
      prenom: _prenomCtrl.text.trim(),
      nom: _nomCtrl.text.trim(),
      role: _role,
      numeroPointeuse: _isPreposee
          ? widget.canEditNumeroPointeuse
              ? (_pointeuseCtrl.text.trim().isEmpty
                  ? null
                  : _pointeuseCtrl.text.trim())
              : widget.employe?.numeroPointeuse
          : null,
      motDePasse: !_isPreposee && _mdpCtrl.text.trim().isNotEmpty
          ? _mdpCtrl.text.trim()
          : null,
      isActif: _isActif,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Titre ────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.rouge.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.rouge,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Text(
                      _isEdit ? 'Modifier l\'employé' : 'Nouvel employé',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.noir,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      color: AppColors.grisDark,
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.lg),

                // ── Prénom + Nom ──────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prenomCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Prénom',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obligatoire'
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _nomCtrl,
                        decoration: const InputDecoration(labelText: 'Nom'),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obligatoire'
                            : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.md),

                // ── Rôle ─────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rôle',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grisDark,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Wrap(
                      spacing: AppSizes.sm,
                      runSpacing: AppSizes.sm,
                      children: _roles.map((r) {
                        final selected = _role == r;
                        final color = roleColor(r);
                        return InkWell(
                          onTap: () => setState(() => _role = r),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color.withValues(alpha: 0.12)
                                  : AppColors.grisLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? color : AppColors.grisMedium,
                              ),
                            ),
                            child: Text(
                              roleDisplay(r),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: selected ? color : AppColors.grisDark,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.md),

                // ── Numéro de pointeuse (préposée only) ──
                if (_isPreposee) ...[
                  if (widget.canEditNumeroPointeuse)
                    TextFormField(
                      controller: _pointeuseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'N° de pointeuse',
                        hintText: '6 chiffres',
                        prefixIcon: Icon(Icons.fingerprint_rounded),
                        helperText: 'Ce champ est réservé aux administrateurs.',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (!_isEdit && value.isEmpty) {
                          return 'Obligatoire pour une préposée';
                        }
                        if (value.isNotEmpty && value.length != 6) {
                          return '6 chiffres requis';
                        }
                        return null;
                      },
                    )
                  else
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'N° de pointeuse',
                        prefixIcon: Icon(Icons.fingerprint_rounded),
                        suffixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                        helperText:
                            'Seul un administrateur peut modifier ce numéro.',
                        filled: true,
                      ),
                      child: Text(
                        widget.employe?.numeroPointeuse ??
                            'À attribuer par un administrateur',
                      ),
                    ),
                  const SizedBox(height: AppSizes.md),
                ],

                // ── Mot de passe (responsable only) ──────
                if (!_isPreposee) ...[
                  TextFormField(
                    controller: _mdpCtrl,
                    decoration: InputDecoration(
                      labelText: _isEdit
                          ? 'Mot de passe (laisser vide pour ne pas changer)'
                          : 'Mot de passe',
                      prefixIcon: const Icon(Icons.password_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showMdp
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _showMdp = !_showMdp),
                      ),
                    ),
                    obscureText: !_showMdp,
                    validator: (v) {
                      if (!_isEdit && (v == null || v.trim().isEmpty)) {
                        return 'Obligatoire pour un responsable';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.md),
                ],

                // ── Statut actif (mode édition) ───────────
                if (_isEdit) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Employé actif',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      _isActif
                          ? 'Apparaît dans le planning'
                          : 'Masqué du planning',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grisDark,
                      ),
                    ),
                    value: _isActif,
                    activeThumbColor: AppColors.jourVert,
                    onChanged: (v) => setState(() => _isActif = v),
                  ),
                  const SizedBox(height: AppSizes.sm),
                ],

                // ── Boutons ───────────────────────────────
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
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isEdit ? 'Enregistrer' : 'Ajouter'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rouge,
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
