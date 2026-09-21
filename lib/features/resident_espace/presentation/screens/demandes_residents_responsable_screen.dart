import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../messages_reception_responsable/presentation/providers/messages_reception_responsable_provider.dart';
import '../../../messages_reception_responsable/presentation/widgets/messages_reception_section.dart';
import '../../domain/entities/demande_resident.dart';
import '../providers/demandes_responsable_provider.dart';

enum _StatutFiltre { tous, enAttente, repondues, resolues }

/// Les deux listes de l'écran : les demandes venues du portail des résidents et
/// les messages que la Réception transmet au responsable.
enum _Onglet { demandes, messages }

String _typeLabelFor(TypeDemande t) => switch (t) {
      TypeDemande.reprogrammer => 'Reprogrammer',
      TypeDemande.annuler => 'Annuler',
      TypeDemande.commentaire => 'Commentaire',
      TypeDemande.infoAppartement => 'Infos appartement',
    };

class DemandesResidentsResponsableScreen extends ConsumerStatefulWidget {
  /// Ouvre directement l'onglet « Messages de la réception » (par exemple depuis
  /// une notification).
  final bool ouvrirMessages;

  const DemandesResidentsResponsableScreen({
    super.key,
    this.ouvrirMessages = false,
  });

  @override
  ConsumerState<DemandesResidentsResponsableScreen> createState() =>
      _DemandesResidentsResponsableScreenState();
}

class _DemandesResidentsResponsableScreenState
    extends ConsumerState<DemandesResidentsResponsableScreen> {
  late _Onglet _onglet =
      widget.ouvrirMessages ? _Onglet.messages : _Onglet.demandes;
  _StatutFiltre _statutFiltre = _StatutFiltre.tous;
  TypeDemande? _typeFiltre;

  List<DemandeResident> _filtrer(List<DemandeResident> demandes) {
    return demandes.where((d) {
      final matchStatut = switch (_statutFiltre) {
        _StatutFiltre.tous => true,
        _StatutFiltre.enAttente => d.enAttente,
        _StatutFiltre.repondues => d.repondue,
        _StatutFiltre.resolues => d.resolue,
      };
      final matchType = _typeFiltre == null || d.type == _typeFiltre;
      return matchStatut && matchType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demandesResponsableProvider);
    final filtrees = _filtrer(state.demandes);
    final filtresActifs =
        _statutFiltre != _StatutFiltre.tous || _typeFiltre != null;

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
          if (state.isLoading && _onglet == _Onglet.demandes)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Actualiser',
              onPressed: () => _onglet == _Onglet.messages
                  ? ref.invalidate(messagesReceptionResponsableProvider)
                  : ref.read(demandesResponsableProvider.notifier).charger(),
            ),
        ],
      ),
      body: Column(
        children: [
          _OngletBar(
            onglet: _onglet,
            onChanged: (o) => setState(() => _onglet = o),
          ),
          Expanded(
            child: _onglet == _Onglet.messages
                ? const MessagesReceptionSection()
                : Column(
        children: [
          _FiltreBar(
            statutFiltre: _statutFiltre,
            typeFiltre: _typeFiltre,
            onStatutChanged: (s) => setState(() => _statutFiltre = s),
            onTypeChanged: (t) => setState(() => _typeFiltre = t),
          ),
          if (state.isLoading && state.demandes.isEmpty)
            const Expanded(child: AppSkeletonList())
          else if (state.demandes.isEmpty)
            Expanded(child: _Empty())
          else if (filtrees.isEmpty)
            Expanded(
              child: _EmptyFiltre(
                onReinitialiser: () => setState(() {
                  _statutFiltre = _StatutFiltre.tous;
                  _typeFiltre = null;
                }),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: AppColors.rouge,
                onRefresh: () => ref
                    .read(demandesResponsableProvider.notifier)
                    .charger(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final hPad = constraints.maxWidth >= 900
                        ? (constraints.maxWidth - 680) / 2
                        : AppSizes.md.toDouble();
                    return filtresActifs
                        ? ListView.separated(
                            padding: EdgeInsets.symmetric(
                                horizontal: hPad, vertical: AppSizes.md),
                            itemCount: filtrees.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSizes.sm),
                            itemBuilder: (_, i) =>
                                _DemandeCard(demande: filtrees[i]),
                          )
                        : _SectionsGroupees(
                            demandes: filtrees, hPad: hPad);
                  },
                ),
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

// ── Onglets : demandes des résidents / messages de la réception ──

class _OngletBar extends ConsumerWidget {
  final _Onglet onglet;
  final ValueChanged<_Onglet> onChanged;

  const _OngletBar({required this.onglet, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enAttente = ref.watch(messagesReceptionEnAttenteProvider);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
          AppSizes.md, AppSizes.sm, AppSizes.md, 0),
      child: Row(
        children: [
          _OngletTab(
            label: 'Demandes des résidents',
            selected: onglet == _Onglet.demandes,
            onTap: () => onChanged(_Onglet.demandes),
          ),
          const SizedBox(width: AppSizes.sm),
          _OngletTab(
            label: 'Messages de la réception',
            compteur: enAttente,
            selected: onglet == _Onglet.messages,
            onTap: () => onChanged(_Onglet.messages),
          ),
        ],
      ),
    );
  }
}

class _OngletTab extends StatelessWidget {
  final String label;
  final int compteur;
  final bool selected;
  final VoidCallback onTap;

  const _OngletTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compteur = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.rouge : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.rouge : AppColors.grisDark,
                  ),
                ),
              ),
              if (compteur > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.rouge,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$compteur',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sections groupées par statut (vue par défaut, sans filtre) ──

class _SectionsGroupees extends StatelessWidget {
  final List<DemandeResident> demandes;
  final double hPad;
  const _SectionsGroupees({required this.demandes, required this.hPad});

  @override
  Widget build(BuildContext context) {
    final enAttente = demandes.where((d) => d.enAttente).toList();
    final repondues = demandes.where((d) => d.repondue).toList();
    final resolues = demandes.where((d) => d.resolue).toList();

    return ListView(
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: AppSizes.md),
      children: [
        if (enAttente.isNotEmpty) ...[
          _SectionHeader('En attente (${enAttente.length})'),
          const SizedBox(height: AppSizes.sm),
          ...enAttente.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: _DemandeCard(demande: d),
              )),
          const SizedBox(height: AppSizes.md),
        ],
        if (repondues.isNotEmpty) ...[
          const _SectionHeader('En attente de réponse résident'),
          const SizedBox(height: AppSizes.sm),
          ...repondues.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: _DemandeCard(demande: d),
              )),
          const SizedBox(height: AppSizes.md),
        ],
        if (resolues.isNotEmpty) ...[
          const _SectionHeader('Résolues'),
          const SizedBox(height: AppSizes.sm),
          ...resolues.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: _DemandeCard(demande: d),
              )),
        ],
      ],
    );
  }
}

