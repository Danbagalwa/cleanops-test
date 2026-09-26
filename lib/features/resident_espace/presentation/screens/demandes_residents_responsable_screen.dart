import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/dialogue_app.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/export_menu_button.dart'
    show showExportSuccess;
import '../../../../core/widgets/mise_en_page.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../../appartements/presentation/widgets/appartement_list_item.dart'
    show comparerNumeros;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../messages_reception_responsable/presentation/providers/messages_reception_responsable_provider.dart';
import '../../../messages_reception_responsable/presentation/widgets/messages_reception_section.dart';
import '../../../pdf/domain/usecases/generate_demandes_residents_export.dart';
import '../../../pdf/presentation/screens/demandes_residents_pdf_preview_screen.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';
import '../../domain/entities/demande_resident.dart';
import '../providers/demandes_responsable_provider.dart';
import '../widgets/demande_resident_elements.dart';

enum _Statut { toutes, aTraiter, attenteResident, resolues }

enum _Tri { priorite, envoi, resident, appartement, etat }

/// Les deux listes de l'écran : les demandes venues du portail des résidents et
/// les messages que la Réception transmet au responsable.
enum _Onglet { demandes, messages }

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
  _Statut _statut = _Statut.toutes;
  TypeDemande? _type;
  String _recherche = '';
  _Tri _tri = _Tri.priorite;
  bool _croissant = false;
  int _page = 0;
  int _parPage = 10;

  /// `null` : choisi selon la largeur (grille sur téléphone, tableau sinon).
  ModeAffichage? _mode;

  DemandesResponsableNotifier get _notifier =>
      ref.read(demandesResponsableProvider.notifier);

  Future<void> _charger() => _notifier.charger();

  void _changer(VoidCallback maj) => setState(() {
        maj();
        _page = 0;
      });

  void _trier(_Tri tri) => _changer(() {
        _croissant = _tri == tri
            ? !_croissant
            : (tri == _Tri.resident || tri == _Tri.appartement);
        _tri = tri;
      });

  bool _duStatut(DemandeResident d) => switch (_statut) {
        _Statut.toutes => true,
        _Statut.aTraiter => aTraiterDemande(d),
        _Statut.attenteResident => d.attendsReponseResident,
        _Statut.resolues => d.resolue,
      };

  /// Rang de l'état pour le tri : ce qui attend le responsable d'abord.
  static int _rangEtat(DemandeResident d) => d.enAttente
      ? 0
      : refuseeParResident(d)
          ? 1
          : d.repondue
              ? 2
              : 3;

  List<DemandeResident> _lignes(List<DemandeResident> toutes) {
    final q = _recherche.trim().toLowerCase();
    int parEnvoi(DemandeResident a, DemandeResident b) =>
        a.createdAt.compareTo(b.createdAt);
    int sens(int c) => _croissant ? c : -c;
    return toutes.where((d) {
      if (!_duStatut(d)) return false;
      if (_type != null && d.type != _type) return false;
      if (q.isEmpty) return true;
      return nomResidentDemande(d).toLowerCase().contains(q) ||
          (d.numeroAppartement?.toLowerCase().contains(q) ?? false) ||
          d.motif.toLowerCase().contains(q) ||
          (d.reponse?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) => switch (_tri) {
            // À traiter d'abord (urgentes en tête), puis les plus récentes.
            _Tri.priorite => aTraiterDemande(a) != aTraiterDemande(b)
                ? (aTraiterDemande(a) ? -1 : 1)
                : a.estUrgente != b.estUrgente
                    ? (a.estUrgente ? -1 : 1)
                    : -parEnvoi(a, b),
            _Tri.envoi => sens(parEnvoi(a, b)),
            _Tri.resident => sens(nomResidentDemande(a)
                .toLowerCase()
                .compareTo(nomResidentDemande(b).toLowerCase())),
            _Tri.appartement => sens(comparerNumeros(
                a.numeroAppartement ?? '', b.numeroAppartement ?? '')),
            _Tri.etat => sens(_rangEtat(a).compareTo(_rangEtat(b))),
          });
  }

  String _descriptionFiltres() {
    final f = <String>[
      if (_statut == _Statut.aTraiter) 'À traiter',
      if (_statut == _Statut.attenteResident) 'Attendent le résident',
      if (_statut == _Statut.resolues) 'Résolues',
      if (_type != null) libelleTypeDemandeResident(_type!),
      if (_recherche.trim().isNotEmpty) '« ${_recherche.trim()} »',
    ];
    return f.isEmpty ? 'Toutes les demandes' : f.join(' · ');
  }

  // ── Actions ────────────────────────────────────────────

  void _ouvrirDetail(DemandeResident d) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _DetailDemande(
        demande: d,
        onAgir: (action) {
          Navigator.of(ctx).pop();
          _agir(d, action);
        },
      ),
    );
  }

  Future<void> _agir(DemandeResident d, _Action action) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => switch (action) {
        _Action.repondre => _RepondreDialog(demande: d),
        _Action.validerInfo => _ValiderInfoDialog(demande: d),
        _Action.refuserInfo => _RefuserInfoDialog(demande: d),
      },
    );
    if (message != null && mounted) NotificationApp.succes(context, message);
  }

  void _exporterPdf(List<DemandeResident> lignes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DemandesResidentsPdfPreviewScreen(
          demandes: lignes,
          filtres: _descriptionFiltres(),
          generatedBy:
              ref.read(employeeCourantProvider)?.nomComplet ?? 'CleanOps',
        ),
      ),
    );
  }

  void _exporterExcel(List<DemandeResident> lignes) {
    try {
      const GenerateDemandesResidentsExcel()(
        demandes: lignes,
        filtres: _descriptionFiltres(),
      );
      showExportSuccess(
          context, 'Le suivi Excel des demandes a été téléchargé.');
    } catch (error) {
      AppFeedback.showError(context, error);
    }
  }

  // ── Construction ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demandesResponsableProvider);
    final aTraiter = state.demandes.where(aTraiterDemande).length;
    final messagesEnAttente = ref.watch(messagesReceptionEnAttenteProvider);
    final marge = estCompact(context) ? 12.0 : 24.0;

    final sousTitre = [
      aTraiter == 0
          ? 'Aucune demande à traiter'
          : '$aTraiter demande${aTraiter > 1 ? 's' : ''} à traiter',
      if (messagesEnAttente > 0)
        '$messagesEnAttente message${messagesEnAttente > 1 ? 's' : ''} '
            'de la réception',
    ].join(' · ');

    return PageAvecEnTete(
      chargement: _onglet == _Onglet.demandes && state.isLoading,
      enTete: EnTetePage(
        icone: Icons.forum_rounded,
        titre: 'Demandes résidents',
        sousTitre: sousTitre,
      ),
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Onglets(
            onglet: _onglet,
            marge: marge,
            aTraiter: aTraiter,
            messages: messagesEnAttente,
            onChanged: (o) => setState(() => _onglet = o),
          ),
          Expanded(
            child: _onglet == _Onglet.messages
                ? const MessagesReceptionSection()
                : _contenuDemandes(state, marge),
          ),
        ],
      ),
    );
  }

  Widget _contenuDemandes(DemandesResponsableState state, double marge) {
    final compact = estCompact(context);
    final mode =
        compact ? ModeAffichage.grille : (_mode ?? ModeAffichage.tableau);
    final toutes = state.demandes;
    final lignes = _lignes(toutes);
    final nbPages = lignes.isEmpty ? 1 : ((lignes.length - 1) ~/ _parPage) + 1;
    final page = _page.clamp(0, nbPages - 1);
    final visibles = lignes.skip(page * _parPage).take(_parPage).toList();
    final aTraiter = toutes.where(aTraiterDemande).length;

    FiltreSection filtre(_Statut s, IconData icone, String info,
            {bool pastille = false}) =>
        FiltreSection(
          icone: icone,
          infoBulle: info,
          actif: _statut == s,
          pastille: pastille,
          onTap: () => _changer(() => _statut = s),
        );

    final recherche = ChampRecherche(
      indice: 'Rechercher un résident, un appartement ou un motif',
      onChanged: (v) => _changer(() => _recherche = v),
    );

    Widget corps;
    if (state.isLoading && toutes.isEmpty) {
      corps = const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.rouge)),
      );
    } else if (state.error != null && toutes.isEmpty) {
      corps = CarteContenu(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: AppErrorNotice(error: state.error!, onRetry: _charger),
      );
    } else if (toutes.isEmpty) {
      corps = const _EtatVide(
        titre: 'Aucune demande de résident',
        texte: 'Les reprogrammations, annulations, commentaires et infos '
            'd’appartement envoyés depuis l’espace résident apparaîtront ici.',
      );
    } else if (lignes.isEmpty) {
      corps = _EtatVide(
        titre: _statut == _Statut.aTraiter
            ? 'Rien à traiter'
            : 'Aucune demande ne correspond',
        texte: _statut == _Statut.aTraiter
            ? 'Toutes les demandes ont reçu une réponse.'
            : 'Modifiez les filtres ou la recherche.',
        onReinitialiser: _statut == _Statut.aTraiter
            ? null
            : () => _changer(() {
                  _statut = _Statut.toutes;
                  _type = null;
                }),
      );
    } else {
      corps = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == ModeAffichage.tableau)
            _TableauDemandes(
              lignes: visibles,
              premierNumero: page * _parPage + 1,
              tri: _tri,
              croissant: _croissant,
              onTrier: _trier,
              onOuvrir: _ouvrirDetail,
              onAgir: _agir,
            )
          else
            _GrilleDemandes(
              lignes: visibles,
              onOuvrir: _ouvrirDetail,
              onAgir: _agir,
            ),
          const SizedBox(height: AppSizes.md),
          BarrePagination(
            page: page,
            parPage: _parPage,
            total: lignes.length,
            onPage: (p) => setState(() => _page = p),
            onParPage: (n) => _changer(() => _parPage = n),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.rouge,
      onRefresh: _charger,
      child: ListView(
        padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
            .plusBarre(context),
        children: [
          BarreSection(
            titre: 'Demandes (${lignes.length})',
            onRetour: () => context.backOrHome(AppRoutes.employerDashboard),
            filtres: [
              filtre(_Statut.toutes, Icons.list_alt_rounded,
                  'Toutes les demandes'),
              filtre(_Statut.aTraiter, Icons.hourglass_top_rounded,
                  'À traiter (en attente ou créneau refusé)',
                  pastille: aTraiter > 0),
              filtre(_Statut.attenteResident, Icons.schedule_rounded,
                  'Attendent la réponse du résident'),
              filtre(_Statut.resolues, Icons.task_alt_rounded, 'Résolues'),
            ],
            actions: [
              ActionSection(
                icone: Icons.print_rounded,
                infoBulle: 'Imprimer ou exporter en PDF',
                onPressed: lignes.isEmpty || state.isLoading
                    ? null
                    : () => _exporterPdf(lignes),
              ),
              ActionSection(
                icone: Icons.download_rounded,
                infoBulle: 'Télécharger en Excel',
                onPressed: lignes.isEmpty || state.isLoading
                    ? null
                    : () => _exporterExcel(lignes),
              ),
              ActionSection(
                icone: Icons.refresh_rounded,
                infoBulle: 'Actualiser',
                onPressed: state.isLoading ? null : _charger,
              ),
            ],
          ),
          if (toutes.isNotEmpty) ...[
            const SizedBox(height: AppSizes.md),
            _FiltreTypes(
              demandes: toutes.where(_duStatut).toList(),
              selection: _type,
              onChanged: (t) => _changer(() => _type = t),
            ),
            const SizedBox(height: AppSizes.md),
            if (compact)
              recherche
            else
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
                  const SizedBox(width: AppSizes.md),
                  BasculeAffichage(
                    mode: mode,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                ],
              ),
          ],
          const SizedBox(height: AppSizes.md),
          corps,
        ],
      ),
    );
  }
}

