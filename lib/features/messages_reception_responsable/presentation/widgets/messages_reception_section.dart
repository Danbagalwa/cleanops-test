import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reception/domain/reception_messages_models.dart';
import '../../../reception/domain/reception_models.dart' show NatureDemande;
import '../../../reception/domain/reception_residents_repository.dart'
    show ReceptionErreur;
import '../providers/messages_reception_responsable_provider.dart';

enum _Filtre { tous, enAttente, repondues, resolues }

/// Section « Messages de la réception » de l'écran « Demandes résidents » du
/// responsable : les demandes que la Réception lui transmet parce qu'elle ne peut
/// pas toucher au planning (annuler, reprogrammer…).
///
/// Le responsable y voit le message, y répond (« Répondue » : l'horaire n'a pas
/// changé) et le marque « Résolue » une fois l'horaire réellement modifié. Aucun
/// de ces boutons ne modifie un planning : il le fait lui-même avant de
/// confirmer.
class MessagesReceptionSection extends ConsumerStatefulWidget {
  const MessagesReceptionSection({super.key});

  @override
  ConsumerState<MessagesReceptionSection> createState() =>
      _MessagesReceptionSectionState();
}

class _MessagesReceptionSectionState
    extends ConsumerState<MessagesReceptionSection> {
  _Filtre _filtre = _Filtre.tous;

  bool _garde(MessageTransmis m) => switch (_filtre) {
        _Filtre.tous => true,
        _Filtre.enAttente => m.statut == StatutMessage.enAttente,
        _Filtre.repondues => m.statut == StatutMessage.repondue,
        _Filtre.resolues => m.statut == StatutMessage.resolue,
      };

  @override
  Widget build(BuildContext context) {
    final liste = ref.watch(messagesReceptionResponsableProvider);

    return Column(
      children: [
        _FiltreBar(
          filtre: _filtre,
          onChanged: (f) => setState(() => _filtre = f),
        ),
        if (liste.isLoading && liste.hasValue)
          const LinearProgressIndicator(
            color: AppColors.rouge,
            backgroundColor: Colors.transparent,
            minHeight: 2,
          ),
        Expanded(
          child: liste.when(
            loading: () => const AppSkeletonList(),
            error: (erreur, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.xl),
                child: AppErrorNotice(
                  error: erreur.toString(),
                  onRetry: () =>
                      ref.invalidate(messagesReceptionResponsableProvider),
                ),
              ),
            ),
            data: (tous) {
              if (tous.isEmpty) return const _Vide();
              final gardes = tous.where(_garde).toList();
              if (gardes.isEmpty) {
                return _VideFiltre(
                  onReinitialiser: () => setState(() => _filtre = _Filtre.tous),
                );
              }
              return RefreshIndicator(
                color: AppColors.rouge,
                onRefresh: () async =>
                    ref.invalidate(messagesReceptionResponsableProvider),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final hPad = constraints.maxWidth >= 900
                        ? (constraints.maxWidth - 680) / 2
                        : AppSizes.md.toDouble();
                    return _Liste(
                      messages: gardes,
                      groupes: _filtre == _Filtre.tous,
                      hPad: hPad,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Liste, groupée par statut quand aucun filtre n'est actif ──

class _Liste extends StatelessWidget {
  final List<MessageTransmis> messages;
  final bool groupes;
  final double hPad;

  const _Liste({
    required this.messages,
    required this.groupes,
    required this.hPad,
  });

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(horizontal: hPad, vertical: AppSizes.md);

    if (!groupes) {
      return ListView.separated(
        padding: padding,
        itemCount: messages.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
        itemBuilder: (_, i) => MessageReceptionCard(message: messages[i]),
      );
    }

    final enAttente =
        messages.where((m) => m.statut == StatutMessage.enAttente).toList();
    final repondues =
        messages.where((m) => m.statut == StatutMessage.repondue).toList();
    final resolues =
        messages.where((m) => m.statut == StatutMessage.resolue).toList();

    Widget groupe(String titre, List<MessageTransmis> liste) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
              child: Text(
                '$titre (${liste.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grisDark,
                ),
              ),
            ),
            for (final m in liste)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: MessageReceptionCard(message: m),
              ),
            const SizedBox(height: AppSizes.sm),
          ],
        );

    return ListView(
      padding: padding,
      children: [
        if (enAttente.isNotEmpty) groupe('En attente', enAttente),
        if (repondues.isNotEmpty) groupe('Répondues', repondues),
        if (resolues.isNotEmpty) groupe('Résolues', resolues),
      ],
    );
  }
}

// ── Filtres ───────────────────────────────────────────────

class _FiltreBar extends StatelessWidget {
  final _Filtre filtre;
  final ValueChanged<_Filtre> onChanged;

  const _FiltreBar({required this.filtre, required this.onChanged});

  static const _chips = [
    (_Filtre.tous, 'Tous'),
    (_Filtre.enAttente, 'En attente'),
    (_Filtre.repondues, 'Répondues'),
    (_Filtre.resolues, 'Résolues'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in _chips)
              _Chip(
                label: c.$2,
                selected: filtre == c.$1,
                onTap: () => onChanged(c.$1),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
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
                : AppColors.grisLight,
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

// ── Carte d'un message ────────────────────────────────────

/// Un message de la Réception, avec ses actions pour le responsable.
class MessageReceptionCard extends ConsumerWidget {
  final MessageTransmis message;

  const MessageReceptionCard({super.key, required this.message});

  IconData get _icone => switch (message.nature) {
        NatureDemande.annulation => Icons.event_busy_rounded,
        NatureDemande.reprogrammation => Icons.update_rounded,
        NatureDemande.autre => Icons.chat_bubble_outline_rounded,
      };

  Color get _couleurStatut => switch (message.statut) {
        StatutMessage.enAttente => AppColors.aVerifier,
        StatutMessage.repondue => AppColors.rouge,
        StatutMessage.resolue => AppColors.fait,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = message;
    final enAttente = m.statut == StatutMessage.enAttente;
    final resolue = m.statut == StatutMessage.resolue;
    final aReponse = m.reponse != null && m.reponse!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: enAttente
              ? AppColors.aVerifier.withValues(alpha: 0.5)
              : AppColors.grisMedium,
          width: enAttente ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.rouge.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icone, size: 18, color: AppColors.rouge),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apt ${m.numero} · ${m.nature.libelle}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.noir,
                      ),
                    ),
                    Text(
                      'Envoyé le ${m.envoyeLe}'
                      '${m.auteurPrenom.isEmpty ? '' : ' par ${m.auteurPrenom}'}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.grisDark),
                    ),
                  ],
                ),
              ),
              _Badge(label: m.statut.libelle, color: _couleurStatut),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          SelectableText(
            m.message,
            style: const TextStyle(fontSize: 13, color: AppColors.noir),
          ),
          if (m.transmisEmploye) ...[
            const SizedBox(height: AppSizes.xs),
            Text(
              m.employePrenom == null
                  ? "Transmis aussi à l'employé."
                  : "Transmis aussi à l'employé : ${m.employePrenom}.",
              style: const TextStyle(fontSize: 12, color: AppColors.grisDark),
            ),
          ],
          if (aReponse) ...[
            const SizedBox(height: AppSizes.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.grisLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Votre réponse'
                    '${m.dateReponse == null ? '' : ' · ${MessageTransmis.formater(m.dateReponse!)}'}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.grisDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(m.reponse!,
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
          if (resolue && m.dateResolution != null) ...[
            const SizedBox(height: AppSizes.sm),
            Text(
              'Résolue le ${MessageTransmis.formater(m.dateResolution!)} : '
              "l'horaire a été modifié.",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.fait,
              ),
            ),
          ],
          if (!resolue) ...[
            const SizedBox(height: AppSizes.md),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _RepondreDialog(message: m),
                  ),
                  icon: const Icon(Icons.reply_rounded, size: 18),
                  label: Text(enAttente ? 'Répondre' : 'Modifier la réponse'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rouge,
                    side: const BorderSide(color: AppColors.rouge),
                  ),
                ),
                // « Horaire modifié » n'existe que pour une annulation ou une
                // reprogrammation : une « Autre demande » n'a pas d'horaire.
                if (m.concerneHoraire)
                  FilledButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => _ResoudreDialog(message: m),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Horaire modifié'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.fait,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Répondre ──────────────────────────────────────────────

