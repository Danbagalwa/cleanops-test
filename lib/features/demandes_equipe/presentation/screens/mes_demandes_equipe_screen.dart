import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reception/presentation/reception_sections.dart';
import '../../domain/entities/demande_equipe.dart';
import '../providers/demande_equipe_provider.dart';
import '../widgets/demande_equipe_elements.dart';
import '../widgets/nouvelle_demande_equipe_sheet.dart';
import '../widgets/piece_jointe_demande.dart';

enum _StatutFiltre { tous, enAttente, resolues }

class MesDemandesEquipeScreen extends ConsumerStatefulWidget {
  const MesDemandesEquipeScreen({super.key});

  @override
  ConsumerState<MesDemandesEquipeScreen> createState() =>
      _MesDemandesEquipeScreenState();
}

class _MesDemandesEquipeScreenState
    extends ConsumerState<MesDemandesEquipeScreen> {
  _StatutFiltre _filtre = _StatutFiltre.tous;
  String _recherche = '';

  /// Un avertissement (document non joint) a déjà été affiché pendant
  /// l'envoi : on ne le recouvre pas par un message de réussite.
  bool _avertissementAffiche = false;

  List<DemandeEquipe> _filtrer(List<DemandeEquipe> demandes) {
    final q = _recherche.trim().toLowerCase();
    return demandes.where((d) {
      final statutOk = switch (_filtre) {
        _StatutFiltre.tous => true,
        _StatutFiltre.enAttente => d.enAttente,
        _StatutFiltre.resolues => d.resolue,
      };
      return statutOk &&
          (q.isEmpty ||
              d.motif.toLowerCase().contains(q) ||
              d.type.libelle.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _ouvrirNouvelleDemande() async {
    _avertissementAffiche = false;
    final envoyee = await showNouvelleDemandeEquipeModal(context);
    if (envoyee == true && mounted && !_avertissementAffiche) {
      NotificationApp.succes(
        context,
        'Votre demande a été envoyée. Vous serez informé(e) de la réponse.',
      );
    }
  }

  Future<void> _charger() =>
      ref.read(mesDemandesEquipeNotifierProvider.notifier).charger();

  @override
  Widget build(BuildContext context) {
    ref.listen(mesDemandesEquipeNotifierProvider, (previous, next) {
      final avertissement = next.avertissement;
      if (avertissement != null && avertissement != previous?.avertissement) {
        _avertissementAffiche = true;
        NotificationApp.avertissement(context, avertissement);
        ref
            .read(mesDemandesEquipeNotifierProvider.notifier)
            .viderAvertissement();
      }
    });
    final state = ref.watch(mesDemandesEquipeNotifierProvider);
    final employee = ref.watch(employeeCourantProvider);
    final filtrees = _filtrer(state.demandes);
    final fallback = switch (employee) {
      Employee(isResponsable: true) => AppRoutes.employerDashboard,
      Employee(isReception: true) => receptionAccueilRoute,
      _ => AppRoutes.employeeDashboard,
    };
    final compact = estCompact(context);
    final marge = compact ? 12.0 : 24.0;
    final enAttente = state.demandes.where((d) => d.enAttente).length;

    FiltreSection filtre(_StatutFiltre f, IconData icone, String info) =>
        FiltreSection(
          icone: icone,
          infoBulle: info,
          actif: _filtre == f,
          onTap: () => setState(() => _filtre = f),
        );

    final nouvelle = FilledButton.icon(
      onPressed: state.isSending ? null : _ouvrirNouvelleDemande,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.rouge,
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      icon: const Icon(Icons.add_rounded, size: 19),
      label: Text(compact ? 'Nouvelle' : 'Nouvelle demande'),
    );
    final recherche = ChampRecherche(
      indice: 'Rechercher dans mes demandes',
      onChanged: (v) => setState(() => _recherche = v),
    );

    Widget corps;
    if (state.isLoading && state.demandes.isEmpty) {
      corps = const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.rouge)),
      );
    } else if (state.error != null && state.demandes.isEmpty) {
      corps = CarteContenu(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: AppErrorNotice(error: state.error!, onRetry: _charger),
      );
    } else if (state.demandes.isEmpty) {
      corps = _EmptyState(onNouvelleDemande: _ouvrirNouvelleDemande);
    } else if (filtrees.isEmpty) {
      corps = const CarteContenu(
        padding: EdgeInsets.all(AppSizes.xl),
        child: Text(
          'Aucune demande ne correspond à ce filtre.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.grisDark),
        ),
      );
    } else {
      corps = LayoutBuilder(builder: (context, c) {
        const ecart = AppSizes.sm;
        final colonnes = math.max(1, (c.maxWidth + ecart) ~/ (360 + ecart));
        final largeur = (c.maxWidth - ecart * (colonnes - 1)) / colonnes;
        return Wrap(
          spacing: ecart,
          runSpacing: ecart,
          children: [
            for (final d in filtrees)
              SizedBox(width: largeur, child: _DemandeCard(demande: d)),
          ],
        );
      });
    }

    return PageAvecEnTete(
      chargement: state.isLoading && state.demandes.isNotEmpty,
      enTete: EnTetePage(
        icone: Icons.event_note_rounded,
        titre: 'Mes demandes',
        sousTitre: enAttente == 0
            ? 'Congés, absences planifiées et autres demandes à la direction'
            : 'Congés, absences planifiées et autres demandes — '
                '$enAttente en attente de réponse',
      ),
      contenu: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _charger,
        child: ListView(
          padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
              .plusBarre(context),
          children: [
            BarreSection(
              titre: 'Mes demandes (${filtrees.length})',
              onRetour: () => context.backOrHome(fallback),
              filtres: [
                filtre(_StatutFiltre.tous, Icons.list_alt_rounded,
                    'Toutes mes demandes'),
                filtre(_StatutFiltre.enAttente, Icons.hourglass_top_rounded,
                    'En attente'),
                filtre(
                    _StatutFiltre.resolues, Icons.task_alt_rounded, 'Traitées'),
              ],
              actions: [
                ActionSection(
                  icone: Icons.refresh_rounded,
                  infoBulle: 'Actualiser',
                  onPressed: state.isLoading ? null : _charger,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: recherche,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                nouvelle,
              ],
            ),
            const SizedBox(height: AppSizes.md),
            corps,
          ],
        ),
      ),
    );
  }
}

// ── Carte demande ──────────────────────────────────────────

class _DemandeCard extends StatelessWidget {
  final DemandeEquipe demande;
  const _DemandeCard({required this.demande});

  @override
  Widget build(BuildContext context) {
    final d = demande;
    final periode = periodeDemande(d);
    final jours = joursDemande(d);
    final couleurType = couleurTypeDemande(d.type);

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: d.enAttente
              ? AppColors.aVerifier.withValues(alpha: 0.6)
              : AppColors.grisMedium,
          width: d.enAttente ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: couleurType.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconeTypeDemande(d.type),
                    size: 18, color: couleurType),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.type.libelle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AppColors.noir,
                      ),
                    ),
                    Text(
                      'Envoyée le ${dateEnvoiDemande(d)}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.grisText),
                    ),
                  ],
                ),
              ),
              BadgeStatutDemande(demande: d),
            ],
          ),
          if (periode != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.event_rounded,
                    size: 15, color: AppColors.grisText),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    jours != null && jours > 1
                        ? '$periode · $jours jours'
                        : periode,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.grisDark),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            d.motif,
            style: const TextStyle(
                fontSize: 13, height: 1.35, color: AppColors.noir),
          ),
          if (d.aDocument) ...[
            const SizedBox(height: 8),
            PieceJointeDemande(demande: d),
          ],
          if (d.resolue) ...[
            const SizedBox(height: 10),
            NoteResponsableDemande(demande: d),
          ],
          if (d.aPreuve) ...[
            const SizedBox(height: 8),
            PieceJointeDemande(demande: d, preuve: true),
          ],
        ],
      ),
    );
  }
}

// ── État vide ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onNouvelleDemande;
  const _EmptyState({required this.onNouvelleDemande});

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.lg),
            decoration: BoxDecoration(
              color: AppColors.rouge.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_note_rounded,
                size: 44, color: AppColors.rouge),
          ),
          const SizedBox(height: AppSizes.md),
          const Text(
            'Aucune demande',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.noir),
          ),
          const SizedBox(height: AppSizes.xs),
          const Text(
            'Demandez un congé, signalez une absence planifiée ou écrivez '
            'une autre demande à la direction.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisText, fontSize: 13),
          ),
          const SizedBox(height: AppSizes.lg),
          FilledButton.icon(
            onPressed: onNouvelleDemande,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rouge,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nouvelle demande'),
          ),
        ],
      ),
    );
  }
}