// ── Onglets : demandes des résidents / messages de la réception ──

class _Onglets extends StatelessWidget {
  final _Onglet onglet;
  final double marge;
  final int aTraiter;
  final int messages;
  final ValueChanged<_Onglet> onChanged;

  const _Onglets({
    required this.onglet,
    required this.marge,
    required this.aTraiter,
    required this.messages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.grisMedium)),
      ),
      padding: EdgeInsets.symmetric(horizontal: marge),
      child: Row(
        children: [
          _Onglet1(
            icone: Icons.forum_outlined,
            libelle: 'Demandes des résidents',
            compteur: aTraiter,
            actif: onglet == _Onglet.demandes,
            onTap: () => onChanged(_Onglet.demandes),
          ),
          const SizedBox(width: AppSizes.md),
          _Onglet1(
            icone: Icons.support_agent_rounded,
            libelle: 'Messages de la réception',
            compteur: messages,
            actif: onglet == _Onglet.messages,
            onTap: () => onChanged(_Onglet.messages),
          ),
        ],
      ),
    );
  }
}

class _Onglet1 extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final int compteur;
  final bool actif;
  final VoidCallback onTap;

  const _Onglet1({
    required this.icone,
    required this.libelle,
    required this.compteur,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? AppColors.rouge : AppColors.grisDark;
    return Flexible(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: actif ? AppColors.rouge : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!estCompact(context)) ...[
                Icon(icone, size: 18, color: couleur),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  libelle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                    color: couleur,
                  ),
                ),
              ),
              if (compteur > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: actif ? AppColors.rouge : AppColors.grisDark,
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

// ── Filtre par type (avec effectifs) ───────────────────────

class _FiltreTypes extends StatelessWidget {
  final List<DemandeResident> demandes;
  final TypeDemande? selection;
  final ValueChanged<TypeDemande?> onChanged;

  const _FiltreTypes({
    required this.demandes,
    required this.selection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    _TuileType tuile(TypeDemande? t) {
      final dans =
          t == null ? demandes : demandes.where((d) => d.type == t).toList();
      return _TuileType(
        icone: t == null ? Icons.apps_rounded : iconeTypeDemandeResident(t),
        couleur: t == null ? AppColors.rouge : couleurTypeDemandeResident(t),
        libelle: t == null ? 'Tous les types' : libelleTypeDemandeResident(t),
        nombre: dans.length,
        aTraiter: dans.where(aTraiterDemande).length,
        actif: selection == t,
        onTap: () => onChanged(selection == t ? null : t),
      );
    }

    final tuiles = [tuile(null), for (final t in TypeDemande.values) tuile(t)];

    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      const minimum = 170.0;
      final tiennent =
          c.maxWidth >= tuiles.length * minimum + ecart * (tuiles.length - 1);
      if (tiennent) {
        return Row(
          children: [
            for (final (i, t) in tuiles.indexed) ...[
              if (i > 0) const SizedBox(width: ecart),
              Expanded(child: t),
            ],
          ],
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, t) in tuiles.indexed) ...[
              if (i > 0) const SizedBox(width: ecart),
              SizedBox(width: minimum, child: t),
            ],
          ],
        ),
      );
    });
  }
}

