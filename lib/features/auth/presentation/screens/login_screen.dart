import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/domain/entities/employee.dart';
import '../providers/auth_provider.dart';
import '../widgets/pin_input_widget.dart';

typedef SlugPinCallback = void Function(String slug, String pin);

enum AuthNiveau { un, deux }

// ── InputDecoration centralisé ─────────────────────────────
InputDecoration _fieldDeco({
  required String label,
  String? hint,
  required IconData icon,
}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF7F7F8),
      prefixIcon: Icon(icon, color: AppColors.grisText, size: 20),
      labelStyle: const TextStyle(color: AppColors.grisText, fontSize: 14),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: const BorderSide(color: AppColors.rouge),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );

// ══════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════

class LoginScreen extends ConsumerStatefulWidget {
  final String? slug;
  const LoginScreen({super.key, this.slug});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  AuthNiveau _niveau = AuthNiveau.un;
  String? _roleSelecte;
  final _idResController = TextEditingController();
  final _pinResController = TextEditingController();

  @override
  void dispose() {
    _idResController.dispose();
    _pinResController.dispose();
    super.dispose();
  }

  Future<void> _passerNiveauDeux() async {
    final ok = await ref.read(authNotifierProvider.notifier).validerNiveauUn(
          idResidence: _idResController.text.trim(),
          pinResidence: _pinResController.text.trim(),
        );
    if (ok && mounted) setState(() => _niveau = AuthNiveau.deux);
  }