// ── Barre de filtres ──────────────────────────────────────

class _FiltreBar extends StatelessWidget {
  final _StatutFiltre statutFiltre;
  final TypeDemande? typeFiltre;
  final ValueChanged<_StatutFiltre> onStatutChanged;
  final ValueChanged<TypeDemande?> onTypeChanged;

  const _FiltreBar({
    required this.statutFiltre,
    required this.typeFiltre,
    required this.onStatutChanged,
    required this.onTypeChanged,
  });

  static const _statuts = [
    (_StatutFiltre.tous, 'Tous'),
    (_StatutFiltre.enAttente, 'En attente'),
    (_StatutFiltre.repondues, 'Répondues'),
    (_StatutFiltre.resolues, 'Résolues'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statuts
                  .map((s) => _ChipFiltre(
                        label: s.$2,
                        selected: statutFiltre == s.$1,
                        onTap: () => onStatutChanged(s.$1),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ChipFiltre(
                  label: 'Tous types',
                  selected: typeFiltre == null,
                  outlined: true,
                  onTap: () => onTypeChanged(null),
                ),
                ...TypeDemande.values.map((t) => _ChipFiltre(
                      label: _typeLabelFor(t),
                      selected: typeFiltre == t,
                      outlined: true,
                      onTap: () => onTypeChanged(typeFiltre == t ? null : t),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipFiltre extends StatelessWidget {
  final String label;
  final bool selected;
  final bool outlined;
  final VoidCallback onTap;

  const _ChipFiltre({
    required this.label,
    required this.selected,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.rouge.withValues(alpha: 0.1)
                : (outlined ? Colors.white : AppColors.grisLight),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.rouge : AppColors.grisMedium,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? AppColors.rouge : AppColors.grisDark,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Carte demande (vue responsable) ──────────────────────

class _DemandeCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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

          // ── Infos appartement : bloc dédié valider/refuser ──
          if (demande.type == TypeDemande.infoAppartement &&
              demande.enAttente) ...[
            const SizedBox(height: AppSizes.sm),
            _PropositionInfoBox(demande: demande),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _refuserInfo(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.grisDark,
                      side: const BorderSide(color: AppColors.grisMedium),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSm)),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _validerInfo(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.fait,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSm)),
                    ),
                    child: const Text('Valider et appliquer'),
                  ),
                ),
              ],
            ),
          ]
          // Bouton répondre (autres types — EnAttente ou refus)
          else if (demande.enAttente ||
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

  Future<void> _validerInfo(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(demandesResponsableProvider.notifier)
        .validerInfoAppartement(demande.id);
    if (!ok && context.mounted) {
      final error = ref.read(demandesResponsableProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.rouge),
        );
      }
    }
  }

  void _refuserInfo(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _RefuserInfoDialog(demandeId: demande.id),
    );
  }