class _TuileType extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String libelle;
  final int nombre;
  final int aTraiter;
  final bool actif;
  final VoidCallback onTap;

  const _TuileType({
    required this.icone,
    required this.couleur,
    required this.libelle,
    required this.nombre,
    required this.aTraiter,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: actif ? AppColors.rouge.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: actif ? AppColors.rouge : AppColors.grisMedium,
          width: actif ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, size: 17, color: couleur),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$nombre',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.noir,
                            height: 1.1,
                          ),
                        ),
                        if (aTraiter > 0) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.aVerifier.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$aTraiter à traiter',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.aVerifier,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      libelle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                        color: actif ? AppColors.rouge : AppColors.grisDark,
                      ),
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

// ── Éléments communs ───────────────────────────────────────

/// Ce que le responsable peut faire d'une demande à traiter.
enum _Action { repondre, validerInfo, refuserInfo }

class _Resident extends StatelessWidget {
  final DemandeResident demande;
  final double rayon;

  /// Affiche l'appartement sous le nom.
  final bool avecAppartement;

  const _Resident(this.demande, {this.rayon = 15, this.avecAppartement = true});

  @override
  Widget build(BuildContext context) {
    final nom = nomResidentDemande(demande);
    final apt = appartementDemande(demande);
    final initiales = nom
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Row(
      children: [
        AvatarProfil(
          proprietaire: ProprietairePhoto(
              TypeProprietairePhoto.resident, demande.residentId),
          initiales: initiales.isEmpty ? '?' : initiales,
          rayon: rayon,
          couleurFond: AppColors.rouge.withValues(alpha: 0.12),
          couleurTexte: AppColors.rouge,
          tailleTexte: rayon * 0.7,
          poidsTexte: FontWeight.bold,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: rayon > 16 ? 14.5 : 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.noir,
                ),
              ),
              if (avecAppartement && apt != null)
                Text(
                  demande.tailleAppartement == null
                      ? apt
                      : '$apt · ${demande.tailleAppartement}',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.grisDark),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Boutons d'action d'une demande à traiter.
class _BoutonsAction extends StatelessWidget {
  final DemandeResident demande;
  final ValueChanged<_Action> onAgir;
  final bool compacts;

  const _BoutonsAction({
    required this.demande,
    required this.onAgir,
    this.compacts = false,
  });

  @override
  Widget build(BuildContext context) {
    final info = demande.type == TypeDemande.infoAppartement;
    final libelleRepondre =
        refuseeParResident(demande) ? 'Nouvelle proposition' : 'Répondre';

    if (compacts) {
      if (info) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Refuser',
              onPressed: () => onAgir(_Action.refuserInfo),
              icon: const Icon(Icons.close_rounded, color: AppColors.refus),
            ),
            IconButton(
              tooltip: 'Valider et appliquer',
              onPressed: () => onAgir(_Action.validerInfo),
              icon: const Icon(Icons.check_rounded, color: AppColors.fait),
            ),
          ],
        );
      }
      return IconButton(
        tooltip: libelleRepondre,
        onPressed: () => onAgir(_Action.repondre),
        icon: const Icon(Icons.reply_rounded, color: AppColors.rouge),
      );
    }

