import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/dashboard_welcome_header.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../../domain/entities/tache_resident.dart';
import '../providers/resident_espace_provider.dart';
import '../widgets/nouvelle_demande_sheet.dart';
import '../widgets/statut_menage_visuel.dart';

/// Accueil du résident : l'essentiel d'un coup d'œil — prochain ménage,
/// dernier ménage effectué, accès au calendrier et aux demandes.
class ResidentAccueilScreen extends ConsumerWidget {
  const ResidentAccueilScreen({super.key});

  Future<void> _faireDemande(BuildContext context, WidgetRef ref) async {
    final taches = ref.read(residentEspaceNotifierProvider).tachesNonFaites;
    final envoye =
        await showNouvelleDemandeModal(context, tachesDisponibles: taches);
    if (envoye == true && context.mounted) {
      context.go(AppRoutes.residentDemandes);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(employeeCourantProvider);
    final state = ref.watch(residentEspaceNotifierProvider);
    final notifier = ref.read(residentEspaceNotifierProvider.notifier);
    final marge = estCompact(context) ? AppSizes.md : AppSizes.lg;

    final prochain = state.menageAujourdhui ?? state.prochaines.firstOrNull;
    final dernier = state.dernierMenage;
    final chargement = state.isLoadingTaches && state.taches.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      body: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: notifier.charger,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(marge).plusBarre(context),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DashboardWelcomeHeader(employee: employee),
                    const SizedBox(height: AppSizes.md),

                    // ── Nouvelles réponses ─────────────────────────
                    if (state.nombreNotificationsNonLues > 0) ...[
                      _BandeauNotifications(
                        nombre: state.nombreNotificationsNonLues,
                        message: state.notificationsNonLues.first.message,
                        onTap: () async {
                          await notifier.toutMarquerLu();
                          if (context.mounted) {
                            context.go(AppRoutes.residentDemandes);
                          }
                        },
                      ),
                      const SizedBox(height: AppSizes.md),
                    ],

                    // ── Prochain ménage ────────────────────────────
                    if (chargement)
                      const _CarteChargement()
                    else if (state.errorTaches != null && state.taches.isEmpty)
                      _CarteLien(
                        icone: Icons.wifi_off_rounded,
                        couleurIcone: AppColors.grisDark,
                        titre: 'Vos ménages n’ont pas pu être chargés',
                        sousTitre: 'Touchez pour réessayer.',
                        onTap: notifier.chargerTaches,
                      )
                    else if (prochain != null)
                      _CarteMenage(
                        tache: prochain,
                        titre: prochain.estAujourdhui
                            ? 'Ménage aujourd’hui'
                            : 'Prochain ménage',
                        fond: AppColors.faitBg,
                        couleur: AppColors.fait,
                        icone: Icons.calendar_month_rounded,
                        iconeRonde: false,
                      )
                    else
                      const _CarteLien(
                        icone: Icons.event_busy_rounded,
                        couleurIcone: AppColors.grisDark,
                        titre: 'Aucun ménage prévu pour le moment',
                        sousTitre:
                            'Vous serez informé dès qu’une date est confirmée.',
                      ),
                    const SizedBox(height: AppSizes.md),

                    // ── Dernier ménage effectué ───────────────────
                    if (dernier != null) ...[
                      _CarteMenage(
                        tache: dernier,
                        titre: 'Dernier ménage effectué',
                        fond: Colors.white,
                        couleur: AppColors.fait,
                        icone: Icons.check_rounded,
                        iconeRonde: true,
                        titreBleu: true,
                      ),
                      const SizedBox(height: AppSizes.md),
                    ],

                    // ── Calendrier ────────────────────────────────
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.residentCalendrier),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rouge,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 28),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Voir mon calendrier',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),

                    // ── Demande ───────────────────────────────────
                    _CarteLien(
                      icone: Icons.description_rounded,
                      couleurIcone: AppColors.rouge,
                      titre: 'Faire une demande',
                      sousTitre: 'Annulation, reprise, information…',
                      onTap: () => _faireDemande(context, ref),
                    ),
                    const SizedBox(height: AppSizes.md),

                    // ── Réception ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF5FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_rounded,
                              color: Color(0xFF1E6FD9), size: 28),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Pour toute question, communiquez avec la '
                              'réception.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: AppColors.noir,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte d'un ménage (prochain, dernier) ─────────────────

class _CarteMenage extends StatelessWidget {
  final TacheResident tache;
  final String titre;
  final Color fond;
  final Color couleur;
  final IconData icone;

  /// Icône blanche dans un rond plein (dernier ménage) plutôt que colorée.
  final bool iconeRonde;

  /// Titre en bleu de l'app (dernier ménage) plutôt que dans [couleur].
  final bool titreBleu;

  const _CarteMenage({
    required this.tache,
    required this.titre,
    required this.fond,
    required this.couleur,
    required this.icone,
    required this.iconeRonde,
    this.titreBleu = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fond,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: fond == Colors.white
              ? AppColors.grisMedium
              : couleur.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(AppRoutes.residentMenage(tache.dateReelle)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: iconeRonde ? couleur : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icone,
                  size: iconeRonde ? 32 : 50,
                  color: iconeRonde ? Colors.white : couleur,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: titreBleu ? AppColors.rouge : couleur,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateLongue(tache.dateReelle),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.noir,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tache.periode == PeriodeType.am ? 'AM' : 'PM',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.noir,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.noir, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Carte simple avec lien ────────────────────────────────

class _CarteLien extends StatelessWidget {
  final IconData icone;
  final Color couleurIcone;
  final String titre;
  final String sousTitre;
  final VoidCallback? onTap;

  const _CarteLien({
    required this.icone,
    required this.couleurIcone,
    required this.titre,
    required this.sousTitre,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.grisMedium),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icone, size: 38, color: couleurIcone),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.noir,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sousTitre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.grisDark),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.noir, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarteChargement extends StatelessWidget {
  const _CarteChargement();

  @override
  Widget build(BuildContext context) {
    return const CarteContenu(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.rouge),
      ),
    );
  }
}

// ── Nouvelles réponses non lues ───────────────────────────

class _BandeauNotifications extends StatelessWidget {
  final int nombre;
  final String message;
  final VoidCallback onTap;

  const _BandeauNotifications({
    required this.nombre,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.rouge.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.rouge.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Badge(
                label: Text('$nombre'),
                backgroundColor: AppColors.rouge,
                child: const Icon(Icons.notifications_rounded,
                    color: AppColors.rouge),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.rouge,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.rouge),
            ],
          ),
        ),
      ),
    );
  }
}