  String _typeLabel(TypeDemande t) => switch (t) {
        TypeDemande.reprogrammer => 'Reprogrammer un ménage',
        TypeDemande.annuler => 'Annuler un ménage',
        TypeDemande.commentaire => 'Commentaire',
        TypeDemande.infoAppartement => _typeLabelFor(t),
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

// ── Bloc proposition infos appartement ────────────────────

class _PropositionInfoBox extends StatelessWidget {
  final DemandeResident demande;
  const _PropositionInfoBox({required this.demande});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.aVerifier.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.aVerifier.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (demande.propositionHasAnimal == true)
            Row(
              children: [
                const Icon(Icons.pets_rounded,
                    size: 15, color: AppColors.aVerifier),
                const SizedBox(width: 6),
                Text(
                  (demande.propositionTypeAnimal?.isNotEmpty ?? false)
                      ? 'Animal : ${demande.propositionTypeAnimal}'
                      : 'Animal présent',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.noir),
                ),
              ],
            ),
          if (demande.propositionHasAnimal == true &&
              (demande.propositionNotes?.isNotEmpty ?? false))
            const SizedBox(height: 4),
          if (demande.propositionNotes?.isNotEmpty ?? false)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded,
                    size: 15, color: AppColors.grisDark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    demande.propositionNotes!,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.grisDark),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Dialog refus infos appartement ────────────────────────

class _RefuserInfoDialog extends ConsumerStatefulWidget {
  final String demandeId;
  const _RefuserInfoDialog({required this.demandeId});

  @override
  ConsumerState<_RefuserInfoDialog> createState() =>
      _RefuserInfoDialogState();
}

class _RefuserInfoDialogState extends ConsumerState<_RefuserInfoDialog> {
  final _reponseCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reponseCtrl.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final reponse = _reponseCtrl.text.trim();
    if (reponse.isEmpty) {
      setState(() => _error = 'Veuillez expliquer le refus');
      return;
    }
    setState(() => _error = null);

    final ok = await ref
        .read(demandesResponsableProvider.notifier)
        .refuserInfoAppartement(demandeId: widget.demandeId, reponse: reponse);

    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSending = ref.watch(demandesResponsableProvider).isSending;

    return AlertDialog(
      title: const Text('Refuser la proposition ?'),
      content: TextField(
        controller: _reponseCtrl,
        maxLines: 3,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Expliquez pourquoi vous refusez…',
          errorText: _error,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
          contentPadding: const EdgeInsets.all(AppSizes.sm),
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
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
              : const Text('Confirmer le refus'),
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
      TypeDemande.infoAppartement => (
          Icons.info_outline_rounded,
          AppColors.aVerifier
        ),
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

class _EmptyFiltre extends StatelessWidget {
  final VoidCallback onReinitialiser;
  const _EmptyFiltre({required this.onReinitialiser});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: AppColors.grisText),
            const SizedBox(height: AppSizes.md),
            const Text('Aucun résultat',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.noir)),
            const SizedBox(height: AppSizes.xs),
            const Text('Aucune demande ne correspond à ces filtres.',
                style: TextStyle(fontSize: 13, color: AppColors.grisDark)),
            const SizedBox(height: AppSizes.md),
            OutlinedButton.icon(
              onPressed: onReinitialiser,
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Réinitialiser les filtres'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.rouge),
            ),
          ],
        ),
      );
}