    const forme = StadiumBorder();
    if (info) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => onAgir(_Action.refuserInfo),
              icon: const Icon(Icons.close_rounded, size: 17),
              label: const Text('Refuser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.refus,
                side: const BorderSide(color: AppColors.refus),
                shape: forme,
                minimumSize: const Size(0, 42),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => onAgir(_Action.validerInfo),
              icon: const Icon(Icons.check_rounded, size: 17),
              label: const Text('Valider'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.fait,
                shape: forme,
                minimumSize: const Size(0, 42),
              ),
            ),
          ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => onAgir(_Action.repondre),
        icon: const Icon(Icons.reply_rounded, size: 17),
        label: Text(libelleRepondre),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.rouge,
          shape: forme,
          minimumSize: const Size(0, 42),
        ),
      ),
    );
  }
}

/// Proposition d'infos appartement faite par le résident (animal, notes).
class _PropositionInfo extends StatelessWidget {
  final DemandeResident demande;
  const _PropositionInfo({required this.demande});

  @override
  Widget build(BuildContext context) {
    final d = demande;
    final animal = d.propositionHasAnimal;
    final notes = d.propositionNotes?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.aVerifier.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.aVerifier.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proposé par le résident',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.grisDark),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(animal == true ? Icons.pets_rounded : Icons.block_rounded,
                  size: 15,
                  color: animal == true
                      ? AppColors.aVerifier
                      : AppColors.grisText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  animal == true
                      ? ((d.propositionTypeAnimal?.isNotEmpty ?? false)
                          ? 'Animal : ${d.propositionTypeAnimal}'
                          : 'Animal présent')
                      : 'Pas d’animal',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.noir),
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded,
                    size: 15, color: AppColors.grisDark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(notes,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.grisDark)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Réponse du responsable, créneau proposé et retour du résident.
class _BlocReponse extends StatelessWidget {
  final DemandeResident demande;
  const _BlocReponse({required this.demande});

