import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        surfaceTintColor: AppColors.rouge,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () => context.backOrHome(
            employee.isResponsable
                ? AppRoutes.employerDashboard
                : AppRoutes.employeeDashboard,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Mon profil',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHeader(employee: employee),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE7E9F2)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Informations personnelles',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Ces informations permettent à l’équipe de vous '
                          'identifier correctement.',
                          style: TextStyle(
                            color: AppColors.grisDark,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 22),
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
                              children: [
                                fields[0],
                                const SizedBox(height: 14),
                                fields[1],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        _ReadOnlyField(
                          label: 'Rôle',
                          value: employee.role.label,
                          icon: Icons.admin_panel_settings_outlined,
                        ),
                        if (employee.numeroPointeuse?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 14),
                          _ReadOnlyField(
                            label: 'Numéro de pointeuse',
                            value: employee.numeroPointeuse!,
                            icon: Icons.pin_outlined,
                            helper:
                                'Seul un administrateur peut modifier ce numéro.',
                          ),
                        ],
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : () => _save(employee),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.rouge,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 15,
                              ),
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
                              _saving
                                  ? 'Enregistrement…'
                                  : 'Enregistrer les modifications',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _LogoutCard(onLogout: _confirmLogout),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
            Employee(
              id: employee.id,
              nom: lastName,
              prenom: firstName,
              slug: employee.slug,
              role: employee.role,
              isActif: employee.isActif,
              numeroPointeuse: employee.numeroPointeuse,
              nomResidence: employee.nomResidence,
              dateCreation: employee.dateCreation,
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
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: AppColors.rouge),
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez vous identifier à nouveau pour accéder à votre espace.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Rester connecté'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) context.go(AppRoutes.login);
  }

  void _feedback(String message, {bool success = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              success ? const Color(0xFF176B3A) : const Color(0xFF9F2D2D),
          content: Text(message),
        ),
      );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final initials = '${employee.prenom.isEmpty ? '' : employee.prenom[0]}'
            '${employee.nom.isEmpty ? '' : employee.nom[0]}'
        .toUpperCase();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.rouge, AppColors.rougeLight],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: Colors.white.withValues(alpha: .18),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.nomComplet,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  employee.role.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF7F8FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.rouge, width: 1.5),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
    this.helper,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(icon),
        suffixIcon: const Tooltip(
          message: 'Ce champ ne peut pas être modifié ici',
          child: Icon(Icons.lock_outline_rounded, size: 18),
        ),
        filled: true,
        fillColor: const Color(0xFFF2F3F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF4C7C7)),
      ),
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
                  style: TextStyle(fontSize: 11, color: AppColors.grisDark),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onLogout,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF9F2D2D),
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
