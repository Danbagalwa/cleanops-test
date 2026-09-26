import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/employee.dart';
import '../constants/app_colors.dart';
import '../helpers/date_helper.dart';
import '../router/app_router.dart';

/// Bouton d'en-tête : texte + icône en largeur normale, icône seule en compact.
class EnTeteAction {
  final IconData icone;
  final String libelle;
  final VoidCallback onPressed;

  const EnTeteAction({
    required this.icone,
    required this.libelle,
    required this.onPressed,
  });
}

/// En-tête des tableaux de bord : initiale, « Bienvenue, Nom », date du jour,
/// nom et poste, puis « Mon Profil » (précédé des [actions] propres à l'écran).
class DashboardWelcomeHeader extends StatelessWidget {
  final Employee? employee;
  final List<EnTeteAction> actions;

  /// Précision affichée après la date (ex. la semaine de travail).
  final String? complement;

  const DashboardWelcomeHeader({
    super.key,
    required this.employee,
    this.actions = const [],
    this.complement,
  });

  @override
  Widget build(BuildContext context) {
    final e = employee;
    final nom = e?.nomComplet.trim() ?? '';
    final poste = e?.role.intitule.toUpperCase() ?? '';
    final initiale = nom.isEmpty ? '?' : nom[0].toUpperCase();
    final toutes = [
      ...actions,
      if (e != null)
        EnTeteAction(
          icone: Icons.person_outline_rounded,
          libelle: 'Mon Profil',
          onPressed: () => context.go(profilDe(e)),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 28,
            vertical: compact ? 14 : 18,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              _Initiale(lettre: initiale, taille: compact ? 44 : 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Bienvenue, ',
                            style: TextStyle(color: AppColors.noir),
                          ),
                          TextSpan(
                            text: nom,
                            style: const TextStyle(color: AppColors.rouge),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        'Le ${DateHelper.formatDateCourt(DateTime.now())}',
                        if (complement != null) complement!,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grisDark,
                      ),
                    ),
                    if (compact && poste.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          poste,
                          style: const TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.3,
                            color: AppColors.rouge,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!compact && nom.isNotEmpty) ...[
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      nom,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.noir,
                      ),
                    ),
                    Text(
                      poste,
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.3,
                        color: AppColors.rouge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
              ],
              for (final (i, action) in toutes.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                compact
                    ? _BoutonIcone(action: action)
                    : _BoutonLibelle(action: action),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Initiale extends StatelessWidget {
  final String lettre;
  final double taille;

  const _Initiale({required this.lettre, required this.taille});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.rouge,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        lettre,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

final _bordure = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
const _cote = BorderSide(color: AppColors.rouge, width: 1.5);

class _BoutonLibelle extends StatelessWidget {
  final EnTeteAction action;

  const _BoutonLibelle({required this.action});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: action.onPressed,
      icon: Icon(action.icone, size: 18),
      label: Text(action.libelle),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.rouge,
        side: _cote,
        shape: _bordure,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BoutonIcone extends StatelessWidget {
  final EnTeteAction action;

  const _BoutonIcone({required this.action});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: action.libelle,
      onPressed: action.onPressed,
      icon: Icon(action.icone, size: 20),
      style: IconButton.styleFrom(
        foregroundColor: AppColors.rouge,
        side: _cote,
        shape: _bordure,
      ),
    );
  }
}