class _RepondreDialog extends ConsumerStatefulWidget {
  final MessageTransmis message;

  const _RepondreDialog({required this.message});

  @override
  ConsumerState<_RepondreDialog> createState() => _RepondreDialogState();
}

class _RepondreDialogState extends ConsumerState<_RepondreDialog> {
  static const _longueurMax = 2000;

  late final TextEditingController _ctrl =
      TextEditingController(text: widget.message.reponse ?? '');
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _valide => _ctrl.text.trim().isNotEmpty && !_envoi;

  Future<void> _envoyer() async {
    final auteur = ref.read(employeeCourantProvider);
    if (auteur == null) {
      setState(() => _erreur = 'Votre session a expiré. Reconnectez-vous.');
      return;
    }

    setState(() {
      _envoi = true;
      _erreur = null;
    });

    try {
      await ref.read(messagesReceptionResponsableRepositoryProvider).repondre(
            messageId: widget.message.id,
            auteurId: auteur.id,
            reponse: _ctrl.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(messagesReceptionResponsableProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réponse enregistrée.')),
      );
    } on ReceptionErreur catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final modification = m.statut == StatutMessage.repondue;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      title: Text(modification ? 'Modifier la réponse' : 'Répondre'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apt ${m.numero} · ${m.nature.libelle}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSizes.xs),
              Text(m.message,
                  style: const TextStyle(color: AppColors.grisDark, height: 1.4)),
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _ctrl,
                enabled: !_envoi,
                minLines: 3,
                maxLines: 6,
                maxLength: _longueurMax,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Votre réponse',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                ),
              ),
              Text(
                m.concerneHoraire
                    ? "La Réception verra cette réponse. Le message passe à « Répondue » "
                        "(l'horaire n'a pas changé). Utilisez « Horaire modifié » une "
                        'fois le planning changé.'
                    : 'La Réception verra cette réponse. Le message passe à '
                        '« Répondue ».',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.grisDark, height: 1.4),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: AppSizes.sm),
                Text(_erreur!, style: const TextStyle(color: AppColors.refus)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _valide ? _envoyer : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
          child: _envoi
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Envoyer la réponse'),
        ),
      ],
    );
  }
}

