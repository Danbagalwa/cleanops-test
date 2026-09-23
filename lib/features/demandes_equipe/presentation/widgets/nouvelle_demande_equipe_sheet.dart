import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/compression_photo.dart' show formaterTaille;
import '../../domain/entities/demande_equipe.dart';
import '../../domain/entities/fichier_choisi.dart';
import '../providers/demande_equipe_provider.dart';

/// Taille maximale d'un document joint (avant encodage base64).
const tailleMaxDocumentDemande = 5 * 1024 * 1024;

const _extensionsDocumentDemande = ['pdf', 'jpg', 'jpeg', 'png'];

/// `null` si l'extension n'est pas acceptée.
String? typeMimeDocumentDemande(String? extension) =>
    switch (extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };

const double _kDesktop = 900;

/// Affiche un Dialog sur desktop, un BottomSheet sur mobile.
Future<bool?> showNouvelleDemandeEquipeModal(BuildContext context) {
  final isDesktop = MediaQuery.of(context).size.width >= _kDesktop;

  if (isDesktop) {
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
        child: const SizedBox(
          width: 480,
          child: NouvelleDemandeEquipeSheet(showHandle: false),
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
    builder: (_) => const NouvelleDemandeEquipeSheet(showHandle: true),
  );
}

// ─────────────────────────────────────────────────────────

class NouvelleDemandeEquipeSheet extends ConsumerStatefulWidget {
  final bool showHandle;
  const NouvelleDemandeEquipeSheet({super.key, this.showHandle = true});

  @override
  ConsumerState<NouvelleDemandeEquipeSheet> createState() =>
      _NouvelleDemandeEquipeSheetState();
}

class _NouvelleDemandeEquipeSheetState
    extends ConsumerState<NouvelleDemandeEquipeSheet> {
  TypeDemandeEquipe _type = TypeDemandeEquipe.conge;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  bool _plusieursJours = false;
  final _motifController = TextEditingController();
  String? _error;

  Uint8List? _documentOctets;
  String? _documentNom;
  String? _documentTypeMime;
  String? _erreurDocument;

  @override
  void dispose() {
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _choisirDate({required bool debut}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: debut
          ? (_dateDebut ?? now)
          : (_dateFin ?? _dateDebut ?? now),
      firstDate: debut ? now : (_dateDebut ?? now),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('fr', 'CA'),
    );
    if (picked == null) return;
    setState(() {
      if (debut) {
        _dateDebut = picked;
        if (_dateFin != null && _dateFin!.isBefore(picked)) _dateFin = null;
      } else {
        _dateFin = picked;
      }
      _error = null;
    });
  }

  Future<void> _choisirDocument() async {
    setState(() => _erreurDocument = null);
    FichierChoisi? fichier;
    try {
      fichier = await ref
          .read(selecteurDocumentProvider)
          .choisir(extensions: _extensionsDocumentDemande);
    } catch (_) {
      setState(() =>
          _erreurDocument = "Impossible d'ouvrir le sélecteur de fichier.");
      return;
    }
    if (!mounted || fichier == null) return;

    final octets = fichier.octets;
    if (octets.length > tailleMaxDocumentDemande) {
      setState(() => _erreurDocument =
          'Ce document est trop volumineux (${formaterTaille(tailleMaxDocumentDemande)} maximum).');
      return;
    }
    final typeMime = typeMimeDocumentDemande(fichier.extension);
    if (typeMime == null) {
      setState(() => _erreurDocument = 'Formats acceptés : PDF, JPEG ou PNG.');
      return;
    }

    setState(() {
      _documentOctets = octets;
      _documentNom = fichier!.nom;
      _documentTypeMime = typeMime;
      _erreurDocument = null;
    });
  }

  void _retirerDocument() {
    setState(() {
      _documentOctets = null;
      _documentNom = null;
      _documentTypeMime = null;
      _erreurDocument = null;
    });
  }

  Future<void> _soumettre() async {
    if (_dateDebut == null) {
      setState(() => _error = 'Veuillez choisir une date de début');
      return;
    }
    final motif = _motifController.text.trim();
    if (motif.isEmpty) {
      setState(() => _error = 'Veuillez indiquer un motif');
      return;
    }
    setState(() => _error = null);

    final success = await ref
        .read(mesDemandesEquipeNotifierProvider.notifier)
        .creerDemande(
          type: _type,
          dateDebut: _dateDebut!,
          dateFin: _plusieursJours ? _dateFin : null,
          motif: motif,
          documentOctets: _documentOctets,
          documentNom: _documentNom,
          documentTypeMime: _documentTypeMime,
        );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final erreur = ref.read(mesDemandesEquipeNotifierProvider).error;
      setState(() => _error = erreur ?? 'Erreur lors de l\'envoi. Réessayez.');
    }
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'Choisir…';
    const mois = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
      'juil', 'août', 'sep', 'oct', 'nov', 'déc',
    ];
    return '${d.day} ${mois[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isSending = ref.watch(mesDemandesEquipeNotifierProvider).isSending;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                    color: AppColors.noir),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: AppSizes.md,
              right: AppSizes.md,
              top: AppSizes.md,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Type de demande',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grisDark)),
                const SizedBox(height: AppSizes.sm),
                Row(
                  children: [
                    Expanded(
                      child: _TypeCard(
                        icon: Icons.beach_access_rounded,
                        label: 'Congé',
                        selected: _type == TypeDemandeEquipe.conge,
                        onTap: () =>
                            setState(() => _type = TypeDemandeEquipe.conge),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: _TypeCard(
                        icon: Icons.event_busy_rounded,
                        label: 'Absence planifiée',
                        selected:
                            _type == TypeDemandeEquipe.absencePlanifiee,
                        onTap: () => setState(
                            () => _type = TypeDemandeEquipe.absencePlanifiee),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),

                Row(
                  children: [
                    const Expanded(
                      child: Text('Date de début',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grisDark)),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Plusieurs jours',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.grisDark)),
                        Switch(
                          value: _plusieursJours,
                          activeThumbColor: AppColors.rouge,
                          onChanged: (v) =>
                              setState(() => _plusieursJours = v),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: _plusieursJours ? 'Du' : 'Date',
                        value: _fmt(_dateDebut),
                        onTap: () => _choisirDate(debut: true),
                      ),
                    ),
                    if (_plusieursJours) ...[
                      const SizedBox(width: AppSizes.sm),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 16, color: AppColors.grisText),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: _DateButton(
                          label: 'Au',
                          value: _fmt(_dateFin),
                          onTap: _dateDebut == null
                              ? null
                              : () => _choisirDate(debut: false),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSizes.lg),

                const Text('Motif',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grisDark)),
                const SizedBox(height: AppSizes.sm),
                if (_error != null) ...[
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
                          child: Text(_error!,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.red.shade700)),
                        ),
                      ],
                    ),
                  ),
                ],
                TextField(
                  controller: _motifController,
                  maxLines: 3,
                  maxLength: 300,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    hintText: 'Décrivez votre demande…',
                    hintStyle: const TextStyle(
                        color: AppColors.grisText, fontSize: 14),
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
                const SizedBox(height: AppSizes.lg),

                const Text('Document (optionnel)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grisDark)),
                const SizedBox(height: AppSizes.sm),
                if (_erreurDocument != null) ...[
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
                          child: Text(_erreurDocument!,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.red.shade700)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_documentNom == null)
                  OutlinedButton.icon(
                    onPressed: _choisirDocument,
                    icon: const Icon(Icons.attach_file_rounded, size: 18),
                    label: const Text('Joindre un document (PDF ou image)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rouge,
                      side: const BorderSide(color: AppColors.grisMedium),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: AppColors.grisLight,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(color: AppColors.grisMedium),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.description_rounded,
                            color: AppColors.rouge),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_documentNom!,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.noir)),
                              Text(formaterTaille(_documentOctets!.length),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.grisDark)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Retirer le document',
                          onPressed: _retirerDocument,
                        ),
                      ],
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
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
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
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sm, vertical: AppSizes.md),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.rouge.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: selected ? AppColors.rouge : AppColors.grisMedium,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppColors.rouge : AppColors.grisDark,
                size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? AppColors.rouge : AppColors.noir,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.grisLight,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(color: AppColors.grisMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 10, color: AppColors.grisText)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.noir)),
          ],
        ),
      ),
    );
  }
}
