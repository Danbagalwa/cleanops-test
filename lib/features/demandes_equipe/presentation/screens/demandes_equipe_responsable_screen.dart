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
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pdf/domain/usecases/generate_demandes_equipe_export.dart';
import '../../../pdf/presentation/screens/demandes_equipe_pdf_preview_screen.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';
import '../../domain/entities/demande_equipe.dart';
import '../providers/demande_equipe_provider.dart';
import '../widgets/actions_document_demande.dart';
import '../widgets/demande_equipe_elements.dart';
import '../widgets/piece_jointe_demande.dart';
import '../widgets/preuve_traitement.dart';

enum _Statut { toutes, enAttente, traitees }

enum _Tri { priorite, envoi, employe, statut }

class DemandesEquipeResponsableScreen extends ConsumerStatefulWidget {
  const DemandesEquipeResponsableScreen({super.key});

  @override
  ConsumerState<DemandesEquipeResponsableScreen> createState() =>
      _DemandesEquipeResponsableScreenState();
}

class _DemandesEquipeResponsableScreenState
    extends ConsumerState<DemandesEquipeResponsableScreen> {
  _Statut _statut = _Statut.toutes;
  TypeDemandeEquipe? _type;
  String _recherche = '';
  _Tri _tri = _Tri.priorite;
  bool _croissant = false;
  int _page = 0;
  int _parPage = 10;

  /// `null` : choisi selon la largeur (grille sur téléphone, tableau sinon).
  ModeAffichage? _mode;

  Future<void> _charger() =>
      ref.read(demandesEquipeResponsableProvider.notifier).charger();

  void _changer(VoidCallback maj) => setState(() {
        maj();
        _page = 0;
      });

  void _trier(_Tri tri) => _changer(() {
        _croissant = _tri == tri ? !_croissant : tri == _Tri.employe;
        _tri = tri;
      });

  bool _duStatut(DemandeEquipe d) => switch (_statut) {
        _Statut.toutes => true,
        _Statut.enAttente => d.enAttente,
        _Statut.traitees => !d.enAttente,
      };

  List<DemandeEquipe> _lignes(List<DemandeEquipe> toutes) {
    final q = _recherche.trim().toLowerCase();
    int parEnvoi(DemandeEquipe a, DemandeEquipe b) =>
        a.createdAt.compareTo(b.createdAt);
    int sens(int c) => _croissant ? c : -c;
    return toutes.where((d) {
      if (!_duStatut(d)) return false;
      if (_type != null && d.type != _type) return false;
      return q.isEmpty ||
          nomDemandeur(d).toLowerCase().contains(q) ||
          d.motif.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => switch (_tri) {
            // En attente d'abord, puis les plus récentes.
            _Tri.priorite => a.enAttente != b.enAttente
                ? (a.enAttente ? -1 : 1)
                : -parEnvoi(a, b),
            _Tri.envoi => sens(parEnvoi(a, b)),
            _Tri.employe => sens(nomDemandeur(a)
                .toLowerCase()
                .compareTo(nomDemandeur(b).toLowerCase())),
            _Tri.statut =>
              sens(libelleStatutDemande(a).compareTo(libelleStatutDemande(b))),
          });
  }

  String _descriptionFiltres() {
    final f = <String>[
      if (_statut == _Statut.enAttente) 'En attente',
      if (_statut == _Statut.traitees) 'Traitées',
      if (_type != null) _type!.libelle,
      if (_recherche.trim().isNotEmpty) '« ${_recherche.trim()} »',
    ];
    return f.isEmpty ? 'Toutes les demandes' : f.join(' · ');
  }

  // ── Actions ────────────────────────────────────────────

  void _ouvrirDetail(DemandeEquipe d) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _DetailDemande(
        demande: d,
        onTraiter: (approuve) {
          Navigator.of(ctx).pop();
          _traiter(d, approuve);
        },
        onAjouterPreuve: () {
          Navigator.of(ctx).pop();
          ouvrirAjoutPreuve(context, d);
        },
      ),
    );
  }

  void _traiter(DemandeEquipe d, bool? approuve) {
    showDialog<void>(
      context: context,
      builder: (_) => _TraiterDialog(demande: d, approuve: approuve),
    );
  }

  void _exporterPdf(List<DemandeEquipe> lignes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DemandesEquipePdfPreviewScreen(
          demandes: lignes,
          filtres: _descriptionFiltres(),
          generatedBy:
              ref.read(employeeCourantProvider)?.nomComplet ?? 'CleanOps',
        ),
      ),
    );
  }

  void _exporterExcel(List<DemandeEquipe> lignes) {
    try {
      const GenerateDemandesEquipeExcel()(
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
    final state = ref.watch(demandesEquipeResponsableProvider);
    final compact = estCompact(context);
    final mode =
        compact ? ModeAffichage.grille : (_mode ?? ModeAffichage.tableau);
    final marge = compact ? 12.0 : 24.0;

    final toutes = state.demandes;
    final lignes = _lignes(toutes);
    final nbPages = lignes.isEmpty ? 1 : ((lignes.length - 1) ~/ _parPage) + 1;
    final page = _page.clamp(0, nbPages - 1);
    final visibles = lignes.skip(page * _parPage).take(_parPage).toList();
    final enAttente = state.badgeEnAttente;

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
      indice: 'Rechercher un employé ou un motif',
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
        titre: 'Aucune demande d’équipe',
        texte: 'Les demandes de congé, d’absence ou autres envoyées par '
            'l’équipe apparaîtront ici.',
      );
    } else if (lignes.isEmpty) {
      corps = _EtatVide(
        titre: _statut == _Statut.enAttente
            ? 'Rien à traiter'
            : 'Aucune demande ne correspond',
        texte: _statut == _Statut.enAttente
            ? 'Toutes les demandes ont reçu une réponse.'
            : 'Modifiez les filtres ou la recherche.',
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
              onTraiter: _traiter,
            )
          else
            _GrilleDemandes(
              lignes: visibles,
              onOuvrir: _ouvrirDetail,
              onTraiter: _traiter,
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

    return PageAvecEnTete(
      chargement: state.isLoading,
      enTete: EnTetePage(
        icone: Icons.event_note_rounded,
        titre: 'Demandes équipe',
        sousTitre: enAttente == 0
            ? 'Congés, absences planifiées et autres demandes — tout est traité'
            : 'Congés, absences planifiées et autres demandes — '
                '$enAttente en attente',
      ),
      contenu: RefreshIndicator(
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
                filtre(_Statut.enAttente, Icons.hourglass_top_rounded,
                    'En attente',
                    pastille: enAttente > 0),
                filtre(_Statut.traitees, Icons.task_alt_rounded, 'Traitées'),
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
      ),
    );
  }
}

// ── Filtre par type (avec effectifs) ───────────────────────

class _FiltreTypes extends StatelessWidget {
  final List<DemandeEquipe> demandes;
  final TypeDemandeEquipe? selection;
  final ValueChanged<TypeDemandeEquipe?> onChanged;

  const _FiltreTypes({
    required this.demandes,
    required this.selection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    _TuileType tuile(TypeDemandeEquipe? t) {
      final dans =
          t == null ? demandes : demandes.where((d) => d.type == t).toList();
      return _TuileType(
        icone: t == null ? Icons.apps_rounded : iconeTypeDemande(t),
        couleur: t == null ? AppColors.rouge : couleurTypeDemande(t),
        libelle: t == null ? 'Tous les types' : t.libelle,
        nombre: dans.length,
        enAttente: dans.where((d) => d.enAttente).length,
        actif: selection == t,
        onTap: () => onChanged(selection == t ? null : t),
      );
    }

    final tuiles = [
      tuile(null),
      for (final t in TypeDemandeEquipe.values) tuile(t)
    ];

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
  final int enAttente;
  final bool actif;
  final VoidCallback onTap;

  const _TuileType({
    required this.icone,
    required this.couleur,
    required this.libelle,
    required this.nombre,
    required this.enAttente,
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
                        if (enAttente > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.aVerifier.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$enAttente en attente',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.aVerifier,
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

class _Demandeur extends StatelessWidget {
  final DemandeEquipe demande;
  final double rayon;
  const _Demandeur(this.demande, {this.rayon = 15});

  @override
  Widget build(BuildContext context) {
    final nom = nomDemandeur(demande);
    return Row(
      children: [
        AvatarProfil(
          proprietaire: ProprietairePhoto(
              TypeProprietairePhoto.employe, demande.employeeId),
          initiales: nom.isNotEmpty ? nom[0].toUpperCase() : '?',
          rayon: rayon,
          couleurFond: AppColors.rouge.withValues(alpha: 0.12),
          couleurTexte: AppColors.rouge,
          tailleTexte: rayon * 0.8,
          poidsTexte: FontWeight.bold,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            nom,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: rayon > 16 ? 14.5 : 13,
              fontWeight: FontWeight.w700,
              color: AppColors.noir,
            ),
          ),
        ),
      ],
    );
  }
}

/// Boutons de traitement d'une demande en attente.
class _BoutonsTraitement extends StatelessWidget {
  final DemandeEquipe demande;
  final ValueChanged<bool?> onTraiter;
  final bool compacts;

  const _BoutonsTraitement({
    required this.demande,
    required this.onTraiter,
    this.compacts = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compacts) {
      if (demande.type == TypeDemandeEquipe.autre) {
        return IconButton(
          tooltip: 'Marquer comme vue',
          onPressed: () => onTraiter(null),
          icon:
              const Icon(Icons.visibility_outlined, color: AppColors.grisDark),
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Refuser',
            onPressed: () => onTraiter(false),
            icon: const Icon(Icons.close_rounded, color: AppColors.refus),
          ),
          IconButton(
            tooltip: 'Approuver',
            onPressed: () => onTraiter(true),
            icon: const Icon(Icons.check_rounded, color: AppColors.fait),
          ),
        ],
      );
    }

    const forme = StadiumBorder();
    if (demande.type == TypeDemandeEquipe.autre) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => onTraiter(null),
          icon: const Icon(Icons.visibility_outlined, size: 17),
          label: const Text('Marquer comme vue'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.grisDark,
            side: const BorderSide(color: AppColors.grisMedium),
            shape: forme,
            minimumSize: const Size(0, 42),
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onTraiter(false),
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
            onPressed: () => onTraiter(true),
            icon: const Icon(Icons.check_rounded, size: 17),
            label: const Text('Approuver'),
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
}

// ── Tableau ────────────────────────────────────────────────

const _styleEnTete = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.grisDark,
);

class _TableauDemandes extends StatelessWidget {
  final List<DemandeEquipe> lignes;
  final int premierNumero;
  final _Tri tri;
  final bool croissant;
  final ValueChanged<_Tri> onTrier;
  final ValueChanged<DemandeEquipe> onOuvrir;
  final void Function(DemandeEquipe, bool?) onTraiter;

  const _TableauDemandes({
    required this.lignes,
    required this.premierNumero,
    required this.tri,
    required this.croissant,
    required this.onTrier,
    required this.onOuvrir,
    required this.onTraiter,
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
                Expanded(flex: 3, child: entete('Employé', _Tri.employe)),
                const Expanded(
                    flex: 2, child: Text('Type', style: _styleEnTete)),
                const Expanded(
                    flex: 3, child: Text('Période', style: _styleEnTete)),
                const Expanded(
                    flex: 4, child: Text('Motif', style: _styleEnTete)),
                Expanded(flex: 2, child: entete('Envoyée le', _Tri.envoi)),
                Expanded(flex: 2, child: entete('Statut', _Tri.statut)),
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
              onTraiter: (a) => onTraiter(d, a),
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
  final DemandeEquipe demande;
  final int numero;
  final VoidCallback onOuvrir;
  final ValueChanged<bool?> onTraiter;

  const _LigneDemande({
    required this.demande,
    required this.numero,
    required this.onOuvrir,
    required this.onTraiter,
  });

  @override
  Widget build(BuildContext context) {
    final d = demande;
    const style = TextStyle(fontSize: 13, color: AppColors.noir);
    final periode = periodeDemande(d);
    final jours = joursDemande(d);
    return Material(
      color: d.enAttente
          ? AppColors.aVerifier.withValues(alpha: 0.04)
          : Colors.transparent,
      child: InkWell(
        onTap: onOuvrir,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 36, child: Text('$numero', style: style)),
              Expanded(flex: 3, child: _Demandeur(d)),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BadgeTypeDemande(type: d.type),
                ),
              ),
              Expanded(
                flex: 3,
                child: periode == null
                    ? const Text('—',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.grisText))
                    : Text(
                        jours != null && jours > 1
                            ? '$periode ($jours j)'
                            : periode,
                        style: style.copyWith(color: AppColors.grisDark),
                      ),
              ),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    if (d.aDocument) ...[
                      MenuDocumentDemande(
                        demande: d,
                        enfant: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child:
                              IconeFichier(pdf: estPdfDemande(d), taille: 26),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        d.motif,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(color: AppColors.grisDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(dateEnvoiDemande(d),
                    style: style.copyWith(color: AppColors.grisDark)),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BadgeStatutDemande(demande: d),
                ),
              ),
              SizedBox(
                width: 104,
                child: Center(
                  child: d.enAttente
                      ? _BoutonsTraitement(
                          demande: d, onTraiter: onTraiter, compacts: true)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (d.aPreuve)
                              MenuDocumentDemande(
                                demande: d,
                                preuve: true,
                                enfant: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                  child: IconeFichier(
                                      pdf: FichierDemande(d, preuve: true).pdf,
                                      taille: 26),
                                ),
                              ),
                            IconButton(
                              tooltip: 'Voir le détail',
                              onPressed: onOuvrir,
                              icon: const Icon(Icons.visibility_outlined,
                                  color: AppColors.rouge),
                            ),
                          ],
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
  final List<DemandeEquipe> lignes;
  final ValueChanged<DemandeEquipe> onOuvrir;
  final void Function(DemandeEquipe, bool?) onTraiter;

  const _GrilleDemandes({
    required this.lignes,
    required this.onOuvrir,
    required this.onTraiter,
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
                onTraiter: (a) => onTraiter(d, a),
              ),
            ),
        ],
      );
    });
  }
}

class _CarteDemande extends StatelessWidget {
  final DemandeEquipe demande;
  final VoidCallback onOuvrir;
  final ValueChanged<bool?> onTraiter;

  const _CarteDemande({
    required this.demande,
    required this.onOuvrir,
    required this.onTraiter,
  });

  @override
  Widget build(BuildContext context) {
    final d = demande;
    final periode = periodeDemande(d);
    return Container(
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
                    Expanded(child: _Demandeur(d, rayon: 18)),
                    const SizedBox(width: 8),
                    BadgeStatutDemande(demande: d),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    BadgeTypeDemande(type: d.type),
                    if (periode != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event_rounded,
                              size: 14, color: AppColors.grisText),
                          const SizedBox(width: 4),
                          Text(periode,
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
                if (d.aDocument) ...[
                  const SizedBox(height: 8),
                  PieceJointeDemande(demande: d),
                ],
                if (d.resolue) ...[
                  const SizedBox(height: 8),
                  NoteResponsableDemande(demande: d),
                ],
                if (d.aPreuve) ...[
                  const SizedBox(height: 8),
                  PieceJointeDemande(demande: d, preuve: true),
                ],
                const SizedBox(height: 8),
                Text(
                  'Envoyée le ${dateEnvoiDemande(d)}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.grisText),
                ),
                if (d.enAttente) ...[
                  const SizedBox(height: AppSizes.md),
                  _BoutonsTraitement(demande: d, onTraiter: onTraiter),
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
  final DemandeEquipe demande;
  final ValueChanged<bool?> onTraiter;
  final VoidCallback onAjouterPreuve;

  const _DetailDemande({
    required this.demande,
    required this.onTraiter,
    required this.onAjouterPreuve,
  });

  @override
  Widget build(BuildContext context) {
    final d = demande;
    final periode = periodeDemande(d);
    final jours = joursDemande(d);

    Widget info(IconData icone, String libelle, Widget valeur) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, size: 17, color: AppColors.grisText),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
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
      titre: 'Demande de ${nomDemandeur(d)}',
      largeur: 540,
      libelleAction: 'Fermer',
      onAction: () => Navigator.of(context).pop(),
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          info(Icons.category_outlined, 'Type', BadgeTypeDemande(type: d.type)),
          info(
            Icons.flag_outlined,
            'Statut',
            Align(
              alignment: Alignment.centerLeft,
              child: BadgeStatutDemande(demande: d),
            ),
          ),
          if (periode != null)
            info(
              Icons.event_rounded,
              'Période',
              Text(
                jours != null && jours > 1
                    ? '$periode · $jours jours'
                    : periode,
                style: style,
              ),
            ),
          info(Icons.send_outlined, 'Envoyée le',
              Text(dateEnvoiDemande(d), style: style)),
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
          if (d.aDocument) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: PieceJointeDemande(demande: d),
            ),
          ],
          if (d.resolue) ...[
            const SizedBox(height: 12),
            NoteResponsableDemande(demande: d),
            const SizedBox(height: 12),
            if (d.aPreuve)
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: PieceJointeDemande(demande: d, preuve: true),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remplacer la preuve',
                    onPressed: onAjouterPreuve,
                    icon: const Icon(Icons.swap_horiz_rounded,
                        color: AppColors.rouge),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onAjouterPreuve,
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Joindre une preuve de traitement'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.fait,
                    side: BorderSide(
                        color: AppColors.fait.withValues(alpha: 0.5)),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
          ],
          if (d.enAttente) ...[
            const SizedBox(height: 18),
            _BoutonsTraitement(demande: d, onTraiter: onTraiter),
          ],
        ],
      ),
    );
  }
}

