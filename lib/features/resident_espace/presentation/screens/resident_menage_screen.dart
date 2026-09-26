import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/demande_resident.dart';
import '../../domain/entities/jour_menage.dart';
import '../providers/resident_espace_provider.dart';
import '../widgets/statut_menage_visuel.dart';

/// Détail d'une date du calendrier du résident : statut du ménage, infos de
/// base (appartement, préposée, fréquence — sans heure ni durée) et, pour un
/// ménage annulé, la demande de reprise.
class ResidentMenageScreen extends ConsumerWidget {
  final DateTime date;
  const ResidentMenageScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jour = DateTime(date.year, date.month, date.day);
    final calendrier =
        ref.watch(calendrierResidentProvider(DateTime(jour.year, jour.month)));
    final marge = estCompact(context) ? 12.0 : 24.0;

    void retour() => context.canPop()
        ? context.pop()
        : context.go('${AppRoutes.residentCalendrier}'
            '?mois=${DateFormat('yyyy-MM-dd').format(jour)}');

    return PageAvecEnTete(
      chargement: calendrier.isLoading && calendrier.hasValue,
      enTete: const EnTetePage(
        icone: Icons.event_note_rounded,
        titre: 'Détail de la date',
        sousTitre: 'Votre ménage à cette date',
      ),
      contenu: ListView(
        padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
            .plusBarre(context),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BarreSection(titre: dateLongue(jour), onRetour: retour),
                  const SizedBox(height: AppSizes.md),
                  ...calendrier.when(
                    skipLoadingOnReload: true,
                    loading: () => const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child:
                              CircularProgressIndicator(color: AppColors.rouge),
                        ),
                      ),
                    ],
                    error: (_, __) => [
                      _Bandeau(
                        icone: Icons.wifi_off_rounded,
                        couleur: AppColors.grisDark,
                        fond: AppColors.grisLight,
                        texte: 'Les informations n’ont pas pu être chargées.',
                        action: TextButton(
                          onPressed: () => ref.invalidate(
                              calendrierResidentProvider(
                                  DateTime(jour.year, jour.month))),
                          child: const Text('Réessayer'),
                        ),
                      ),
                    ],
                    data: (c) {
                      final menages = c.du(jour);
                      if (menages.isEmpty) {
                        return [
                          const _Bandeau(
                            icone: Icons.event_busy_rounded,
                            couleur: AppColors.grisDark,
                            fond: Colors.white,
                            texte: 'Aucun ménage prévu à cette date.',
                          ),
                        ];
                      }
                      return [
                        for (final (i, m) in menages.indexed) ...[
                          if (i > 0) const SizedBox(height: AppSizes.lg),
                          _DetailMenage(menage: m, frequence: c.frequence),
                        ],
                      ];
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMenage extends ConsumerStatefulWidget {
  final JourMenage menage;
  final String frequence;
  const _DetailMenage({required this.menage, required this.frequence});

  @override
  ConsumerState<_DetailMenage> createState() => _DetailMenageState();
}

class _DetailMenageState extends ConsumerState<_DetailMenage> {
  bool _envoi = false;

  Future<void> _demanderReprise() async {
    final m = widget.menage;
    setState(() => _envoi = true);
    final ok =
        await ref.read(residentEspaceNotifierProvider.notifier).creerDemande(
              type: TypeDemande.reprogrammer,
              tacheJourId: m.tacheJourId,
              motif: 'Je souhaite reprendre le ménage du '
                  '${dateLongue(m.date).toLowerCase()} (${m.periodeCourte}), '
                  'qui a été annulé.',
            );
    if (!mounted) return;
    setState(() => _envoi = false);
    ok
        ? NotificationApp.succes(
            context,
            'Demande envoyée. Le responsable vous confirmera une nouvelle '
            'date.',
            libelleAction: 'Mes demandes',
            onAction: () => context.go(AppRoutes.residentDemandes),
          )
        : NotificationApp.erreur(
            context, 'La demande n’a pas pu être envoyée. Réessayez.');
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.menage;
    final s = m.statut;
    final appartement = ref.watch(employeeCourantProvider)?.nomResidence;
    final demandes =
        ref.watch(residentEspaceNotifierProvider.select((st) => st.demandes));
    // Une reprise déjà demandée pour ce ménage, et pas encore réglée.
    final repriseEnCours = m.tacheJourId != null &&
        demandes.any((d) =>
            d.type == TypeDemande.reprogrammer &&
            d.tacheJourId == m.tacheJourId &&
            !d.resolue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Carte du statut ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: s.fond,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: s.couleur.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: s == StatutMenageResident.prevu
                      ? Colors.transparent
                      : s.couleur,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  s.icone,
                  size: s == StatutMenageResident.prevu ? 46 : 30,
                  color: s == StatutMenageResident.prevu
                      ? s.couleur
                      : s == StatutMenageResident.absent ||
                              s == StatutMenageResident.autre
                          ? AppColors.noir
                          : Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.titre,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: s == StatutMenageResident.autre ||
                                s == StatutMenageResident.absent
                            ? AppColors.noir
                            : s.couleur,
                      ),
                    ),
                    if (m.precision != null)
                      Text(
                        m.precision!,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.noir),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      dateLongue(m.date),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.noir,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.periodeCourte,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.noir,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),

        // ── Informations de base (ni heure ni durée) ─────────
        if (s != StatutMenageResident.annule)
          CarteContenu(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                if (appartement != null && appartement.isNotEmpty)
                  _Info(
                    icone: Icons.home_rounded,
                    texte: 'Appartement : $appartement',
                  ),
                if (m.preposee != null)
                  _Info(
                    icone: Icons.hourglass_bottom_rounded,
                    texte: 'Préposée : ${m.preposee}',
                  ),
                _Info(
                  icone: Icons.sync_rounded,
                  texte: 'Fréquence : ${widget.frequence}',
                ),
              ],
            ),
          ),
        if (s != StatutMenageResident.annule)
          const SizedBox(height: AppSizes.md),

        // ── Explication ──────────────────────────────────────
        _Bandeau(
          icone: s == StatutMenageResident.annule
              ? Icons.cancel_outlined
              : Icons.info_rounded,
          couleur: s == StatutMenageResident.annule
              ? AppColors.nonAutorise
              : const Color(0xFF1E6FD9),
          fond: s == StatutMenageResident.annule
              ? s.fond
              : const Color(0xFFEFF5FD),
          texte: m.explication,
          sansIcone: s == StatutMenageResident.annule,
        ),

        // ── Reprise d'un ménage annulé ───────────────────────
        if (s == StatutMenageResident.annule) ...[
          const SizedBox(height: AppSizes.md),
          if (repriseEnCours)
            const _Bandeau(
              icone: Icons.hourglass_top_rounded,
              couleur: AppColors.fait,
              fond: AppColors.faitBg,
              texte: 'Votre demande de reprise a été envoyée. Le responsable '
                  'vous confirmera une nouvelle date.',
            )
          else ...[
            FilledButton(
              onPressed:
                  _envoi || m.tacheJourId == null ? null : _demanderReprise,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rouge,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                children: [
                  _envoi
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 26),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Demander la reprise',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.md),
            const _Bandeau(
              icone: Icons.info_rounded,
              couleur: Color(0xFF1E6FD9),
              fond: Color(0xFFEFF5FD),
              texte: 'Votre demande sera envoyée au responsable, qui vous '
                  'confirmera une nouvelle date.',
            ),
          ],
        ],
      ],
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icone;
  final String texte;
  const _Info({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icone, size: 24, color: AppColors.grisDark),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(fontSize: 15, color: AppColors.noir),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bandeau extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final Color fond;
  final String texte;
  final Widget? action;
  final bool sansIcone;

  const _Bandeau({
    required this.icone,
    required this.couleur,
    required this.fond,
    required this.texte,
    this.action,
    this.sansIcone = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(12),
        border: fond == Colors.white
            ? Border.all(color: AppColors.grisMedium)
            : null,
      ),
      child: Row(
        children: [
          if (!sansIcone) ...[
            Icon(icone, color: couleur, size: 28),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(
                  fontSize: 14, height: 1.45, color: AppColors.noir),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
