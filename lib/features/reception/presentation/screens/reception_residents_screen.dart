import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/reception_models.dart';
import '../providers/reception_residents_provider.dart';
import '../reception_sections.dart';

/// Section « Résidents » de la vue Réception : recherche d'un appartement, par
/// numéro ou par nom de résident. Lecture seule.
class ReceptionResidentsScreen extends ConsumerStatefulWidget {
  const ReceptionResidentsScreen({super.key});

  @override
  ConsumerState<ReceptionResidentsScreen> createState() =>
      _ReceptionResidentsScreenState();
}

class _ReceptionResidentsScreenState
    extends ConsumerState<ReceptionResidentsScreen> {
  static const _delaiSaisie = Duration(milliseconds: 300);

  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _recherche = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String texte) {
    setState(() {}); // le bouton « Effacer » suit la saisie sans attendre
    _debounce?.cancel();
    _debounce = Timer(_delaiSaisie, () {
      if (mounted) setState(() => _recherche = texte.trim());
    });
  }

  void _effacer() {
    _debounce?.cancel();
    _ctrl.clear();
    setState(() => _recherche = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Résidents',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: TextField(
                  controller: _ctrl,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Numéro d\'appartement ou nom du résident',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _ctrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: _effacer,
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(child: _corps()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _corps() {
    if (_recherche.isEmpty) {
      return const _Message(
        icon: Icons.manage_search_rounded,
        texte: 'Recherchez un appartement pour consulter sa fiche.',
      );
    }

    return ref.watch(receptionRechercheProvider(_recherche)).when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.rouge),
          ),
          error: (erreur, _) => _Message(
            icon: Icons.error_outline_rounded,
            texte: erreur.toString(),
            actionLabel: 'Réessayer',
            onAction: () =>
                ref.invalidate(receptionRechercheProvider(_recherche)),
          ),
          data: (resultats) => resultats.isEmpty
              ? const _Message(
                  icon: Icons.search_off_rounded,
                  texte: 'Aucun appartement ne correspond à cette recherche.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.md,
                    0,
                    AppSizes.md,
                    AppSizes.lg,
                  ),
                  itemCount: resultats.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSizes.sm),
                  itemBuilder: (_, i) => _ResultatTile(resultat: resultats[i]),
                ),
        );
  }
}

class _ResultatTile extends StatelessWidget {
  final AppartementResultat resultat;

  const _ResultatTile({required this.resultat});

  @override
  Widget build(BuildContext context) {
    final residents = resultat.residents.isEmpty
        ? 'Aucun résident actif'
        : resultat.residents.join(', ');
    final etage = resultat.etage == null ? '' : ' · Étage ${resultat.etage}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: () => context.go(receptionFicheRoute(resultat.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              const Icon(Icons.apartment_rounded, color: AppColors.rouge),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appartement ${resultat.numero}$etage',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      residents,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.grisDark),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.grisDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String texte;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.texte,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.grisDark),
            const SizedBox(height: AppSizes.sm),
            Text(
              texte,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grisDark, height: 1.4),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSizes.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
