import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/reception_models.dart';
import '../../domain/reception_residents_repository.dart';
import '../providers/reception_residents_provider.dart';

/// Formulaire de message vers l'administration, depuis la fiche d'un
/// appartement, avec la case facultative « Transmettre aussi à l'employé ».
class MessageFormCard extends ConsumerStatefulWidget {
  final FicheAppartement fiche;

  const MessageFormCard({super.key, required this.fiche});

  @override
  ConsumerState<MessageFormCard> createState() => _MessageFormCardState();
}

class _MessageFormCardState extends ConsumerState<MessageFormCard> {
  static const _longueurMax = 2000;

  final _ctrl = TextEditingController();
  bool _transmettre = false;
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _peutEnvoyer => _ctrl.text.trim().isNotEmpty && !_envoi;

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
      await ref.read(receptionResidentsRepositoryProvider).envoyerMessage(
            appartementId: widget.fiche.id,
            auteurId: auteur.id,
            message: _ctrl.text.trim(),
            transmettreEmploye: _transmettre,
          );
      if (!mounted) return;
      _ctrl.clear();
      setState(() {
        _envoi = false;
        _transmettre = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message transmis à l\'administration.')),
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
    final concerne = widget.fiche.employeConcerne;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Message à l\'administration',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSizes.sm),
            TextField(
              controller: _ctrl,
              enabled: !_envoi,
              minLines: 3,
              maxLines: 6,
              maxLength: _longueurMax,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText:
                    'Écrivez votre message concernant l\'appartement '
                    '${widget.fiche.numero}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _transmettre,
              onChanged: concerne == null || _envoi
                  ? null
                  : (v) => setState(() => _transmettre = v ?? false),
              title: const Text('Transmettre aussi à l\'employé'),
              subtitle: Text(
                concerne == null
                    ? 'Aucun employé n\'est concerné par cet appartement.'
                    : 'Employé concerné : ${concerne.prenom}',
              ),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: AppSizes.xs),
              Text(
                _erreur!,
                style: const TextStyle(color: AppColors.refus),
              ),
            ],
            const SizedBox(height: AppSizes.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _peutEnvoyer ? _envoyer : null,
                icon: _envoi
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Envoyer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
