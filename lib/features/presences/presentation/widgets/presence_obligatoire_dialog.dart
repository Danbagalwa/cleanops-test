import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/presence.dart';
import '../providers/presence_provider.dart';

/// Fenêtre bloquante : s'affiche à l'ouverture si la préposée n'a pas encore
/// confirmé sa présence du jour (jours de travail seulement). Elle choisit
/// d'abord sa situation, puis confirme : un appui par erreur n'envoie rien.
/// On ne peut pas la fermer sans répondre, sauf en se déconnectant (appareil
/// partagé, mauvaise personne connectée).
class PresenceObligatoireDialog extends ConsumerStatefulWidget {
  final String employeeId;
  const PresenceObligatoireDialog({super.key, required this.employeeId});

  @override
  ConsumerState<PresenceObligatoireDialog> createState() =>
      _PresenceObligatoireDialogState();
}

/// Les cinq réponses possibles.
enum _Choix {
  present,
  horairePartiel,
  absentMatin,
  absentApresMidi,
  absent;

  StatutPresence get statut => switch (this) {
        _Choix.present || _Choix.horairePartiel => StatutPresence.present,
        _Choix.absentMatin => StatutPresence.absentMatin,
        _Choix.absentApresMidi => StatutPresence.absentApresMidi,
        _Choix.absent => StatutPresence.absent,
      };

  String get titre => switch (this) {
        _Choix.present => 'Présente',
        _Choix.horairePartiel => 'Présente, horaire partiel',
        _Choix.absentMatin => 'Absente le matin',
        _Choix.absentApresMidi => 'Absente l’après-midi',
        _Choix.absent => 'Absente',
      };

  String get detail => switch (this) {
        _Choix.present => 'Toute la journée',
        _Choix.horairePartiel => 'Je travaille une partie de la journée',
        _Choix.absentMatin => 'Présente l’après-midi (PM)',
        _Choix.absentApresMidi => 'Présente le matin (AM)',
        _Choix.absent => 'Toute la journée',
      };

  IconData get icone => switch (this) {
        _Choix.present => Icons.check_circle_outline_rounded,
        _Choix.horairePartiel => Icons.schedule_rounded,
        _Choix.absentMatin => Icons.wb_sunny_outlined,
        _Choix.absentApresMidi => Icons.nights_stay_outlined,
        _Choix.absent => Icons.person_off_outlined,
      };

  Color get couleur => switch (this) {
        _Choix.present || _Choix.horairePartiel => AppColors.fait,
        _Choix.absentMatin || _Choix.absentApresMidi => AppColors.aVerifier,
        _Choix.absent => AppColors.refus,
      };

  /// Ce que la confirmation déclenche, dit à la préposée avant d'envoyer.
  String? get consequence => switch (this) {
        _Choix.present => null,
        _Choix.horairePartiel => 'Votre horaire est transmis au responsable à '
            'titre d’information. Vos tâches du jour ne changent pas.',
        _ => 'Votre responsable sera prévenu de votre absence.',
      };
}

