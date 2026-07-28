import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../auth/presentation/widgets/pin_input_widget.dart';

// Signature du callback de soumission
typedef CreerResidentCallback = Future<bool> Function({
  required String aptId,
  required String nom,
  required String prenom,
  required bool aApplication,
  required String pin,
});

class CreerResidentDialog extends StatefulWidget {
  final CreerResidentCallback onConfirmer;

  const CreerResidentDialog({super.key, required this.onConfirmer});

  @override
  State<CreerResidentDialog> createState() => _CreerResidentDialogState();
}

class _CreerResidentDialogState extends State<CreerResidentDialog> {
  // Champs texte
  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  // Appartement
  List<Map<String, dynamic>> _aptResults = [];
  String? _selectedAptId;
  String? _selectedAptNumero;
  String? _selectedAptTaille;
  bool _searchLoading = false;
  Timer? _debounce;

  // Accès app (défaut = Non)
  bool _aApplication = false;

  // PIN
  String? _pin;
  String? _pinError;

  // Soumission
  bool _loading = false;
  String? _erreurGlobal;

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Recherche appartements ─────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _aptResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _searchLoading = true);
    try {
      final data = await SupabaseService.client
          .from('appartements')
          .select('id, numero, taille')
          .ilike('numero', '%${query.trim()}%')
          .limit(5);
      if (mounted) {
        setState(() {
          _aptResults = List<Map<String, dynamic>>.from(data as List);
          _searchLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  void _selectionnerApt(Map<String, dynamic> apt) {
    setState(() {
      _selectedAptId = apt['id'] as String;
      _selectedAptNumero = apt['numero'] as String?;
      _selectedAptTaille = apt['taille']?.toString();
      _aptResults = [];
      _searchCtrl.clear();
      _pinError = null;
    });
  }

  void _reinitialiserApt() {
    setState(() {
      _selectedAptId = null;
      _selectedAptNumero = null;
      _selectedAptTaille = null;
    });
  }

  // ── Validation ─────────────────────────────────────────

  String? _valider() {
    if (_prenomCtrl.text.trim().length < 2) return 'Prénom trop court (min 2 caractères).';
    if (_nomCtrl.text.trim().length < 2) return 'Nom trop court (min 2 caractères).';
    if (_selectedAptId == null) return 'Sélectionnez un appartement.';
    if (_pin == null || _pin!.length != 4) return 'Entrez un PIN à 4 chiffres.';
    if (_selectedAptNumero != null && _pin == _selectedAptNumero) {
      return 'Le PIN ne peut pas être le numéro d\'appartement.';
    }
    return null;
  }

  bool get _peutSoumettre =>
      _prenomCtrl.text.trim().length >= 2 &&
      _nomCtrl.text.trim().length >= 2 &&
      _selectedAptId != null &&
      _pin != null &&
      _pin!.length == 4 &&
      (_selectedAptNumero == null || _pin != _selectedAptNumero);

  // ── Soumission ─────────────────────────────────────────

  Future<void> _soumettre() async {
    final erreur = _valider();
    if (erreur != null) {
      setState(() => _erreurGlobal = erreur);
      return;
    }

    setState(() {
      _loading = true;
      _erreurGlobal = null;
    });

    final ok = await widget.onConfirmer(
      aptId: _selectedAptId!,
      nom: _nomCtrl.text.trim(),
      prenom: _prenomCtrl.text.trim(),
      aApplication: _aApplication,
      pin: _pin!,
    );

    if (mounted) {
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() => _loading = false);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── En-tête ──────────────────────────────────
            _DialogHeader(onClose: () => Navigator.pop(context, false)),

            // ── Corps scrollable ─────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.xl, 0, AppSizes.xl, AppSizes.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Prénom + Nom
                    _field(_prenomCtrl, 'Prénom',
                        Icons.badge_outlined, () => setState(() {})),
                    const SizedBox(height: AppSizes.sm),
                    _field(_nomCtrl, 'Nom',
                        Icons.person_outline_rounded, () => setState(() {})),
                    const SizedBox(height: AppSizes.md),

                    // ── Appartement ─────────────────────
                    const _SectionLabel(label: 'Appartement'),
                    const SizedBox(height: AppSizes.xs),

                    if (_selectedAptId != null)
                      _AptSelectionnee(
                        numero: _selectedAptNumero ?? '—',
                        taille: _selectedAptTaille,
                        onReinit: _reinitialiserApt,
                      )
                    else ...[
                      _AptSearchField(
                        ctrl: _searchCtrl,
                        isLoading: _searchLoading,
                        onChanged: _onSearchChanged,
                      ),
                      if (_aptResults.isNotEmpty)
                        _AptResultats(
                          results: _aptResults,
                          onSelect: _selectionnerApt,
                        ),
                    ],

                    const SizedBox(height: AppSizes.md),

                    // ── Accès app ────────────────────────
                    const _SectionLabel(label: 'Accès application'),
                    const SizedBox(height: AppSizes.xs),
                    _AppToggle(
                      value: _aApplication,
                      onChanged: (v) => setState(() => _aApplication = v),
                    ),

                    const SizedBox(height: AppSizes.lg),

                    // ── PIN ──────────────────────────────
                    const _SectionLabel(label: 'PIN — 4 chiffres'),
                    const SizedBox(height: AppSizes.xs),
                    _PinWarning(aptNumero: _selectedAptNumero),
                    const SizedBox(height: AppSizes.sm),

                    PinInputWidget(
                      slug: '',
                      pinLength: 4,
                      isLoading: _loading,
                      error: _pinError,
                      onPinComplete: (pin) {
                        final invalide = _selectedAptNumero != null &&
                            pin == _selectedAptNumero;
                        setState(() {
                          _pin = pin;
                          _pinError = invalide
                              ? 'PIN identique au numéro d\'appartement'
                              : null;
                        });
                      },
                    ),

                    // Erreur globale
                    if (_erreurGlobal != null) ...[
                      const SizedBox(height: AppSizes.sm),
                      _ErreurBaniere(message: _erreurGlobal!),
                    ],

                    const SizedBox(height: AppSizes.lg),

                    // ── Actions ──────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.grisDark,
                              side: const BorderSide(
                                  color: AppColors.grisMedium),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppSizes.radiusMd),
                              ),
                            ),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed:
                                (_loading || !_peutSoumettre) ? null : _soumettre,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.rouge,
                              disabledBackgroundColor:
                                  AppColors.rouge.withValues(alpha: 0.4),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppSizes.radiusMd),
                              ),
                            ),
                            icon: _loading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.arrow_forward_rounded,
                                    size: 18),
                            label: const Text(
                              'Créer',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon,
    VoidCallback onChange,
  ) {
    return TextField(
      controller: ctrl,
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => onChange(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.grisText),
        filled: true,
        fillColor: const Color(0xFFF7F7F8),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// SOUS-WIDGETS
// ══════════════════════════════════════════════════════════

class _DialogHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _DialogHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.xl, AppSizes.lg, AppSizes.md, AppSizes.md),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Nouveau résident',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.noir,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.grisText,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.grisDark,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ── Recherche appartement ──────────────────────────────────

class _AptSearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isLoading;
  final ValueChanged<String> onChanged;

  const _AptSearchField({
    required this.ctrl,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Numéro d\'appartement...',
        hintStyle:
            const TextStyle(fontSize: 14, color: AppColors.grisText),
        prefixIcon: const Icon(Icons.search_rounded,
            size: 20, color: AppColors.grisText),
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.rouge),
                ),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF7F7F8),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _AptResultats extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _AptResultats({required this.results, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: results.asMap().entries.map((e) {
          final apt = e.value;
          final numero = apt['numero'] as String? ?? '—';
          final taille = apt['taille']?.toString();
          final label =
              taille != null ? 'Apt $numero ($taille)' : 'Apt $numero';
          final isLast = e.key == results.length - 1;
          return InkWell(
            onTap: () => onSelect(apt),
            borderRadius: BorderRadius.vertical(
              top: e.key == 0
                  ? const Radius.circular(AppSizes.radiusMd)
                  : Radius.zero,
              bottom: isLast
                  ? const Radius.circular(AppSizes.radiusMd)
                  : Radius.zero,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: Color(0xFFF0F0F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.apartment_rounded,
                      size: 16, color: AppColors.grisText),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.noir,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AptSelectionnee extends StatelessWidget {
  final String numero;
  final String? taille;
  final VoidCallback onReinit;

  const _AptSelectionnee({
    required this.numero,
    this.taille,
    required this.onReinit,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        taille != null ? 'Apt $numero ($taille)' : 'Apt $numero';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
            color: AppColors.rouge.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: AppColors.rouge),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.rouge,
              ),
            ),
          ),
          GestureDetector(
            onTap: onReinit,
            child: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.rouge),
          ),
        ],
      ),
    );
  }
}

// ── Toggle accès app ───────────────────────────────────────

class _AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AppToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleBtn(
            icon: Icons.phone_android_rounded,
            label: 'Oui',
            selected: value,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: _ToggleBtn(
            icon: Icons.description_rounded,
            label: 'Non',
            selected: !value,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.rouge.withValues(alpha: 0.08)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: selected ? AppColors.rouge : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 17,
                color: selected ? AppColors.rouge : AppColors.grisDark),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.rouge : AppColors.grisDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avertissement PIN ──────────────────────────────────────

class _PinWarning extends StatelessWidget {
  final String? aptNumero;
  const _PinWarning({this.aptNumero});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 15, color: Color(0xFFF57C00)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              aptNumero != null
                  ? 'Jamais le numéro d\'appartement ($aptNumero)'
                  : 'Jamais le numéro d\'appartement',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFFF57C00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bannière erreur ────────────────────────────────────────

class _ErreurBaniere extends StatelessWidget {
  final String message;
  const _ErreurBaniere({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border:
            Border.all(color: AppColors.rouge.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 15, color: AppColors.rouge),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.rouge,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