// ── Dialog de traitement ───────────────────────────────────

class _TraiterDialog extends ConsumerStatefulWidget {
  final DemandeEquipe demande;

  /// null : marquer comme vue seulement (demande de type "Autre").
  final bool? approuve;
  const _TraiterDialog({required this.demande, required this.approuve});

  @override
  ConsumerState<_TraiterDialog> createState() => _TraiterDialogState();
}

class _TraiterDialogState extends ConsumerState<_TraiterDialog> {
  final _noteCtrl = TextEditingController();
  FichierPreuve? _preuve;
  bool _envoiPreuve = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final ok = await ref
        .read(demandesEquipeResponsableProvider.notifier)
        .traiter(
          demandeId: widget.demande.id,
          approuve: widget.approuve,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      // La demande est traitée ; la preuve (facultative) suit. Son échec ne
      // remet pas en cause le traitement : on prévient simplement.
      String? erreurPreuve;
      if (_preuve != null) {
        setState(() => _envoiPreuve = true);
        erreurPreuve =
            await envoyerPreuveTraitement(ref, widget.demande, _preuve!);
        if (!mounted) return;
      }
      Navigator.of(context).pop();
      final message = switch (widget.approuve) {
        true => 'Demande approuvée.',
        false => 'Demande refusée.',
        null => 'Demande marquée comme vue.',
      };
      if (erreurPreuve != null) {
        NotificationApp.avertissement(
          context,
          '$message Mais la preuve n’a pas pu être jointe : $erreurPreuve '
          'Vous pourrez la joindre depuis le détail de la demande.',
        );
      } else {
        NotificationApp.succes(
          context,
          _preuve == null ? message : '$message Preuve de traitement jointe.',
        );
      }
    } else {
      NotificationApp.erreur(
        context,
        ref.read(demandesEquipeResponsableProvider).error ??
            'La demande n’a pas pu être traitée. Réessayez.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSending = ref.watch(demandesEquipeResponsableProvider).isSending;
    final d = widget.demande;
    final periode = periodeDemande(d);
    final titre = switch (widget.approuve) {
      true => 'Approuver la demande',
      false => 'Refuser la demande',
      null => 'Marquer comme vue',
    };
    final labelNote = switch (widget.approuve) {
      true => 'Note (optionnelle)',
      false => 'Motif du refus (optionnel)',
      null => 'Note (optionnelle)',
    };
    final labelBouton = switch (widget.approuve) {
      true => 'Approuver',
      false => 'Refuser',
      null => 'Marquer comme vue',
    };

    return DialogueApp(
      titre: titre,
      largeur: 480,
      libelleAction: labelBouton,
      libelleSecondaire: 'Annuler',
      enCours: isSending || _envoiPreuve,
      onAction: _envoyer,
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.grisLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.grisMedium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Demandeur(d, rayon: 16),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    BadgeTypeDemande(type: d.type),
                    if (periode != null)
                      Text(periode,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.grisDark)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  d.motif,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.noir),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              labelText: labelNote,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          ChampPreuveTraitement(
            valeur: _preuve,
            enEnvoi: _envoiPreuve,
            onChanged: (f) => setState(() => _preuve = f),
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
  const _EtatVide({required this.titre, required this.texte});

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
        ],
      ),
    );
  }
}
