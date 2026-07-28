import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/demande_resident.dart';
import '../../domain/entities/tache_resident.dart';
import '../providers/resident_espace_provider.dart';

const double _kDesktop = 900;

/// Affiche un Dialog sur desktop, un BottomSheet sur mobile.
Future<bool?> showNouvelleDemandeModal(
  BuildContext context, {
  required List<TacheResident> tachesDisponibles,
}) {
  final isDesktop = MediaQuery.of(context).size.width >= _kDesktop;

  if (isDesktop) {
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
        child: SizedBox(
          width: 560,
          height: 660,
          child: NouvelleDemandeSheet(
            tachesDisponibles: tachesDisponibles,
            showHandle: false,
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.88,
      child: NouvelleDemandeSheet(
        tachesDisponibles: tachesDisponibles,
        showHandle: true,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────

class NouvelleDemandeSheet extends ConsumerStatefulWidget {
  final List<TacheResident> tachesDisponibles;
  final bool showHandle;

  const NouvelleDemandeSheet({
    super.key,
    required this.tachesDisponibles,
    this.showHandle = true,
  });

  @override
  ConsumerState<NouvelleDemandeSheet> createState() =>
      _NouvelleDemandeSheetState();
}

class _NouvelleDemandeSheetState extends ConsumerState<NouvelleDemandeSheet> {
  TypeDemande? _type;
  TacheResident? _tacheSelectee;
  final _motifController = TextEditingController();
  String? _motifError;
  String? _submitError;

  @override
  void dispose() {
    _motifController.dispose();
    super.dispose();
  }

  bool get _peutSelectionnerTache =>
      _type == TypeDemande.reprogrammer || _type == TypeDemande.annuler;

  bool get _avertissementUrgent =>
      _type == TypeDemande.annuler &&
      _tacheSelectee != null &&
      _tacheSelectee!.estAujourdhui;

  bool get _tacheRequise =>
      _type == TypeDemande.reprogrammer || _type == TypeDemande.annuler;

  List<TacheResident> get _tachesEligibles {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_type == TypeDemande.reprogrammer) {
      // Passés NonCommencé (ménages ratés) + le prochain à venir (y compris aujourd'hui)
      final passes = widget.tachesDisponibles
          .where((t) => t.dateReelle.isBefore(today))
          .toList();
      final prochain = widget.tachesDisponibles
          .where((t) => !t.dateReelle.isBefore(today))
          .firstOrNull;
      return [...passes, if (prochain != null) prochain];
    }
    if (_type == TypeDemande.annuler) {
      // Uniquement aujourd'hui et futurs (impossible d'annuler un passé)
      return widget.tachesDisponibles
          .where((t) => !t.dateReelle.isBefore(today))
          .take(2)
          .toList();
    }
    return [];
  }

  Future<void> _soumettre() async {
    if (_type == null) return;

    // Validation : tâche obligatoire pour reprogrammer / annuler
    if (_tacheRequise && _tacheSelectee == null) {
      setState(() => _submitError = 'Veuillez sélectionner le ménage concerné');
      return;
    }

    final motif = _motifController.text.trim();
    if (motif.length < 10) {
      setState(() {
        _motifError = 'Le motif doit faire au moins 10 caractères';
        _submitError = null;
      });
      return;
    }
    setState(() {
      _motifError = null;
      _submitError = null;
    });

    final success = await ref
        .read(residentEspaceNotifierProvider.notifier)
        .creerDemande(
          type: _type!,
          tacheJourId: _tacheSelectee?.id,
          motif: motif,
          estUrgente: _avertissementUrgent,
        );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final erreur = ref.read(residentEspaceNotifierProvider).errorDemandes;
      setState(() => _submitError =
          erreur ?? 'Erreur lors de l\'envoi. Réessayez.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSending =
        ref.watch(residentEspaceNotifierProvider).isSendingDemande;

    return Column(
      children: [
        // ── Poignée (mobile uniquement) ─────────────────
        if (widget.showHandle)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grisMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        // ── En-tête ─────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(
            left: AppSizes.md,
            right: AppSizes.sm,
            top: widget.showHandle ? AppSizes.sm : AppSizes.md,
            bottom: AppSizes.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nouvelle demande',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.noir,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Corps scrollable ─────────────────────────────
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(
              left: AppSizes.md,
              right: AppSizes.md,
              top: AppSizes.md,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.xl,
            ),
            children: [
              // Type
              const _SectionLabel('Type de demande'),
              const SizedBox(height: AppSizes.sm),
              _TypeCard(
                icon: Icons.calendar_month_rounded,
                label: 'Reprogrammer un ménage',
                subtitle: 'Demander de changer la date',
                selected: _type == TypeDemande.reprogrammer,
                onTap: () => setState(() {
                  _type = TypeDemande.reprogrammer;
                  _tacheSelectee = null;
                  _submitError = null;
                }),
              ),
              const SizedBox(height: AppSizes.sm),
              _TypeCard(
                icon: Icons.cancel_rounded,
                label: 'Annuler un ménage',
                subtitle: 'Demander l\'annulation d\'une date',
                selected: _type == TypeDemande.annuler,
                onTap: () => setState(() {
                  _type = TypeDemande.annuler;
                  _tacheSelectee = null;
                  _submitError = null;
                }),
              ),
              const SizedBox(height: AppSizes.sm),
              _TypeCard(
                icon: Icons.chat_bubble_rounded,
                label: 'Laisser un commentaire',
                subtitle: 'Message général à l\'équipe',
                selected: _type == TypeDemande.commentaire,
                onTap: () => setState(() {
                  _type = TypeDemande.commentaire;
                  _tacheSelectee = null;
                  _submitError = null;
                }),
              ),
              const SizedBox(height: AppSizes.lg),

              // Sélection de tâche
              if (_peutSelectionnerTache && _tachesEligibles.isNotEmpty) ...[
                _SectionLabel(
                  _type == TypeDemande.reprogrammer
                      ? 'Quel ménage reprogrammer ?'
                      : 'Quel ménage annuler ?',
                ),
                const SizedBox(height: AppSizes.sm),
                ..._tachesEligibles.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.sm),
                      child: _TacheChoixCard(
                        tache: t,
                        selected: _tacheSelectee?.id == t.id,
                        onTap: () => setState(() {
                          _tacheSelectee = t;
                          _submitError = null;
                        }),
                      ),
                    )),
                const SizedBox(height: AppSizes.md),
              ],

              // Avertissement urgence
              if (_avertissementUrgent) ...[
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  margin: const EdgeInsets.only(bottom: AppSizes.md),
                  decoration: BoxDecoration(
                    color: AppColors.aVerifier.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(
                        color: AppColors.aVerifier.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.flash_on_rounded,
                          color: AppColors.aVerifier, size: 20),
                      SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Text(
                          'Ménage prévu ce matin. Pour une réponse rapide, contactez l\'équipe directement.',
                          style: TextStyle(fontSize: 13, color: AppColors.noir),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Motif
              if (_type != null) ...[
                const _SectionLabel('Motif'),
                const SizedBox(height: AppSizes.sm),
                // Message d'erreur de soumission
                if (_submitError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSizes.sm),
                    margin: const EdgeInsets.only(bottom: AppSizes.sm),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 16, color: Colors.red.shade700),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            _submitError!,
                            style: TextStyle(
                                fontSize: 13, color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextField(
                  controller: _motifController,
                  maxLines: 4,
                  maxLength: 500,
                  onChanged: (_) {
                    if (_motifError != null) setState(() => _motifError = null);
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Décrivez votre demande (minimum 10 caractères)…',
                    hintStyle: const TextStyle(
                        color: AppColors.grisText, fontSize: 14),
                    errorText: _motifError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      borderSide:
                          const BorderSide(color: AppColors.grisMedium),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      borderSide: const BorderSide(color: AppColors.rouge),
                    ),
                    contentPadding: const EdgeInsets.all(AppSizes.md),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSending ? null : _soumettre,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rouge,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                    child: isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Envoyer la demande',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.grisDark,
          letterSpacing: 0.3,
        ),
      );
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.rouge.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: selected ? AppColors.rouge : AppColors.grisMedium,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.rouge.withValues(alpha: 0.12)
                    : AppColors.grisLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.rouge : AppColors.grisDark,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: selected ? AppColors.rouge : AppColors.noir,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.grisText),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.rouge, size: 20),
          ],
        ),
      ),
    );
  }
}

class _TacheChoixCard extends StatelessWidget {
  final TacheResident tache;
  final bool selected;
  final VoidCallback onTap;

  static const _jours = [
    'lundi', 'mardi', 'mercredi', 'jeudi',
    'vendredi', 'samedi', 'dimanche'
  ];
  static const _mois = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];

  const _TacheChoixCard({
    required this.tache,
    required this.selected,
    required this.onTap,
  });

  String get _dateLabel {
    final d = tache.dateReelle;
    final base = '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';
    return tache.estAujourdhui ? "Aujourd'hui — $base" : base;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.rouge.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(
            color: selected ? AppColors.rouge : AppColors.grisMedium,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.event_rounded,
                size: 18,
                color: selected ? AppColors.rouge : AppColors.grisDark),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                '$_dateLabel · ${tache.periodeDisplayLabel}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.rouge : AppColors.noir,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  color: AppColors.rouge, size: 18),
          ],
        ),
      ),
    );
  }
}
