import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/dialogue_app.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/photo_profil_editeur.dart';
import '../../data/compte_repository.dart';
import 'package:cleanops/core/widgets/espace_barre_mobile.dart';
import 'package:cleanops/core/widgets/notification_app.dart';

/// « Mon profil » des employés (préposée, responsable, Réception) ; les
/// résidents ont le leur.
///
/// - Informations personnelles : prénom et nom.
/// - Connexion : identifiant (slug) et mot de passe, modifiables en donnant
///   son code actuel. La préposée se connecte avec son numéro de pointeuse,
///   que seul un administrateur modifie : elle n'a pas de mot de passe.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final employee = ref.read(employeeCourantProvider);
    _firstNameController = TextEditingController(text: employee?.prenom ?? '');
    _lastNameController = TextEditingController(text: employee?.nom ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(employeeCourantProvider);
    if (employee == null) {
      return const Scaffold(
        body: Center(child: Text('Votre session n’est plus active.')),
      );
    }
    final marge = estCompact(context) ? 12.0 : 24.0;

    return PageAvecEnTete(
      chargement: _saving,
      enTete: const EnTetePage(
        icone: Icons.person_rounded,
        titre: 'Mon profil',
        sousTitre: 'Vos informations et vos identifiants de connexion',
      ),
      contenu: ListView(
        padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
            .plusBarre(context),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BarreSection(
                    titre: 'Mon compte',
                    onRetour: () => context.backOrHome(accueilDe(employee)),
                  ),
                  const SizedBox(height: AppSizes.md),
                  _CarteIdentite(employee: employee),
                  const SizedBox(height: AppSizes.md),
                  _Section(
                    icone: Icons.badge_outlined,
                    titre: 'Informations personnelles',
                    sousTitre: 'Ces informations permettent à l’équipe de vous '
                        'identifier correctement.',
                    child: _formulaire(employee),
                  ),
                  if (!employee.isResident) ...[
                    const SizedBox(height: AppSizes.md),
                    _Section(
                      icone: Icons.key_rounded,
                      titre: 'Connexion',
                      sousTitre: employee.isPreposee
                          ? 'Votre identifiant et votre numéro de pointeuse '
                              'servent à vous connecter.'
                          : 'Votre identifiant et votre mot de passe servent '
                              'à vous connecter.',
                      padding: EdgeInsets.zero,
                      child: _connexion(employee),
                    ),
                  ],
                  const SizedBox(height: AppSizes.md),
                  _LogoutCard(onLogout: _confirmLogout),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Informations personnelles ───────────────────────────

  Widget _formulaire(Employee employee) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                _NameField(
                  controller: _firstNameController,
                  label: 'Prénom',
                  icon: Icons.person_outline_rounded,
                ),
                _NameField(
                  controller: _lastNameController,
                  label: 'Nom',
                  icon: Icons.badge_outlined,
                ),
              ];
              if (constraints.maxWidth >= 540) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 14),
                    Expanded(child: fields[1]),
                  ],
                );
              }
              return Column(
                children: [fields[0], const SizedBox(height: 14), fields[1]],
              );
            },
          ),
          const SizedBox(height: 14),
          _ReadOnlyField(
            label: 'Rôle',
            value: employee.role.libelleAffiche,
            icon: Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : () => _save(employee),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rouge,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
              ),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 19),
              label: Text(
                _saving ? 'Enregistrement…' : 'Enregistrer les modifications',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Connexion ───────────────────────────────────────────

  Widget _connexion(Employee employee) {
    return Column(
      children: [
        _LigneReglage(
          icone: Icons.alternate_email_rounded,
          titre: 'Identifiant',
          valeur: employee.slug,
          detail: 'À saisir sur l’écran de connexion.',
          libelleAction: 'Modifier',
          onAction: () => _changerIdentifiant(employee),
        ),
        const Divider(height: 1, color: AppColors.grisMedium),
        if (employee.isPreposee)
          const _LigneReglage(
            icone: Icons.pin_outlined,
            titre: 'Numéro de pointeuse',
            valeur: '••••••',
            detail: 'Seul un administrateur peut modifier ce numéro.',
          )
        else
          _LigneReglage(
            icone: Icons.lock_outline_rounded,
            titre: 'Mot de passe',
            valeur: '••••••••',
            detail: '8 chiffres.',
            libelleAction: 'Modifier',
            onAction: () => _changerMotDePasse(employee),
          ),
      ],
    );
  }

  Future<void> _changerIdentifiant(Employee employee) async {
    final slug = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogueIdentifiant(employee: employee),
    );
    if (slug == null || !mounted) return;
    ref.read(authNotifierProvider.notifier).setEmployee(
          employee.copyWith(slug: slug, dateMiseAJour: DateTime.now()),
        );
    NotificationApp.succes(
      context,
      'Votre identifiant est maintenant « $slug ». Utilisez-le à votre '
      'prochaine connexion.',
    );
  }

  Future<void> _changerMotDePasse(Employee employee) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogueMotDePasse(employee: employee),
    );
    if (ok != true || !mounted) return;
    NotificationApp.succes(
      context,
      'Votre mot de passe a été modifié. Utilisez-le à votre prochaine '
      'connexion.',
    );
  }

  // ── Actions ─────────────────────────────────────────────

  Future<void> _save(Employee employee) async {
    if (!_formKey.currentState!.validate()) return;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName == employee.prenom && lastName == employee.nom) {
      _feedback('Aucune modification à enregistrer.');
      return;
    }

    setState(() => _saving = true);
    try {
      await SupabaseService.table('employees').update({
        'prenom': firstName,
        'nom': lastName,
        'date_mise_a_jour': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', employee.id);

      ref.read(authNotifierProvider.notifier).setEmployee(
            employee.copyWith(
              prenom: firstName,
              nom: lastName,
              dateMiseAJour: DateTime.now(),
            ),
          );
      if (mounted) _feedback('Votre profil a bien été mis à jour.');
    } catch (_) {
      if (mounted) {
        _feedback(
          'La modification n’a pas pu être enregistrée. Réessayez dans un '
          'instant.',
          success: false,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DialogueApp(
        titre: 'Se déconnecter ?',
        contenu: const Text(
          'Vous devrez vous identifier à nouveau pour accéder à votre espace.',
        ),
        libelleSecondaire: 'Rester connecté',
        onSecondaire: () => Navigator.pop(dialogContext, false),
        libelleAction: 'Se déconnecter',
        onAction: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) context.go(AppRoutes.login);
  }

  void _feedback(String message, {bool success = true}) => success
      ? NotificationApp.succes(context, message)
      : NotificationApp.erreur(context, message);
}

// ══ Dialogues ═════════════════════════════════════════════

/// Code actuel demandé pour confirmer un changement : le numéro de pointeuse
/// pour la préposée, le mot de passe pour les autres.
class _ChampCode extends StatelessWidget {
  const _ChampCode({
    required this.controller,
    required this.label,
    required this.longueur,
    this.erreur,
    this.validator,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final int longueur;
  final String? erreur;
  final FormFieldValidator<String>? validator;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: longueur,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      autofillHints: const [AutofillHints.password],
      validator: validator ??
          (v) => (v ?? '').length == longueur
              ? null
              : '$longueur chiffres attendus',
      decoration: _decoration(
        label: label,
        icone: Icons.lock_outline_rounded,
        erreur: erreur,
      ).copyWith(counterText: ''),
    );
  }
}

class _DialogueIdentifiant extends ConsumerStatefulWidget {
  const _DialogueIdentifiant({required this.employee});

  final Employee employee;

  @override
  ConsumerState<_DialogueIdentifiant> createState() =>
      _DialogueIdentifiantState();
}

class _DialogueIdentifiantState extends ConsumerState<_DialogueIdentifiant> {
  final _formKey = GlobalKey<FormState>();
  late final _slug = TextEditingController(text: widget.employee.slug);
  final _code = TextEditingController();
  bool _enCours = false;
  String? _erreurSlug;
  String? _erreurCode;
  String? _erreurGenerale;

  bool get _preposee => widget.employee.isPreposee;

  @override
  void dispose() {
    _slug.dispose();
    _code.dispose();
    super.dispose();
  }

  String? _validerSlug(String? valeur) {
    final s = valeur ?? '';
    if (s.length < 3) return 'Au moins 3 caractères';
    if (!RegExp(r'^[a-z0-9]{3,30}$').hasMatch(s)) {
      return 'Lettres minuscules et chiffres uniquement';
    }
    if (s == widget.employee.slug) return 'C’est déjà votre identifiant';
    if (estSlugReserve(s)) {
      return 'Cet identifiant est réservé par l’application';
    }
    return null;
  }

  Future<void> _valider() async {
    setState(() => _erreurSlug = _erreurCode = _erreurGenerale = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    final slug = _slug.text;
    try {
      final resultat =
          await ref.read(compteRepositoryProvider).changerIdentifiant(
                employeeId: widget.employee.id,
                codeActuel: _code.text,
                nouveauSlug: slug,
              );
      if (!mounted) return;
      switch (resultat) {
        case ResultatCompte.ok:
          Navigator.pop(context, slug);
          return;
        case ResultatCompte.code:
          _erreurCode = _preposee
              ? 'Numéro de pointeuse incorrect'
              : 'Mot de passe incorrect';
        case ResultatCompte.pris:
          _erreurSlug = 'Cet identifiant est déjà utilisé';
        case ResultatCompte.format:
          _erreurSlug = 'Lettres minuscules et chiffres, 3 à 30 caractères';
        case ResultatCompte.interdit:
          _erreurGenerale = 'Modification refusée.';
      }
    } catch (_) {
      if (!mounted) return;
      _erreurGenerale = 'L’identifiant n’a pas pu être modifié. Vérifiez la '
          'connexion et réessayez.';
    }
    setState(() => _enCours = false);
  }

  @override
  Widget build(BuildContext context) {
    return DialogueApp(
      titre: 'Changer d’identifiant',
      enCours: _enCours,
      libelleSecondaire: 'Annuler',
      libelleAction: 'Enregistrer',
      onAction: _valider,
      contenu: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_erreurGenerale != null) ...[
              _Alerte(_erreurGenerale!),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _slug,
              autofocus: true,
              maxLength: 30,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.username],
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (_, nouveau) =>
                      nouveau.copyWith(text: nouveau.text.toLowerCase()),
                ),
                FilteringTextInputFormatter.allow(RegExp('[a-z0-9]')),
              ],
              validator: _validerSlug,
              decoration: _decoration(
                label: 'Nouvel identifiant',
                icone: Icons.alternate_email_rounded,
                erreur: _erreurSlug,
                aide: 'Lettres minuscules et chiffres, 3 à 30 caractères.',
              ),
            ),
            const SizedBox(height: 10),
            _ChampCode(
              controller: _code,
              label: _preposee ? 'Numéro de pointeuse' : 'Mot de passe actuel',
              longueur: _preposee ? 6 : 8,
              erreur: _erreurCode,
            ),
            const SizedBox(height: 6),
            Text(
              _preposee
                  ? 'Votre numéro de pointeuse confirme que c’est bien vous. '
                      'Il ne change pas.'
                  : 'Votre mot de passe confirme que c’est bien vous. Il ne '
                      'change pas.',
              style: const TextStyle(fontSize: 12, color: AppColors.grisDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogueMotDePasse extends ConsumerStatefulWidget {
  const _DialogueMotDePasse({required this.employee});

  final Employee employee;

  @override
  ConsumerState<_DialogueMotDePasse> createState() =>
      _DialogueMotDePasseState();
}

class _DialogueMotDePasseState extends ConsumerState<_DialogueMotDePasse> {
  final _formKey = GlobalKey<FormState>();
  final _ancien = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  bool _enCours = false;
  String? _erreurAncien;
  String? _erreurNouveau;
  String? _erreurGenerale;

  @override
  void dispose() {
    _ancien.dispose();
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    setState(() => _erreurAncien = _erreurNouveau = _erreurGenerale = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    try {
      final resultat =
          await ref.read(compteRepositoryProvider).changerMotDePasse(
                employeeId: widget.employee.id,
                ancien: _ancien.text,
                nouveau: _nouveau.text,
              );
      if (!mounted) return;
      switch (resultat) {
        case ResultatCompte.ok:
          Navigator.pop(context, true);
          return;
        case ResultatCompte.code:
          _erreurAncien = 'Mot de passe actuel incorrect';
        case ResultatCompte.format:
          _erreurNouveau = '8 chiffres attendus';
        case ResultatCompte.interdit:
        case ResultatCompte.pris:
          _erreurGenerale = 'Ce compte n’a pas de mot de passe modifiable.';
      }
    } catch (_) {
      if (!mounted) return;
      _erreurGenerale = 'Le mot de passe n’a pas pu être modifié. Vérifiez '
          'la connexion et réessayez.';
    }
    setState(() => _enCours = false);
  }

  @override
  Widget build(BuildContext context) {
    return DialogueApp(
      titre: 'Changer de mot de passe',
      enCours: _enCours,
      libelleSecondaire: 'Annuler',
      libelleAction: 'Enregistrer',
      onAction: _valider,
      contenu: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_erreurGenerale != null) ...[
              _Alerte(_erreurGenerale!),
              const SizedBox(height: 14),
            ],
            _ChampCode(
              controller: _ancien,
              label: 'Mot de passe actuel',
              longueur: 8,
              erreur: _erreurAncien,
              autofocus: true,
            ),
            const SizedBox(height: 14),
            _ChampCode(
              controller: _nouveau,
              label: 'Nouveau mot de passe',
              longueur: 8,
              erreur: _erreurNouveau,
              validator: (v) {
                if ((v ?? '').length != 8) return '8 chiffres attendus';
                if (v == _ancien.text) {
                  return 'Choisissez un mot de passe différent de l’actuel';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _ChampCode(
              controller: _confirmation,
              label: 'Confirmer le nouveau mot de passe',
              longueur: 8,
              validator: (v) => v == _nouveau.text
                  ? null
                  : 'Les deux mots de passe ne correspondent pas',
            ),
            const SizedBox(height: 6),
            const Text(
              'Le mot de passe se compose de 8 chiffres.',
              style: TextStyle(fontSize: 12, color: AppColors.grisDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _Alerte extends StatelessWidget {
  const _Alerte(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFC2410C), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9A3412),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _decoration({
  required String label,
  required IconData icone,
  String? erreur,
  String? aide,
}) {
  OutlineInputBorder bord(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    helperText: aide,
    helperMaxLines: 2,
    errorText: erreur,
    errorMaxLines: 2,
    prefixIcon: Icon(icone),
    filled: true,
    fillColor: const Color(0xFFF7F8FC),
    border: bord(AppColors.grisMedium),
    enabledBorder: bord(AppColors.grisMedium),
    focusedBorder: bord(AppColors.rouge, 1.5),
  );
}

// ══ Blocs de la page ══════════════════════════════════════

class _CarteIdentite extends StatelessWidget {
  const _CarteIdentite({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final initials = '${employee.prenom.isEmpty ? '' : employee.prenom[0]}'
            '${employee.nom.isEmpty ? '' : employee.nom[0]}'
        .toUpperCase();
    return CarteContenu(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Photo de profil (ou initiales), modifiable : réduite avant l'envoi.
          PhotoProfilEditeur(
            proprietaire: ProprietairePhoto.de(employee),
            initiales: initials,
            rayon: 34,
            couleurFond: AppColors.rouge.withValues(alpha: .10),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.nomComplet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.noir,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Etiquette(
                      icone: Icons.work_outline_rounded,
                      texte: employee.role.intitule,
                    ),
                    _Etiquette(
                      icone: Icons.alternate_email_rounded,
                      texte: employee.slug,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Etiquette extends StatelessWidget {
  const _Etiquette({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: AppColors.rouge),
          const SizedBox(width: 5),
          Text(
            texte,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.rouge,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloc titré de la page (même allure que les cartes de statistiques).
class _Section extends StatelessWidget {
  const _Section({
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final IconData icone;
  final String titre;
  final String sousTitre;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icone, color: AppColors.rouge, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.noir,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sousTitre,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.grisDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.grisMedium),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Ligne d'un réglage : icône, libellé et valeur, puis action (ou cadenas).
class _LigneReglage extends StatelessWidget {
  const _LigneReglage({
    required this.icone,
    required this.titre,
    required this.valeur,
    required this.detail,
    this.libelleAction,
    this.onAction,
  });

  final IconData icone;
  final String titre;
  final String valeur;
  final String detail;
  final String? libelleAction;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final modifiable = onAction != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: AppColors.grisDark, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grisDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valeur,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.noir,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.grisText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (modifiable)
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(libelleAction ?? 'Modifier'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rouge,
                side: const BorderSide(color: AppColors.rouge),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            )
          else
            const Tooltip(
              message: 'Modifiable uniquement par un administrateur',
              child: Icon(Icons.lock_outline_rounded,
                  size: 20, color: AppColors.grisText),
            ),
        ],
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      autofillHints: label == 'Prénom'
          ? const [AutofillHints.givenName]
          : const [AutofillHints.familyName],
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return '$label requis';
        if (text.length < 2) return '$label trop court';
        if (text.length > 80) return '$label trop long';
        return null;
      },
      decoration: _decoration(label: label, icone: icon),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: _decoration(label: label, icone: icon).copyWith(
        fillColor: const Color(0xFFF2F3F7),
        suffixIcon: const Tooltip(
          message: 'Ce champ ne peut pas être modifié ici',
          child: Icon(Icons.lock_outline_rounded, size: 18),
        ),
      ),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          const Icon(Icons.logout_rounded, color: Color(0xFF9F2D2D)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Déconnexion',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Fermer votre session sur cet appareil',
                  style: TextStyle(fontSize: 11.5, color: AppColors.grisDark),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onLogout,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF9F2D2D),
              side: const BorderSide(color: Color(0xFFF4C7C7)),
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
