import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/dialogue_app.dart';

/// Création d'un résident. [pin] est `null` quand le résident n'utilise pas
/// l'application (aucun code de connexion à lui attribuer).
typedef CreerResidentCallback = Future<bool> Function({
  required String aptId,
  required String nom,
  required String prenom,
  required bool aApplication,
  required String? pin,
});

class CreerResidentDialog extends StatefulWidget {
  final CreerResidentCallback onConfirmer;

  const CreerResidentDialog({super.key, required this.onConfirmer});

  @override
  State<CreerResidentDialog> createState() => _CreerResidentDialogState();
}

class _CreerResidentDialogState extends State<CreerResidentDialog> {
  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  // Appartement
  List<Map<String, dynamic>> _aptResults = [];
  bool _rechercheFaite = false;
  String? _selectedAptId;
  String? _selectedAptNumero;
  String? _selectedAptTaille;
  bool _searchLoading = false;
  Timer? _debounce;

  // Accès à l'application (par défaut : sans application)
  bool _aApplication = false;
  bool _pinVisible = false;

  // Soumission
  bool _loading = false;
  String? _erreurGlobal;

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _searchCtrl.dispose();
    _pinCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Recherche d'appartement ────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _aptResults = [];
        _rechercheFaite = false;
      });
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
          .order('numero')
          .limit(6);
      if (mounted) {
        setState(() {
          _aptResults = List<Map<String, dynamic>>.from(data as List);
          _searchLoading = false;
          _rechercheFaite = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchLoading = false;
          _rechercheFaite = true;
        });
      }
    }
  }

  void _selectionnerApt(Map<String, dynamic> apt) {
    setState(() {
      _selectedAptId = apt['id'] as String;
      _selectedAptNumero = apt['numero'] as String?;
      _selectedAptTaille = apt['taille']?.toString();
      _aptResults = [];
      _rechercheFaite = false;
      _searchCtrl.clear();
      _erreurGlobal = null;
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

  String get _pin => _pinCtrl.text.trim();

  /// Erreur du PIN à afficher sous le champ (seulement une fois saisi).
  String? get _erreurPin {
    if (!_aApplication || _pin.isEmpty) return null;
    if (_pin.length < 4) return null; // saisie en cours
    if (_selectedAptNumero != null && _pin == _selectedAptNumero) {
      return 'Le PIN ne peut pas être le numéro d’appartement.';
    }
    return null;
  }

  bool get _pinValide =>
      _pin.length == 4 &&
      (_selectedAptNumero == null || _pin != _selectedAptNumero);

  bool get _peutSoumettre =>
      _prenomCtrl.text.trim().length >= 2 &&
      _nomCtrl.text.trim().length >= 2 &&
      _selectedAptId != null &&
      (!_aApplication || _pinValide);

  /// Ce qu'il reste à compléter (affiché au-dessus des boutons).
  String? get _manquant {
    if (_prenomCtrl.text.trim().length < 2) return 'Indiquez le prénom.';
    if (_nomCtrl.text.trim().length < 2) return 'Indiquez le nom.';
    if (_selectedAptId == null) return 'Choisissez l’appartement.';
    if (_aApplication && _pin.length != 4) {
      return 'Saisissez un PIN à 4 chiffres.';
    }
    return null;
  }

  // ── Soumission ─────────────────────────────────────────

  Future<void> _soumettre() async {
    if (!_peutSoumettre) return;
    setState(() {
      _loading = true;
      _erreurGlobal = null;
    });

    final ok = await widget.onConfirmer(
      aptId: _selectedAptId!,
      nom: _nomCtrl.text.trim(),
      prenom: _prenomCtrl.text.trim(),
      aApplication: _aApplication,
      pin: _aApplication ? _pin : null,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _loading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final manquant = _manquant;
    return DialogueApp(
      titre: 'Nouveau résident',
      largeur: 500,
      libelleAction: _aApplication ? 'Créer avec PIN' : 'Enregistrer',
      libelleSecondaire: 'Annuler',
      enCours: _loading,
      onFermer: () => Navigator.pop(context, false),
      onSecondaire: () => Navigator.pop(context, false),
      onAction: _peutSoumettre ? _soumettre : null,
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 1. Identité ────────────────────────────────
          const _Etape(numero: 1, titre: 'Identité'),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final prenom = _champ(_prenomCtrl, 'Prénom', Icons.badge_outlined,
                autofocus: true);
            final nom = _champ(_nomCtrl, 'Nom', Icons.person_outline_rounded);
            if (c.maxWidth < 380) {
              return Column(
                children: [prenom, const SizedBox(height: 10), nom],
              );
            }
            return Row(
              children: [
                Expanded(child: prenom),
                const SizedBox(width: 10),
                Expanded(child: nom),
              ],
            );
          }),
          const SizedBox(height: 20),

          // ── 2. Appartement ─────────────────────────────
          const _Etape(numero: 2, titre: 'Appartement'),
          const SizedBox(height: 10),
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
              _AptResultats(results: _aptResults, onSelect: _selectionnerApt)
            else if (_rechercheFaite && !_searchLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  'Aucun appartement ne correspond à ce numéro.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.grisText),
                ),
              ),
          ],
          const SizedBox(height: 20),

          // ── 3. Accès à l'application ───────────────────
          const _Etape(numero: 3, titre: 'Accès à l’application'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ChoixAcces(
                  icone: Icons.phonelink_erase_rounded,
                  titre: 'Sans application',
                  description: 'Pas de code. La Réception le prévient.',
                  selectionne: !_aApplication,
                  onTap: () => setState(() => _aApplication = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoixAcces(
                  icone: Icons.phone_iphone_rounded,
                  titre: 'Avec l’application',
                  description: 'Se connecte avec un PIN.',
                  selectionne: _aApplication,
                  onTap: () => setState(() => _aApplication = true),
                ),
              ),
            ],
          ),

          // ── 4. PIN (seulement avec l'application) ──────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _aApplication
                ? Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Etape(numero: 4, titre: 'Code PIN'),
                        const SizedBox(height: 10),
                        _champPin(),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),

          // ── Récapitulatif / erreur ─────────────────────
          const SizedBox(height: 18),
          if (_erreurGlobal != null)
            _ErreurBaniere(message: _erreurGlobal!)
          else if (manquant != null)
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 15, color: AppColors.grisText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(manquant,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.grisText)),
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: AppColors.fait),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _aApplication
                        ? 'Prêt : ${_prenomCtrl.text.trim()} pourra se '
                            'connecter avec son PIN.'
                        : 'Prêt à enregistrer ${_prenomCtrl.text.trim()} '
                            '(sans application).',
                    style:
                        const TextStyle(fontSize: 12.5, color: AppColors.fait),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _champ(
    TextEditingController ctrl,
    String label,
    IconData icone, {
    bool autofocus = false,
  }) {
    return TextField(
      controller: ctrl,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {}),
      decoration: _decoration(label, icone),
    );
  }

  Widget _champPin() {
    final erreur = _erreurPin;
    final valide = _pinValide;
    return TextField(
      controller: _pinCtrl,
      keyboardType: TextInputType.number,
      obscureText: !_pinVisible,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _soumettre(),
      style: const TextStyle(
          fontSize: 18, letterSpacing: 8, fontWeight: FontWeight.w700),
      decoration: _decoration('PIN à 4 chiffres', Icons.key_rounded).copyWith(
        counterText: '',
        errorText: erreur,
        helperText: erreur == null
            ? (_selectedAptNumero != null
                ? 'Jamais le numéro d’appartement ($_selectedAptNumero).'
                : 'Jamais le numéro d’appartement.')
            : null,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (valide)
              const Icon(Icons.check_circle_rounded,
                  size: 20, color: AppColors.fait),
            IconButton(
              tooltip: _pinVisible ? 'Masquer le PIN' : 'Afficher le PIN',
              onPressed: () => setState(() => _pinVisible = !_pinVisible),
              icon: Icon(
                _pinVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icone) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icone, size: 20, color: AppColors.grisText),
        filled: true,
        fillColor: const Color(0xFFF7F7F8),
        isDense: true,
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
          borderSide: const BorderSide(color: AppColors.rouge, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

// ══════════════════════════════════════════════════════════
// SOUS-WIDGETS
// ══════════════════════════════════════════════════════════

class _Etape extends StatelessWidget {
  final int numero;
  final String titre;
  const _Etape({required this.numero, required this.titre});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.rouge,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$numero',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          titre,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.noir,
          ),
        ),
      ],
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
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Rechercher le numéro d’appartement…',
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.grisText),
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
        isDense: true,
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
          borderSide: const BorderSide(color: AppColors.rouge, width: 1.5),
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
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.grisMedium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (final (i, apt) in results.indexed) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.grisMedium),
              InkWell(
                onTap: () => onSelect(apt),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      const Icon(Icons.apartment_rounded,
                          size: 17, color: AppColors.rouge),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Apt ${apt['numero'] ?? '—'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.noir,
                          ),
                        ),
                      ),
                      if (apt['taille'] != null)
                        Text(
                          '${apt['taille']}',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.grisText),
                        ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.grisText),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.rouge.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: AppColors.rouge),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              taille != null ? 'Apt $numero · $taille' : 'Apt $numero',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.rouge,
              ),
            ),
          ),
          TextButton(
            onPressed: onReinit,
            style: TextButton.styleFrom(foregroundColor: AppColors.rouge),
            child: const Text('Changer'),
          ),
        ],
      ),
    );
  }
}

class _ChoixAcces extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String description;
  final bool selectionne;
  final VoidCallback onTap;

  const _ChoixAcces({
    required this.icone,
    required this.titre,
    required this.description,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selectionne
          ? AppColors.rouge.withValues(alpha: 0.07)
          : const Color(0xFFF7F7F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        side: BorderSide(
          color: selectionne ? AppColors.rouge : const Color(0xFFE8E8E8),
          width: selectionne ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icone,
                      size: 20,
                      color:
                          selectionne ? AppColors.rouge : AppColors.grisDark),
                  const Spacer(),
                  Icon(
                    selectionne
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 18,
                    color: selectionne ? AppColors.rouge : AppColors.grisText,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                titre,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selectionne ? AppColors.rouge : AppColors.noir,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                    fontSize: 12, height: 1.3, color: AppColors.grisText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErreurBaniere extends StatelessWidget {
  final String message;
  const _ErreurBaniere({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.refus.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.refus.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 15, color: AppColors.refus),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.refus,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