// ── Résoudre ──────────────────────────────────────────────

class _ResoudreDialog extends ConsumerStatefulWidget {
  final MessageTransmis message;

  const _ResoudreDialog({required this.message});

  @override
  ConsumerState<_ResoudreDialog> createState() => _ResoudreDialogState();
}

class _ResoudreDialogState extends ConsumerState<_ResoudreDialog> {
  bool _envoi = false;
  String? _erreur;

  Future<void> _confirmer() async {
    final auteur = ref.read(employeeCourantProvider);
    if (auteur == null) {
      setState(() => _erreur = 'Votre session a expiré. Reconnectez-vous.');
      return;
    }

    setState(() {
      _envoi = true;
      _erreur = null;
    });

    try {
      await ref.read(messagesReceptionResponsableRepositoryProvider).resoudre(
            messageId: widget.message.id,
            auteurId: auteur.id,
          );
      if (!mounted) return;
      ref.invalidate(messagesReceptionResponsableProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message marqué comme résolu.')),
      );
    } on ReceptionErreur catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      title: const Text('Horaire modifié ?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apt ${m.numero} · ${m.nature.libelle}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSizes.sm),
            const Text(
              "Confirmez que le planning a bien été modifié. Le message passera "
              'à « Résolue » et la Réception verra que l\'horaire a changé.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: AppSizes.xs),
            const Text(
              'Cette action ne modifie pas le planning : faites-le avant.',
              style: TextStyle(height: 1.4, color: AppColors.grisDark),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: AppSizes.sm),
              Text(_erreur!, style: const TextStyle(color: AppColors.refus)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : _confirmer,
          style: FilledButton.styleFrom(backgroundColor: AppColors.fait),
          child: _envoi
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirmer'),
        ),
      ],
    );
  }
}

// ── États vides ───────────────────────────────────────────

class _Vide extends StatelessWidget {
  const _Vide();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forward_to_inbox_outlined,
                size: 56, color: AppColors.grisDark),
            SizedBox(height: AppSizes.md),
            Text(
              'Aucun message de la réception',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppSizes.sm),
            Text(
              'Les demandes que la Réception vous transmet apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grisDark, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideFiltre extends StatelessWidget {
  final VoidCallback onReinitialiser;

  const _VideFiltre({required this.onReinitialiser});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_list_off_rounded,
              size: 48, color: AppColors.grisDark),
          const SizedBox(height: AppSizes.md),
          const Text(
            'Aucun message ne correspond à ce filtre',
            style: TextStyle(color: AppColors.grisDark),
          ),
          const SizedBox(height: AppSizes.md),
          OutlinedButton(
            onPressed: onReinitialiser,
            child: const Text('Tout afficher'),
          ),
        ],
      ),
    );
  }
}
