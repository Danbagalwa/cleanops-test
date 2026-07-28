import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/demande_resident.dart';
import '../providers/demandes_responsable_provider.dart';

class DemandesResidentsResponsableScreen extends ConsumerWidget {
  const DemandesResidentsResponsableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demandesResponsableProvider);

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text(
              'Demandes résidents',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            if (state.badgeEnAttente > 0) ...[
              const SizedBox(width: AppSizes.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.badgeEnAttente}',
                  style: const TextStyle(
                    color: AppColors.rouge,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () =>
                ref.read(demandesResponsableProvider.notifier).charger(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.demandes.isEmpty
              ? _Empty()
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(demandesResponsableProvider.notifier).charger(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final hPad = constraints.maxWidth >= 900
                          ? (constraints.maxWidth - 680) / 2
                          : AppSizes.md.toDouble();
                      return ListView(
                        padding: EdgeInsets.symmetric(
                            horizontal: hPad, vertical: AppSizes.md),
                        children: [
                          if (state.enAttente.isNotEmpty) ...[
                            _SectionHeader(
                                'En attente (${state.enAttente.length})'),
                            const SizedBox(height: AppSizes.sm),
                            ...state.enAttente.map((d) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSizes.sm),
                                  child: _DemandeCard(demande: d),
                                )),
                            const SizedBox(height: AppSizes.md),
                          ],
                          if (state.repondues.isNotEmpty) ...[
                            const _SectionHeader('En attente de réponse résident'),
                            const SizedBox(height: AppSizes.sm),
                            ...state.repondues.map((d) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSizes.sm),
                                  child: _DemandeCard(demande: d),
                                )),
                            const SizedBox(height: AppSizes.md),
                          ],
                          if (state.resolues.isNotEmpty) ...[
                            const _SectionHeader('Résolues'),
                            const SizedBox(height: AppSizes.sm),
                            ...state.resolues.map((d) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSizes.sm),
                                  child: _DemandeCard(demande: d),
                                )),
                          ],
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}

// ── Carte demande (vue responsable) ──────────────────────

class _DemandeCard extends StatelessWidget {
  final DemandeResident demande;
  const _DemandeCard({required this.demande});