  @override
  Widget build(BuildContext context) {
    final d = demande;
    final proposition = propositionDemande(d);
    final accepte = d.residentAccepte;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.rouge.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.reply_rounded, size: 15, color: AppColors.rouge),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  d.dateReponse == null
                      ? 'Votre réponse'
                      : 'Votre réponse · ${dateCourteDemande(d.dateReponse!)}',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.rouge),
                ),
              ),
            ],
          ),
          if (d.reponse?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(d.reponse!,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.35, color: AppColors.noir)),
          ],
          if (proposition != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.event_available_rounded,
                    size: 15, color: AppColors.grisDark),
                const SizedBox(width: 6),
                Text('Créneau proposé : $proposition',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grisDark)),
              ],
            ),
          ],
          // Accepté / refusé n'a de sens que pour un créneau proposé.
          if (accepte != null && proposition != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                    accepte ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 15,
                    color: accepte ? AppColors.fait : AppColors.refus),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    accepte
                        ? 'Le résident a accepté.'
                        : 'Le résident a refusé — nouvelle proposition requise.',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: accepte ? AppColors.fait : AppColors.refus),
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

class _Vide extends StatelessWidget {
  const _Vide();

  @override
  Widget build(BuildContext context) => const Text('—',
      style: TextStyle(fontSize: 13, color: AppColors.grisText));
}

// ── Tableau ────────────────────────────────────────────────

const _styleEnTete = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.grisDark,
);

class _TableauDemandes extends StatelessWidget {
  final List<DemandeResident> lignes;
  final int premierNumero;
  final _Tri tri;
  final bool croissant;
  final ValueChanged<_Tri> onTrier;
  final ValueChanged<DemandeResident> onOuvrir;
  final void Function(DemandeResident, _Action) onAgir;

  const _TableauDemandes({
    required this.lignes,
    required this.premierNumero,
    required this.tri,
    required this.croissant,
    required this.onTrier,
    required this.onOuvrir,
    required this.onAgir,
  });

  @override
  Widget build(BuildContext context) {
    Widget entete(String libelle, _Tri t) => _EnTeteTri(
          libelle: libelle,
          actif: tri == t,
          croissant: croissant,
          onTap: () => onTrier(t),
        );

    return CarteContenu(
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF7F8FA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                    width: 36, child: Text('N°', style: _styleEnTete)),
                Expanded(flex: 3, child: entete('Résident', _Tri.resident)),
                Expanded(flex: 1, child: entete('Apt', _Tri.appartement)),
                const Expanded(
                    flex: 2, child: Text('Type', style: _styleEnTete)),
                const Expanded(
                    flex: 2, child: Text('Ménage visé', style: _styleEnTete)),
                const Expanded(
                    flex: 4, child: Text('Motif', style: _styleEnTete)),
                Expanded(flex: 2, child: entete('Envoyée le', _Tri.envoi)),
                Expanded(flex: 2, child: entete('État', _Tri.etat)),
                const SizedBox(
                  width: 104,
                  child: Text('Actions',
                      textAlign: TextAlign.center, style: _styleEnTete),
                ),
              ],
            ),
          ),
          for (final (i, d) in lignes.indexed) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.grisMedium),
            _LigneDemande(
              demande: d,
              numero: premierNumero + i,
              onOuvrir: () => onOuvrir(d),
              onAgir: (a) => onAgir(d, a),
            ),
          ],
        ],
      ),
    );
  }
}

class _EnTeteTri extends StatelessWidget {
  final String libelle;
  final bool actif;
  final bool croissant;
  final VoidCallback onTap;