class _PresenceObligatoireDialogState
    extends ConsumerState<PresenceObligatoireDialog> {
  _Choix? _choix;
  TimeOfDay _debut = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _fin = const TimeOfDay(hour: 13, minute: 0);
  bool _envoi = false;

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  bool get _horaireValide => _minutes(_fin) > _minutes(_debut);

  bool get _peutConfirmer =>
      _choix != null &&
      !_envoi &&
      (_choix != _Choix.horairePartiel || _horaireValide);

  String _affiche(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')} h ${t.minute.toString().padLeft(2, '0')}';

  String _base(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _choisirHeure({required bool debut}) async {
    final choisie = await showTimePicker(
      context: context,
      initialTime: debut ? _debut : _fin,
      helpText: debut ? 'Heure d’arrivée' : 'Heure de départ',
    );
    if (choisie == null || !mounted) return;
    setState(() => debut ? _debut = choisie : _fin = choisie);
  }

  Future<void> _confirmer() async {
    final choix = _choix;
    if (choix == null || !_peutConfirmer) return;
    setState(() => _envoi = true);
    final partiel = choix == _Choix.horairePartiel;
    final ids = await idsResponsablesAPrevenir(ref);
    await ref
        .read(maPresenceNotifierProvider(widget.employeeId).notifier)
        .confirmer(
          date: DateTime.now(),
          statut: choix.statut,
          responsableIds: ids,
          heureDebut: partiel ? _base(_debut) : null,
          heureFin: partiel ? _base(_fin) : null,
        );
    // Succès : la fenêtre se ferme (écoute ci-dessous). Échec : on réessaie.
    if (mounted) setState(() => _envoi = false);
  }

  Future<void> _seDeconnecter() async {
    final routeur = GoRouter.of(context);
    Navigator.of(context).pop();
    await ref.read(authNotifierProvider.notifier).logout();
    routeur.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maPresenceNotifierProvider(widget.employeeId));
    final prenom = ref.watch(employeeCourantProvider)?.prenom ?? '';

    // Ferme la fenêtre dès que la présence est enregistrée.
    ref.listen(maPresenceNotifierProvider(widget.employeeId), (prev, next) {
      if (prev?.isLoading == true &&
          !next.isLoading &&
          next.maPresence != null &&
          next.error == null &&
          mounted) {
        Navigator.of(context).pop();
      }
    });

    final jour = DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now());
    final jourAffiche = '${jour[0].toUpperCase()}${jour.substring(1)}';
    final choix = _choix;

    return PopScope(
      // Le bouton Retour d'Android ne ferme pas la fenêtre.
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EnTete(prenom: prenom, jour: jourAffiche),
              const Divider(height: 1, color: AppColors.grisMedium),

              // ── Choix ───────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Quelle est votre situation aujourd’hui ?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grisDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final c in _Choix.values) ...[
                        _CarteChoix(
                          choix: c,
                          selectionne: choix == c,
                          actif: !_envoi,
                          onTap: () => setState(() => _choix = c),
                        ),
                        if (c == _Choix.horairePartiel &&
                            choix == _Choix.horairePartiel)
                          _Horaire(
                            debut: _affiche(_debut),
                            fin: _affiche(_fin),
                            valide: _horaireValide,
                            actif: !_envoi,
                            onDebut: () => _choisirHeure(debut: true),
                            onFin: () => _choisirHeure(debut: false),
                          ),
                        const SizedBox(height: 8),
                      ],
                      if (choix?.consequence != null) ...[
                        const SizedBox(height: 4),
                        _Information(choix!.consequence!),
                      ],
                      if (state.error != null) ...[
                        const SizedBox(height: 10),
                        const _Erreur(
                          'Votre réponse n’a pas pu être enregistrée. '
                          'Vérifiez la connexion et réessayez.',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.grisMedium),

              // ── Pied ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 20, 12),
                child: Row(
                  children: [
                    Flexible(
                      child: TextButton(
                        onPressed: _envoi ? null : _seDeconnecter,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.grisDark,
                          textStyle: const TextStyle(fontSize: 12.5),
                        ),
                        child: const Text(
                          'Ce n’est pas moi',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _peutConfirmer ? _confirmer : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: choix?.couleur ?? AppColors.rouge,
                        disabledBackgroundColor:
                            AppColors.rouge.withValues(alpha: 0.3),
                        disabledForegroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        minimumSize: const Size(0, 46),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: _envoi
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Confirmer'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── En-tête ────────────────────────────────────────────────

class _EnTete extends StatelessWidget {
  final String prenom;
  final String jour;
  const _EnTete({required this.prenom, required this.jour});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.rouge.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.how_to_reg_rounded,
                color: AppColors.rouge, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prenom.isEmpty ? 'Bonjour !' : 'Bonjour $prenom !',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.noir,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Confirmez votre présence · $jour',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.grisDark,
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

// ── Une réponse ────────────────────────────────────────────

class _CarteChoix extends StatelessWidget {
  final _Choix choix;
  final bool selectionne;
  final bool actif;
  final VoidCallback onTap;

  const _CarteChoix({
    required this.choix,
    required this.selectionne,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = choix.couleur;
    return Semantics(
      selected: selectionne,
      button: true,
      child: Material(
        color: selectionne ? c.withValues(alpha: 0.08) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selectionne ? c : AppColors.grisMedium,
            width: selectionne ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          onTap: actif ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(choix.icone, size: 19, color: c),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        choix.titre,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selectionne ? c : AppColors.noir,
                        ),
                      ),
                      Text(
                        choix.detail,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.grisDark,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    selectionne
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(selectionne),
                    size: 22,
                    color: selectionne ? c : AppColors.grisMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Horaire partiel ────────────────────────────────────────

class _Horaire extends StatelessWidget {
  final String debut;
  final String fin;
  final bool valide;
  final bool actif;
  final VoidCallback onDebut;
  final VoidCallback onFin;

  const _Horaire({
    required this.debut,
    required this.fin,
    required this.valide,
    required this.actif,
    required this.onDebut,
    required this.onFin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _BoutonHeure(
                  libelle: 'Arrivée',
                  heure: debut,
                  onTap: actif ? onDebut : null,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 16, color: AppColors.grisText),
              ),
              Expanded(
                child: _BoutonHeure(
                  libelle: 'Départ',
                  heure: fin,
                  onTap: actif ? onFin : null,
                  erreur: !valide,
                ),
              ),
            ],
          ),
          if (!valide)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'L’heure de départ doit suivre l’heure d’arrivée.',
                style: TextStyle(fontSize: 11.5, color: AppColors.refus),
              ),
            ),
        ],
      ),
    );
  }
}

class _BoutonHeure extends StatelessWidget {
  final String libelle;
  final String heure;
  final VoidCallback? onTap;
  final bool erreur;

  const _BoutonHeure({
    required this.libelle,
    required this.heure,
    required this.onTap,
    this.erreur = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: erreur ? AppColors.refus : AppColors.grisMedium,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    libelle,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.grisText),
                  ),
                  Text(
                    heure,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.noir,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.grisText),
          ],
        ),
      ),
    );
  }
}

// ── Messages ───────────────────────────────────────────────

class _Information extends StatelessWidget {
  final String texte;
  const _Information(this.texte);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline_rounded,
              size: 15, color: AppColors.grisDark),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texte,
            style: const TextStyle(fontSize: 12, color: AppColors.grisDark),
          ),
        ),
      ],
    );
  }
}

class _Erreur extends StatelessWidget {
  final String texte;
  const _Erreur(this.texte);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 18, color: Color(0xFFC2410C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9A3412),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
