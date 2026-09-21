import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/reception_models.dart';
import '../../domain/reception_residents_repository.dart' show ReceptionErreur;
import '../providers/reception_pin_provider.dart';
import '../providers/reception_residents_provider.dart';
import 'pin_affichage_dialog.dart';

/// Ouvre la fenêtre d'inscription d'un résident sur un appartement libre.
Future<void> ouvrirInscriptionResident(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const InscriptionResidentDialog(),
  );
}

/// Inscription d'un résident par la Réception, À LA DEMANDE D'UN RESPONSABLE.
///
/// La Réception saisit le nom et indique quel responsable a demandé
/// l'inscription (trace obligatoire). La date d'arrivée est remplie par le
/// serveur. Elle peut ensuite générer le PIN. Elle n'assigne AUCUN ménage :
/// fréquence, préposée, jour et période restent au responsable.
class InscriptionResidentDialog extends ConsumerStatefulWidget {
  const InscriptionResidentDialog({super.key});

  @override
  ConsumerState<InscriptionResidentDialog> createState() =>
      _InscriptionResidentDialogState();
}

class _InscriptionResidentDialogState
    extends ConsumerState<InscriptionResidentDialog> {
  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  AppartementLibre? _appartement;
  ResponsableDemandeur? _demandeur;
  bool _aApplication = true;
  bool _envoi = false;
  String? _erreur;

  ResidentInscrit? _inscrit;
  String _nomInscrit = '';
  bool _pinEnCours = false;
  bool _pinGenere = false;

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    super.dispose();
  }

  bool get _valide =>
      _appartement != null &&
      _demandeur != null &&
      _prenomCtrl.text.trim().isNotEmpty &&
      _nomCtrl.text.trim().isNotEmpty &&
      !_envoi;

  Future<void> _inscrire() async {
    final auteur = ref.read(employeeCourantProvider);
    final apt = _appartement;
    final demandeur = _demandeur;
    if (apt == null || demandeur == null) return;
    if (auteur == null) {
      setState(() => _erreur = 'Votre session a expiré. Reconnectez-vous.');
      return;
    }

    setState(() {
      _envoi = true;
      _erreur = null;
    });

    try {
      final resultat =
          await ref.read(receptionResidentsRepositoryProvider).inscrireResident(
                appartementId: apt.id,
                auteurId: auteur.id,
                prenom: _prenomCtrl.text.trim(),
                nom: _nomCtrl.text.trim(),
                demandeParId: demandeur.id,
                aApplication: _aApplication,
              );
      if (!mounted) return;
      ref.invalidate(receptionResidentsListeProvider);
      ref.invalidate(receptionAppartementsLibresProvider);
      ref.invalidate(receptionPinListeProvider);
      setState(() {
        _envoi = false;
        _inscrit = resultat;
        _nomInscrit = '${_prenomCtrl.text.trim()} ${_nomCtrl.text.trim()}';
      });
    } on ReceptionErreur catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = e.message;
      });
    }
  }

  Future<void> _genererPin() async {
    final auteur = ref.read(employeeCourantProvider);
    final inscrit = _inscrit;
    if (inscrit == null) return;
    if (auteur == null) {
      setState(() => _erreur = 'Votre session a expiré. Reconnectez-vous.');
      return;
    }

    setState(() {
      _pinEnCours = true;
      _erreur = null;
    });

    try {
      final pin = await ref.read(receptionPinRepositoryProvider).genererPin(
            residentId: inscrit.residentId,
            auteurId: auteur.id,
          );
      if (!mounted) return;
      setState(() {
        _pinEnCours = false;
        _pinGenere = true;
      });
      ref.invalidate(receptionPinListeProvider);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AffichagePinDialog(
          nomComplet: _nomInscrit,
          numero: inscrit.numero,
          pin: pin,
        ),
      );
    } on ReceptionErreur catch (e) {
      if (!mounted) return;
      setState(() {
        _pinEnCours = false;
        _erreur = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(AppSizes.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: SingleChildScrollView(
            child: _inscrit == null ? _formulaire() : _resultat(_inscrit!),
          ),
        ),
      ),
    );
  }

  // ── Formulaire ────────────────────────────────────────────

  Widget _formulaire() {
    final libres = ref.watch(receptionAppartementsLibresProvider);
    final responsables = ref.watch(receptionResponsablesProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Inscrire un résident',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close_rounded),
              onPressed: _envoi ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const Text(
          "À faire à la demande du responsable, pour un appartement qui n'a "
          "pas encore d'occupant.",
          style: TextStyle(color: AppColors.grisDark, height: 1.4),
        ),
        const SizedBox(height: AppSizes.md),
        libres.when(
          loading: () => const _Chargement(),
          error: (e, _) => _ErreurChargement(
            message: e.toString(),
            onRetry: () => ref.invalidate(receptionAppartementsLibresProvider),
          ),
          data: (liste) => liste.isEmpty
              ? const Text(
                  "Aucun appartement sans occupant : il n'y a personne à "
                  'inscrire pour le moment.',
                  style: TextStyle(color: AppColors.grisDark),
                )
              : DropdownButtonFormField<AppartementLibre>(
                  initialValue: _appartement,
                  isExpanded: true,
                  decoration: _deco('Appartement'),
                  items: [
                    for (final a in liste)
                      DropdownMenuItem(value: a, child: Text(a.libelle)),
                  ],
                  onChanged: _envoi
                      ? null
                      : (a) => setState(() => _appartement = a),
                ),
        ),
        const SizedBox(height: AppSizes.sm),
        TextField(
          controller: _prenomCtrl,
          enabled: !_envoi,
          textCapitalization: TextCapitalization.words,
          maxLength: 100,
          onChanged: (_) => setState(() {}),
          decoration: _deco('Prénom'),
        ),
        TextField(
          controller: _nomCtrl,
          enabled: !_envoi,
          textCapitalization: TextCapitalization.words,
          maxLength: 100,
          onChanged: (_) => setState(() {}),
          decoration: _deco('Nom'),
        ),
        const SizedBox(height: AppSizes.xs),
        responsables.when(
          loading: () => const _Chargement(),
          error: (e, _) => _ErreurChargement(
            message: e.toString(),
            onRetry: () => ref.invalidate(receptionResponsablesProvider),
          ),
          data: (liste) => DropdownButtonFormField<ResponsableDemandeur>(
            initialValue: _demandeur,
            isExpanded: true,
            decoration: _deco('À la demande de (responsable)'),
            items: [
              for (final r in liste)
                DropdownMenuItem(value: r, child: Text(r.nomComplet)),
            ],
            onChanged: _envoi ? null : (r) => setState(() => _demandeur = r),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Utilisera l'application"),
          subtitle: const Text(
              'Portail résident. Sans application, le résident est prévenu '
              'par téléphone ou en personne.'),
          value: _aApplication,
          onChanged: _envoi ? null : (v) => setState(() => _aApplication = v),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.sm + 4),
          decoration: BoxDecoration(
            color: AppColors.grisLight,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm + 4),
          ),
          child: const Text(
            "La Réception n'assigne aucun ménage : fréquence, préposée, jour "
            'et période sont définis par le responsable.',
            style: TextStyle(fontSize: 12.5, height: 1.4),
          ),
        ),
        if (_erreur != null) ...[
          const SizedBox(height: AppSizes.sm),
          Text(_erreur!, style: const TextStyle(color: AppColors.refus)),
        ],
        const SizedBox(height: AppSizes.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _valide ? _inscrire : null,
            icon: _envoi
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_rounded),
            label: const Text('Inscrire'),
          ),
        ),
      ],
    );
  }

  // ── Résultat ──────────────────────────────────────────────

  Widget _resultat(ResidentInscrit inscrit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.fait),
            SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                'Résident inscrit',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        Text('$_nomInscrit · Apt ${inscrit.numero}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSizes.xs),
        Text("Date d'arrivée : ${inscrit.dateArriveeCourte}",
            style: const TextStyle(color: AppColors.grisDark)),
        const SizedBox(height: AppSizes.sm),
        const Text(
          "Aucun ménage n'est encore planifié pour cet appartement : "
          'le responsable doit encore assigner la fréquence, la préposée, le '
          'jour et la période.',
          style: TextStyle(height: 1.4),
        ),
        if (_aApplication) ...[
          const SizedBox(height: AppSizes.sm),
          const Text(
            "Le PIN permet au résident d'utiliser le portail dès le premier "
            'jour.',
            style: TextStyle(height: 1.4, color: AppColors.grisDark),
          ),
        ],
        if (_erreur != null) ...[
          const SizedBox(height: AppSizes.sm),
          Text(_erreur!, style: const TextStyle(color: AppColors.refus)),
        ],
        const SizedBox(height: AppSizes.md),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_aApplication)
              OutlinedButton.icon(
                onPressed: _pinEnCours || _pinGenere ? null : _genererPin,
                icon: _pinEnCours
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.key_rounded, size: 18),
                label: Text(_pinGenere ? 'PIN généré' : 'Générer le PIN'),
              ),
            FilledButton(
              onPressed:
                  _pinEnCours ? null : () => Navigator.of(context).pop(),
              child: const Text('Terminé'),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      );
}

class _Chargement extends StatelessWidget {
  const _Chargement();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(AppSizes.md),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

class _ErreurChargement extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErreurChargement({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: AppColors.refus)),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      );
}