  const _EnTeteTri({
    required this.libelle,
    required this.actif,
    required this.croissant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? AppColors.rouge : AppColors.grisDark;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(libelle,
                    overflow: TextOverflow.ellipsis,
                    style: _styleEnTete.copyWith(color: couleur)),
              ),
              const SizedBox(width: 4),
              Icon(
                !actif
                    ? Icons.swap_vert_rounded
                    : croissant
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                size: 14,
                color: couleur,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LigneDemande extends StatelessWidget {
  final DemandeResident demande;
  final int numero;
  final VoidCallback onOuvrir;
  final ValueChanged<_Action> onAgir;

  const _LigneDemande({
    required this.demande,
    required this.numero,
    required this.onOuvrir,
    required this.onAgir,
  });

  @override
  Widget build(BuildContext context) {
    final d = demande;
    const style = TextStyle(fontSize: 13, color: AppColors.grisDark);
    final menage = menageDemande(d);
    final aTraiter = aTraiterDemande(d);
    return Material(
      color: aTraiter
          ? AppColors.aVerifier.withValues(alpha: 0.04)
          : Colors.transparent,
      child: InkWell(
        onTap: onOuvrir,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                  width: 36,
                  child: Text('$numero',
                      style: style.copyWith(color: AppColors.noir))),
              Expanded(flex: 3, child: _Resident(d, avecAppartement: false)),
              Expanded(
                flex: 1,
                child: d.numeroAppartement == null
                    ? const _Vide()
                    : Text(d.numeroAppartement!,
                        style: style.copyWith(
                            color: AppColors.noir,
                            fontWeight: FontWeight.w600)),
              ),
              Expanded(
                flex: 2,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    BadgeTypeDemandeResident(type: d.type),
                    if (d.estUrgente)
                      const Tooltip(
                        message: 'Urgent',
                        child: Icon(Icons.priority_high_rounded,
                            size: 16, color: AppColors.nonAutorise),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child:
                    menage == null ? const _Vide() : Text(menage, style: style),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    d.motif,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(dateEnvoiDemandeResident(d), style: style),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BadgeEtatDemandeResident(demande: d),
                ),
              ),
              SizedBox(
                width: 104,
                child: Center(
                  child: aTraiter
                      ? _BoutonsAction(
                          demande: d, onAgir: onAgir, compacts: true)
                      : IconButton(
                          tooltip: 'Voir le détail',
                          onPressed: onOuvrir,
                          icon: const Icon(Icons.visibility_outlined,
                              color: AppColors.rouge),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grille ─────────────────────────────────────────────────

class _GrilleDemandes extends StatelessWidget {
  final List<DemandeResident> lignes;
  final ValueChanged<DemandeResident> onOuvrir;
  final void Function(DemandeResident, _Action) onAgir;

  const _GrilleDemandes({
    required this.lignes,
    required this.onOuvrir,
    required this.onAgir,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      final colonnes = math.max(1, (c.maxWidth + ecart) ~/ (340 + ecart));
      final largeur = (c.maxWidth - ecart * (colonnes - 1)) / colonnes;
      return Wrap(
        spacing: ecart,
        runSpacing: ecart,
        children: [
          for (final d in lignes)
            SizedBox(
              width: largeur,
              child: _CarteDemande(
                demande: d,
                onOuvrir: () => onOuvrir(d),
                onAgir: (a) => onAgir(d, a),
              ),
            ),
        ],
      );
    });
  }
}

class _CarteDemande extends StatelessWidget {
  final DemandeResident demande;
  final VoidCallback onOuvrir;
  final ValueChanged<_Action> onAgir;

  const _CarteDemande({
    required this.demande,
    required this.onOuvrir,
    required this.onAgir,
  });

  @override
  Widget build(BuildContext context) {
    final d = demande;
    final menage = menageDemande(d);
    final aTraiter = aTraiterDemande(d);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: aTraiter
              ? AppColors.aVerifier.withValues(alpha: 0.6)
              : AppColors.grisMedium,
          width: aTraiter ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOuvrir,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _Resident(d, rayon: 18)),
                    const SizedBox(width: 8),
                    BadgeEtatDemandeResident(demande: d),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    BadgeTypeDemandeResident(type: d.type),
                    if (d.estUrgente) const BadgeUrgente(),
                    if (menage != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cleaning_services_outlined,
                              size: 14, color: AppColors.grisText),
                          const SizedBox(width: 4),
                          Text(menage,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.grisDark)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  d.motif,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, height: 1.35, color: AppColors.noir),
                ),
                if (d.type == TypeDemande.infoAppartement && d.enAttente) ...[
                  const SizedBox(height: 8),
                  _PropositionInfo(demande: d),
                ],
                if (!d.enAttente &&
                    ((d.reponse?.isNotEmpty ?? false) ||
                        d.propositionDate != null)) ...[
                  const SizedBox(height: 8),
                  _BlocReponse(demande: d),
                ],
                const SizedBox(height: 8),
                Text(
                  d.resolue && d.dateResolution != null
                      ? 'Envoyée le ${dateEnvoiDemandeResident(d)} · '
                          'résolue le ${dateCourteDemande(d.dateResolution!)}'
                      : 'Envoyée le ${dateEnvoiDemandeResident(d)}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.grisText),
                ),
                if (aTraiter) ...[
                  const SizedBox(height: AppSizes.md),
                  _BoutonsAction(demande: d, onAgir: onAgir),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Détail d'une demande ───────────────────────────────────

class _DetailDemande extends StatelessWidget {
  final DemandeResident demande;
  final ValueChanged<_Action> onAgir;

  const _DetailDemande({required this.demande, required this.onAgir});

  @override
  Widget build(BuildContext context) {
    final d = demande;
    final menage = menageDemande(d);
    final apt = appartementDemande(d);

    Widget info(IconData icone, String libelle, Widget valeur) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, size: 17, color: AppColors.grisText),
              const SizedBox(width: 10),
              SizedBox(
                width: 104,
                child: Text(libelle,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.grisText)),
              ),
              Expanded(child: valeur),
            ],
          ),
        );
    const style = TextStyle(fontSize: 13.5, color: AppColors.noir);

    return DialogueApp(
      titre: 'Demande de ${nomResidentDemande(d)}',
      largeur: 560,
      libelleAction: 'Fermer',
      onAction: () => Navigator.of(context).pop(),
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (apt != null)
            info(
              Icons.apartment_rounded,
              'Appartement',
              Text(
                d.tailleAppartement == null
                    ? apt
                    : '$apt · ${d.tailleAppartement}',
                style: style.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          info(
            Icons.category_outlined,
            'Type',
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  BadgeTypeDemandeResident(type: d.type),
                  if (d.estUrgente) const BadgeUrgente(),
                ],
              ),
            ),
          ),
          info(
            Icons.flag_outlined,
            'État',
            Align(
              alignment: Alignment.centerLeft,
              child: BadgeEtatDemandeResident(demande: d),
            ),
          ),
          if (menage != null)
            info(Icons.cleaning_services_outlined, 'Ménage visé',
                Text(menage, style: style)),
          info(Icons.send_outlined, 'Envoyée le',
              Text(dateEnvoiDemandeResident(d), style: style)),
          if (d.dateReponse != null)
            info(Icons.reply_rounded, 'Répondue le',
                Text(dateHeureDemande(d.dateReponse!), style: style)),
          if (d.resolue && d.dateResolution != null)
            info(Icons.task_alt_rounded, 'Résolue le',
                Text(dateHeureDemande(d.dateResolution!), style: style)),
          const SizedBox(height: 4),
          const Text('Motif',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grisDark)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.grisLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.grisMedium),
            ),
            child: Text(d.motif, style: style.copyWith(height: 1.4)),
          ),
          if (d.type == TypeDemande.infoAppartement) ...[
            const SizedBox(height: 12),
            _PropositionInfo(demande: d),
          ],
          if (!d.enAttente &&
              ((d.reponse?.isNotEmpty ?? false) ||
                  d.propositionDate != null)) ...[
            const SizedBox(height: 12),
            _BlocReponse(demande: d),
          ],
          if (aTraiterDemande(d)) ...[
            const SizedBox(height: 18),
            _BoutonsAction(demande: d, onAgir: onAgir),
          ],
        ],
      ),
    );
  }
}