  static const _jours = [
    'lundi', 'mardi', 'mercredi', 'jeudi',
    'vendredi', 'samedi', 'dimanche',
  ];
  static const _mois = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  String _fmt(DateTime d) =>
      '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: demande.enAttente
              ? AppColors.aVerifier.withValues(alpha: 0.5)
              : AppColors.grisMedium,
          width: demande.enAttente ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              _TypeIcon(demande.type),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeLabel(demande.type),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.noir),
                    ),
                    Text(
                      _fmt(demande.createdAt.toLocal()),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.grisDark),
                    ),
                  ],
                ),
              ),
              _StatutBadge(demande.statut),
              if (demande.estUrgente) ...[
                const SizedBox(width: AppSizes.sm),
                const _UrgenceBadge(),
              ],
            ],
          ),
          const SizedBox(height: AppSizes.sm),

          // Motif
          Text(demande.motif,
              style: const TextStyle(fontSize: 13, color: AppColors.grisDark)),

          // Réponse résident
          if (demande.repondue && demande.residentAccepte != null) ...[
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: demande.residentAccepte!
                    ? AppColors.faitBg
                    : AppColors.grisLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    demande.residentAccepte!
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 16,
                    color: demande.residentAccepte!
                        ? AppColors.fait
                        : AppColors.grisDark,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Text(
                    demande.residentAccepte!
                        ? 'Résident·e a accepté'
                        : 'Résident·e a refusé — nouvelle proposition requise',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: demande.residentAccepte!
                          ? AppColors.fait
                          : AppColors.grisDark,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Bouton répondre (EnAttente ou refus)
          if (demande.enAttente ||
              (demande.repondue && demande.residentAccepte == false)) ...[
            const SizedBox(height: AppSizes.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _ouvrirReponse(context),
                icon: const Icon(Icons.reply_rounded, size: 18),
                label: Text(demande.enAttente ? 'Répondre' : 'Nouvelle proposition'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rouge,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusSm)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _ouvrirReponse(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _RepondreDialog(demande: demande),
    );
  }

  String _typeLabel(TypeDemande t) => switch (t) {
        TypeDemande.reprogrammer => 'Reprogrammer un ménage',
        TypeDemande.annuler => 'Annuler un ménage',
        TypeDemande.commentaire => 'Commentaire',
      };
}

// ── Dialog réponse responsable ────────────────────────────

class _RepondreDialog extends ConsumerStatefulWidget {
  final DemandeResident demande;
  const _RepondreDialog({required this.demande});

  @override
  ConsumerState<_RepondreDialog> createState() => _RepondreDialogState();
}

class _RepondreDialogState extends ConsumerState<_RepondreDialog> {
  final _reponseCtrl = TextEditingController();
  DateTime? _propDate;
  String _propPeriode = 'AM';
  String? _reponseError;

  bool get _avecProposition =>
      widget.demande.type == TypeDemande.reprogrammer ||
      widget.demande.type == TypeDemande.annuler;

  @override
  void dispose() {
    _reponseCtrl.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final reponse = _reponseCtrl.text.trim();
    if (reponse.isEmpty) {
      setState(() => _reponseError = 'Veuillez saisir un message');
      return;
    }
    if (_avecProposition && _propDate == null) {
      setState(() => _reponseError = 'Veuillez choisir une date proposée');
      return;
    }
    setState(() => _reponseError = null);

    final ok = await ref.read(demandesResponsableProvider.notifier).repondre(
          demandeId: widget.demande.id,
          reponse: reponse,
          propositionDate: _avecProposition ? _propDate : null,
          propositionPeriode: _avecProposition ? _propPeriode : null,
        );

    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSending =
        ref.watch(demandesResponsableProvider).isSending;

    return AlertDialog(
      title: const Text('Répondre à la demande'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Motif original
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.grisLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(widget.demande.motif,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.grisDark)),
            ),
            const SizedBox(height: AppSizes.md),

            // Réponse
            const Text('Votre réponse',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grisDark)),
            const SizedBox(height: AppSizes.sm),
            TextField(
              controller: _reponseCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Expliquez votre décision…',
                errorText: _reponseError,
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusSm)),
                contentPadding: const EdgeInsets.all(AppSizes.sm),
              ),
              onChanged: (_) {
                if (_reponseError != null) {
                  setState(() => _reponseError = null);
                }
              },
            ),

            // Proposition date (reprogrammer / annuler)
            if (_avecProposition) ...[
              const SizedBox(height: AppSizes.md),
              const Text('Date proposée',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grisDark)),
              const SizedBox(height: AppSizes.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now()
                              .add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                          locale: const Locale('fr', 'CA'),
                        );
                        if (picked != null) {
                          setState(() => _propDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today_rounded,
                          size: 16),
                      label: Text(
                        _propDate == null
                            ? 'Choisir'
                            : '${_propDate!.day}/${_propDate!.month}/${_propDate!.year}',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rouge,
                        side: const BorderSide(color: AppColors.rouge),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'AM', label: Text('Matin')),
                      ButtonSegment(value: 'PM', label: Text('PM')),
                    ],
                    selected: {_propPeriode},
                    onSelectionChanged: (s) =>
                        setState(() => _propPeriode = s.first),
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.white
                            : AppColors.grisDark,
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? AppColors.rouge
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: isSending ? null : _envoyer,
          style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
          child: isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Envoyer'),
        ),
      ],
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

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

class _TypeIcon extends StatelessWidget {
  final TypeDemande type;
  const _TypeIcon(this.type);

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      TypeDemande.reprogrammer => (Icons.calendar_month_rounded, AppColors.rouge),
      TypeDemande.annuler => (Icons.cancel_rounded, AppColors.refus),
      TypeDemande.commentaire => (Icons.chat_bubble_rounded, AppColors.absent),
    };
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final StatutDemande statut;
  const _StatutBadge(this.statut);

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (statut) {
      StatutDemande.enAttente => ('En attente', AppColors.aVerifier.withValues(alpha: 0.15), AppColors.aVerifier),
      StatutDemande.repondue => ('Répondue', AppColors.absentBg, AppColors.absent),
      StatutDemande.resolue => ('Résolue', AppColors.faitBg, AppColors.fait),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _UrgenceBadge extends StatelessWidget {
  const _UrgenceBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.aVerifier.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('Urgent',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.aVerifier)),
      );
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 56, color: AppColors.grisText),
            SizedBox(height: AppSizes.md),
            Text('Aucune demande en cours',
                style: TextStyle(fontSize: 16, color: AppColors.grisDark)),
          ],
        ),
      );
}