  void _retourNiveauUn() {
    ref.read(authNotifierProvider.notifier).retourNiveauUn();
    setState(() {
      _niveau = AuthNiveau.un;
      _roleSelecte = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final formContent = _AuthForm(
      niveau: _niveau,
      roleSelecte: _roleSelecte,
      isLoading: authState.isLoading,
      error: authState.error,
      idController: _idResController,
      pinController: _pinResController,
      onNiveauDeux: _passerNiveauDeux,
      onRetour: _retourNiveauUn,
      onRoleChange: (r) => setState(() => _roleSelecte = r),
      onPinComplete: (slug, pin) => _handlePinLogic(
          context, ref, pin, slug, _niveau, _roleSelecte),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: isWide
          ? _WideLayout(niveau: _niveau, formContent: formContent)
          : _NarrowLayout(formContent: formContent),
    );
  }
}

// ══════════════════════════════════════════════════════════
// NARROW LAYOUT — mobile & tablette portrait (< 900 px)
// ══════════════════════════════════════════════════════════

class _NarrowLayout extends StatelessWidget {
  final Widget formContent;
  const _NarrowLayout({required this.formContent});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── En-tête compact rouge ────────────────────────
        Container(
          padding:
              EdgeInsets.fromLTRB(AppSizes.lg, topPad + 14, AppSizes.lg, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.rouge, AppColors.rougeFonce],
            ),
            borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(AppSizes.radiusXl)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Gestion d\'entretien ménager',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideY(begin: -0.1, end: 0, curve: Curves.easeOut),

        // ── Formulaire scrollable ─────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.xl, AppSizes.lg, AppSizes.xxl),
            child: formContent
                .animate(delay: 200.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// WIDE LAYOUT — desktop (≥ 900 px)
// ══════════════════════════════════════════════════════════

class _WideLayout extends StatelessWidget {
  final AuthNiveau niveau;
  final Widget formContent;
  const _WideLayout({required this.niveau, required this.formContent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Panneau gauche: branding ─────────────────────
        SizedBox(
          width: 420,
          child: const _BrandPanel()
              .animate()
              .fadeIn(duration: 600.ms)
              .slideX(begin: -0.05, end: 0, curve: Curves.easeOut),
        ),

        // ── Panneau droit: formulaire ─────────────────────
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.xxl, vertical: AppSizes.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Titre + sous-titre
                    Text(
                      niveau == AuthNiveau.un
                          ? 'Connexion'
                          : 'Vérification',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppColors.noir,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      niveau == AuthNiveau.un
                          ? 'Accès résidence'
                          : 'Identité personnelle',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.grisText),
                    ),
                    const SizedBox(height: AppSizes.lg),

                    formContent
                        .animate(delay: 150.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Panneau branding (desktop) ─────────────────────────────

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(AppSizes.xxl),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.rouge, AppColors.rougeFonce],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: AppSizes.xl),

          // App name
          const Text(
            AppStrings.appName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gestion d\'entretien ménager',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),

          const SizedBox(height: AppSizes.xxl),

          // Features
          ...[
            (Icons.cleaning_services_rounded, 'Suivi des tâches en temps réel'),
            (Icons.people_rounded, 'Gestion des équipes ménagères'),
            (Icons.apartment_rounded, 'Aires communes et espaces partagés'),
            (Icons.chat_bubble_rounded, 'Messagerie privée intégrée'),
          ].map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(e.$1, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    e.$2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSizes.xxl),

          Text(
            AppStrings.slogan,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// FORMULAIRE PRINCIPAL (partagé mobile + desktop)
// ══════════════════════════════════════════════════════════

class _AuthForm extends StatelessWidget {
  final AuthNiveau niveau;
  final String? roleSelecte;
  final bool isLoading;
  final String? error;
  final TextEditingController idController;
  final TextEditingController pinController;
  final VoidCallback onNiveauDeux;
  final VoidCallback onRetour;
  final ValueChanged<String?> onRoleChange;
  final SlugPinCallback onPinComplete;

  const _AuthForm({
    required this.niveau,
    required this.roleSelecte,
    required this.isLoading,
    this.error,
    required this.idController,
    required this.pinController,
    required this.onNiveauDeux,
    required this.onRetour,
    required this.onRoleChange,
    required this.onPinComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepBar(etape: niveau == AuthNiveau.un ? 1 : 2),
        const SizedBox(height: AppSizes.xl),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: niveau == AuthNiveau.un
              ? _NiveauUn(
                  key: const ValueKey('n1'),
                  idController: idController,
                  pinController: pinController,
                  isLoading: isLoading,
                  error: error,
                  onContinue: onNiveauDeux,
                )
              : _NiveauDeux(
                  key: const ValueKey('n2'),
                  roleSelecte: roleSelecte,
                  isLoading: isLoading,
                  error: error,
                  onRoleChange: onRoleChange,
                  onRetour: onRetour,
                  onPinComplete: onPinComplete,
                ),
        ),
      ],
    );
  }
}

// ── Barre de progression d'étape ──────────────────────────

class _StepBar extends StatelessWidget {
  final int etape;
  const _StepBar({required this.etape});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Étape $etape sur 2',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.grisText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.rouge,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                decoration: BoxDecoration(
                  color: etape == 2
                      ? AppColors.rouge
                      : const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// NIVEAU 1 — ID résidence + PIN résidence
// ══════════════════════════════════════════════════════════

class _NiveauUn extends StatelessWidget {
  final TextEditingController idController;
  final TextEditingController pinController;
  final bool isLoading;
  final String? error;
  final VoidCallback onContinue;

  const _NiveauUn({
    super.key,
    required this.idController,
    required this.pinController,
    required this.isLoading,
    this.error,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Titre section
        const Text(
          'Accès résidence',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.noir,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Entrez les identifiants de votre résidence.',
          style: TextStyle(fontSize: 13, color: AppColors.grisText),
        ),
        const SizedBox(height: AppSizes.xl),

        // Identifiant
        TextField(
          controller: idController,
          textInputAction: TextInputAction.next,
          decoration: _fieldDeco(
            label: 'Identifiant résidence',
            hint: 'Ex : JT-2026-001',
            icon: Icons.business_outlined,
          ),
        ),
        const SizedBox(height: AppSizes.md),

        // PIN résidence
        TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onContinue(),
          decoration: _fieldDeco(
            label: 'Code PIN résidence',
            icon: Icons.lock_outline_rounded,
          ),
        ),

        // Erreur
        if (error != null) ...[
          const SizedBox(height: AppSizes.sm),
          _ErrorBanner(message: error!),
        ],

        const SizedBox(height: AppSizes.xl),

        _SubmitBtn(
          isLoading: isLoading,
          label: 'Continuer',
          onPressed: onContinue,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// NIVEAU 2 — Sélection rôle + formulaire
// ══════════════════════════════════════════════════════════

class _NiveauDeux extends StatelessWidget {
  final String? roleSelecte;
  final bool isLoading;
  final String? error;
  final ValueChanged<String?> onRoleChange;
  final VoidCallback onRetour;
  final SlugPinCallback onPinComplete;

  const _NiveauDeux({
    super.key,
    required this.roleSelecte,
    required this.isLoading,
    this.error,
    required this.onRoleChange,
    required this.onRetour,
    required this.onPinComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bouton retour étape 1
        GestureDetector(
          onTap: onRetour,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new_rounded,
                  size: 13, color: AppColors.grisText),
              SizedBox(width: 5),
              Text(
                'Retour à l\'étape 1',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.grisText,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.lg),

        // Titre
        const Text(
          'Qui êtes-vous ?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.noir,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sélectionnez votre profil pour continuer.',
          style: TextStyle(fontSize: 13, color: AppColors.grisText),
        ),
        const SizedBox(height: AppSizes.lg),

        // Cartes de rôle
        if (roleSelecte == null) ...[
          _RoleCard(
            icon: Icons.cleaning_services_rounded,
            iconColor: const Color(0xFF1A7A3C),
            iconBg: const Color(0xFFE8F5E9),
            label: 'Préposé(e) entretien',
            sublabel: 'Identifiant + PIN pointeuse (6 chiffres)',
            onTap: () => onRoleChange('preposee'),
          ),
          const SizedBox(height: AppSizes.sm),
          _RoleCard(
            icon: Icons.home_rounded,
            iconColor: const Color(0xFF1565C0),
            iconBg: const Color(0xFFE3F2FD),
            label: 'Résident(e)',
            sublabel: 'Numéro d\'appartement + PIN (4 chiffres)',
            onTap: () => onRoleChange('resident'),
          ),
          const SizedBox(height: AppSizes.sm),
          _RoleCard(
            icon: Icons.manage_accounts_rounded,
            iconColor: const Color(0xFF6A1B9A),
            iconBg: const Color(0xFFF3E5F5),
            label: 'Responsable',
            sublabel: 'Identifiant + mot de passe (8 chiffres)',
            onTap: () => onRoleChange('responsable'),
          ),
        ],

        // Formulaire selon rôle sélectionné
        if (roleSelecte == 'preposee')
          _FormPreposee(
            isLoading: isLoading,
            error: error,
            onPinComplete: onPinComplete,
            onBack: () => onRoleChange(null),
          ),

        if (roleSelecte == 'resident')
          _FormResident(
            isLoading: isLoading,
            error: error,
            onPinComplete: onPinComplete,
            onBack: () => onRoleChange(null),
          ),

        if (roleSelecte == 'responsable')
          _FormResponsable(
            isLoading: isLoading,
            error: error,
            onPinComplete: onPinComplete,
            onBack: () => onRoleChange(null),
          ),
      ],
    );
  }
}

// ── Carte de rôle ──────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Row(
            children: [
              // Icône colorée
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppSizes.md),

              // Texte
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.noir,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grisText),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.grisMedium, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Lien de retour vers la sélection de rôle ──────────────

class _RetourRole extends StatelessWidget {
  final String label;
  final VoidCallback onBack;
  const _RetourRole({required this.label, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onBack,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_back_ios_new_rounded,
              size: 11, color: AppColors.rouge),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.rouge,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// FORMULAIRES PAR RÔLE
// ══════════════════════════════════════════════════════════

class _FormPreposee extends StatefulWidget {
  final bool isLoading;
  final String? error;
  final SlugPinCallback onPinComplete;
  final VoidCallback onBack;

  const _FormPreposee({
    required this.isLoading,
    this.error,
    required this.onPinComplete,
    required this.onBack,
  });

  @override
  State<_FormPreposee> createState() => _FormPreposeeState();
}

class _FormPreposeeState extends State<_FormPreposee> {
  final _slugCtrl = TextEditingController();

  @override
  void dispose() {
    _slugCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RetourRole(label: 'Préposé(e) entretien', onBack: widget.onBack),
        const SizedBox(height: AppSizes.lg),

        TextField(
          controller: _slugCtrl,
          textInputAction: TextInputAction.next,
          decoration: _fieldDeco(
            label: 'Votre identifiant',
            hint: 'Ex : marie-dupont',
            icon: Icons.person_outline_rounded,
          ),
        ),
        const SizedBox(height: AppSizes.lg),

        const Text(
          'Numéro de pointeuse',
          style: TextStyle(
              fontSize: 13,
              color: AppColors.grisText,
              fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.sm),

        PinInputWidget(
          slug: _slugCtrl.text,
          pinLength: 6,
          isLoading: widget.isLoading,
          error: widget.error,
          onPinComplete: (pin) =>
              widget.onPinComplete(_slugCtrl.text.trim(), pin),
        ),
      ],
    );
  }
}

class _FormResident extends StatefulWidget {
  final bool isLoading;
  final String? error;
  final SlugPinCallback onPinComplete;
  final VoidCallback onBack;

  const _FormResident({
    required this.isLoading,
    this.error,
    required this.onPinComplete,
    required this.onBack,
  });

  @override
  State<_FormResident> createState() => _FormResidentState();
}

class _FormResidentState extends State<_FormResident> {
  final _slugCtrl = TextEditingController();

  @override
  void dispose() {
    _slugCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RetourRole(label: 'Résident(e)', onBack: widget.onBack),
        const SizedBox(height: AppSizes.lg),

        TextField(
          controller: _slugCtrl,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          decoration: _fieldDeco(
            label: 'Numéro d\'appartement',
            hint: 'Ex : 101',
            icon: Icons.home_outlined,
          ),
        ),
        const SizedBox(height: AppSizes.lg),

        const Text(
          'Code PIN à 4 chiffres',
          style: TextStyle(
              fontSize: 13,
              color: AppColors.grisText,
              fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.sm),

        PinInputWidget(
          slug: _slugCtrl.text,
          pinLength: 4,
          isLoading: widget.isLoading,
          error: widget.error,
          onPinComplete: (pin) =>
              widget.onPinComplete(_slugCtrl.text.trim(), pin),
        ),
      ],
    );
  }
}

class _FormResponsable extends StatefulWidget {
  final bool isLoading;
  final String? error;
  final SlugPinCallback onPinComplete;
  final VoidCallback onBack;

  const _FormResponsable({
    required this.isLoading,
    this.error,
    required this.onPinComplete,
    required this.onBack,
  });

  @override
  State<_FormResponsable> createState() => _FormResponsableState();
}

class _FormResponsableState extends State<_FormResponsable> {
  final _slugCtrl = TextEditingController();

  @override
  void dispose() {
    _slugCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RetourRole(label: 'Responsable', onBack: widget.onBack),
        const SizedBox(height: AppSizes.lg),

        TextField(
          controller: _slugCtrl,
          textInputAction: TextInputAction.next,
          decoration: _fieldDeco(
            label: 'Votre identifiant',
            hint: 'Ex : responsable-jt',
            icon: Icons.manage_accounts_outlined,
          ),
        ),
        const SizedBox(height: AppSizes.lg),

        const Text(
          'Mot de passe (8 chiffres)',
          style: TextStyle(
              fontSize: 13,
              color: AppColors.grisText,
              fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.sm),

        PinInputWidget(
          slug: _slugCtrl.text,
          pinLength: 8,
          isLoading: widget.isLoading,
          error: widget.error,
          onPinComplete: (pin) =>
              widget.onPinComplete(_slugCtrl.text.trim(), pin),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// WIDGETS UTILITAIRES
// ══════════════════════════════════════════════════════════

class _SubmitBtn extends StatelessWidget {
  final bool isLoading;
  final String label;
  final VoidCallback onPressed;

  const _SubmitBtn({
    required this.isLoading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.rouge,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.rouge.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(
            color: AppColors.rouge.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.rouge),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.rouge,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// LOGIQUE AUTH (inchangée)
// ══════════════════════════════════════════════════════════

Future<void> _handlePinLogic(
  BuildContext context,
  WidgetRef ref,
  String pin,
  String? slug,
  AuthNiveau niveau,
  String? roleSelecte,
) async {
  if (niveau == AuthNiveau.un) return;

  final notifier = ref.read(authNotifierProvider.notifier);
  final success = await notifier.login(
    slug: slug ?? '',
    pin: pin,
    role: roleSelecte,
  );

  if (success && context.mounted) {
    final employee = ref.read(authNotifierProvider).employee;
    if (employee == null) return;

    switch (employee.role) {
      case RoleType.employe:
        context.go(AppRoutes.employeeDashboard);
        break;
      case RoleType.superviseurMenage:
      case RoleType.admin:
      case RoleType.direction:
      case RoleType.reception:
        context.go(AppRoutes.employerDashboard);
        break;
      case RoleType.resident:
        context.go(AppRoutes.residentDashboard);
        break;
    }
  }
}