// ── Rappel de la demande dans les dialogues d'action ───────

class _RappelDemande extends StatelessWidget {
  final DemandeResident demande;
  const _RappelDemande({required this.demande});

  @override
  Widget build(BuildContext context) {
    final d = demande;
    final menage = menageDemande(d);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Resident(d, rayon: 16),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BadgeTypeDemandeResident(type: d.type),
              if (d.estUrgente) const BadgeUrgente(),
              if (menage != null)
                Text(menage,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.grisDark)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            d.motif,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.noir),
          ),
        ],
      ),
    );
  }
}

InputDecoration _decorationChamp(String label, {String? erreur}) =>
    InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      errorText: erreur,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
      contentPadding: const EdgeInsets.all(12),
    );

void _signalerErreur(BuildContext context, WidgetRef ref) {
  NotificationApp.erreur(
    context,
    ref.read(demandesResponsableProvider).error ??
        'L’opération n’a pas abouti. Réessayez.',
  );
}

// ── Répondre (avec créneau proposé pour reprogrammer / annuler) ──

class _RepondreDialog extends ConsumerStatefulWidget {
  final DemandeResident demande;
  const _RepondreDialog({required this.demande});

  @override
  ConsumerState<_RepondreDialog> createState() => _RepondreDialogState();
}

class _RepondreDialogState extends ConsumerState<_RepondreDialog> {
  final _reponseCtrl = TextEditingController();
  DateTime? _date;
  String _periode = 'AM';

  bool get _avecProposition =>
      widget.demande.type == TypeDemande.reprogrammer ||
      widget.demande.type == TypeDemande.annuler;

  bool get _valide =>
      _reponseCtrl.text.trim().isNotEmpty &&
      (!_avecProposition || _date != null);

  @override
  void initState() {
    super.initState();
    // Nouvelle proposition : on repart du créneau précédent.
    final d = widget.demande;
    if (refuseeParResident(d)) {
      _periode = d.propositionPeriode ?? 'AM';
    }
  }

  @override
  void dispose() {
    _reponseCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final demain = DateTime.now().add(const Duration(days: 1));
    final choisie = await showDatePicker(
      context: context,
      initialDate: _date ?? widget.demande.menageDate ?? demain,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'CA'),
    );
    if (choisie != null) setState(() => _date = choisie);
  }

  Future<void> _envoyer() async {
    if (!_valide) return;
    final ok = await ref.read(demandesResponsableProvider.notifier).repondre(
          demandeId: widget.demande.id,
          reponse: _reponseCtrl.text.trim(),
          propositionDate: _avecProposition ? _date : null,
          propositionPeriode: _avecProposition ? _periode : null,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(_avecProposition
          ? 'Réponse envoyée : le résident doit accepter le créneau proposé.'
          : 'Réponse envoyée au résident.');
    } else {
      _signalerErreur(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSending = ref.watch(demandesResponsableProvider).isSending;
    final nouvelle = refuseeParResident(widget.demande);

    return DialogueApp(
      titre: nouvelle ? 'Nouvelle proposition' : 'Répondre à la demande',
      largeur: 500,
      libelleAction: 'Envoyer',
      libelleSecondaire: 'Annuler',
      enCours: isSending,
      onAction: _valide ? _envoyer : null,
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _RappelDemande(demande: widget.demande),
          if (nouvelle) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 15, color: AppColors.refus),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Le résident a refusé le créneau précédent.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.refus),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _reponseCtrl,
            maxLines: 3,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: _decorationChamp('Votre réponse').copyWith(
              hintText: 'Expliquez votre décision…',
            ),
          ),
          if (_avecProposition) ...[
            const SizedBox(height: 16),
            const Text('Créneau proposé',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grisDark)),
            const SizedBox(height: 8),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _choisirDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(_date == null
                      ? 'Choisir la date'
                      : dateCourteDemande(_date!)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rouge,
                    side: const BorderSide(color: AppColors.rouge),
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 40),
                  ),
                ),
                for (final (p, libelle) in const [
                  ('AM', 'Matin'),
                  ('PM', 'Après-midi'),
                ])
                  ChoiceChip(
                    label: Text(libelle),
                    selected: _periode == p,
                    onSelected: (_) => setState(() => _periode = p),
                    selectedColor: AppColors.rouge.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          _periode == p ? AppColors.rouge : AppColors.grisDark,
                    ),
                    side: BorderSide(
                        color: _periode == p
                            ? AppColors.rouge
                            : AppColors.grisMedium),
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Le résident recevra une notification pour accepter ou refuser '
              'ce créneau.',
              style: TextStyle(fontSize: 12, color: AppColors.grisText),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Valider les infos d'appartement ───────────────────────

class _ValiderInfoDialog extends ConsumerWidget {
  final DemandeResident demande;
  const _ValiderInfoDialog({required this.demande});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSending = ref.watch(demandesResponsableProvider).isSending;
    final apt = appartementDemande(demande) ?? 'l’appartement';

    return DialogueApp(
      titre: 'Valider les infos',
      largeur: 460,
      libelleAction: 'Valider et appliquer',
      libelleSecondaire: 'Annuler',
      enCours: isSending,
      onAction: () async {
        final ok = await ref
            .read(demandesResponsableProvider.notifier)
            .validerInfoAppartement(demande.id);
        if (!context.mounted) return;
        if (ok) {
          Navigator.of(context).pop('Infos appliquées à $apt.');
        } else {
          _signalerErreur(context, ref);
        }
      },
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PropositionInfo(demande: demande),
          const SizedBox(height: 12),
          Text(
            'Ces informations remplaceront celles de la fiche de $apt, '
            'et la demande sera résolue.',
            style: const TextStyle(fontSize: 13, color: AppColors.grisDark),
          ),
        ],
      ),
    );
  }
}

// ── Refuser les infos d'appartement ───────────────────────

class _RefuserInfoDialog extends ConsumerStatefulWidget {
  final DemandeResident demande;
  const _RefuserInfoDialog({required this.demande});

  @override
  ConsumerState<_RefuserInfoDialog> createState() => _RefuserInfoDialogState();
}

class _RefuserInfoDialogState extends ConsumerState<_RefuserInfoDialog> {
  final _reponseCtrl = TextEditingController();

  @override
  void dispose() {
    _reponseCtrl.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final reponse = _reponseCtrl.text.trim();
    if (reponse.isEmpty) return;
    final ok = await ref
        .read(demandesResponsableProvider.notifier)
        .refuserInfoAppartement(demandeId: widget.demande.id, reponse: reponse);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context)
          .pop('Proposition refusée. Le résident est prévenu.');
    } else {
      _signalerErreur(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSending = ref.watch(demandesResponsableProvider).isSending;
    return DialogueApp(
      titre: 'Refuser la proposition',
      largeur: 480,
      libelleAction: 'Confirmer le refus',
      libelleSecondaire: 'Annuler',
      enCours: isSending,
      onAction: _reponseCtrl.text.trim().isEmpty ? null : _envoyer,
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PropositionInfo(demande: widget.demande),
          const SizedBox(height: 14),
          TextField(
            controller: _reponseCtrl,
            maxLines: 3,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: _decorationChamp('Motif du refus').copyWith(
              hintText: 'Expliquez pourquoi vous refusez…',
            ),
          ),
        ],
      ),
    );
  }
}

// ── État vide ──────────────────────────────────────────────

class _EtatVide extends StatelessWidget {
  final String titre;
  final String texte;
  final VoidCallback? onReinitialiser;

  const _EtatVide({
    required this.titre,
    required this.texte,
    this.onReinitialiser,
  });

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
            child: const Icon(Icons.forum_rounded,
                size: 44, color: AppColors.rouge),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.noir),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            texte,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grisText, fontSize: 13),
          ),
          if (onReinitialiser != null) ...[
            const SizedBox(height: AppSizes.md),
            OutlinedButton.icon(
              onPressed: onReinitialiser,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Réinitialiser les filtres'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rouge,
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
