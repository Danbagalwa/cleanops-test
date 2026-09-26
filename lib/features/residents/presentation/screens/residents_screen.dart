import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/export_menu_button.dart'
    show showExportSuccess;
import '../../../../core/widgets/mise_en_page.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../../appartements/presentation/widgets/appartement_list_item.dart'
    show BadgeTaille, comparerNumeros;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pdf/domain/usecases/generate_residents_export.dart';
import '../../../pdf/presentation/screens/residents_pdf_preview_screen.dart';
import '../../domain/entities/resident.dart';
import '../providers/resident_provider.dart';
import '../widgets/creer_resident_dialog.dart';
import '../widgets/desactivation_dialog.dart';
import '../widgets/pin_attribution_dialog.dart';
import '../widgets/resident_list_item.dart';

/// Activité du résident (filtres de la barre de section).
enum _Activite { tous, actifs, inactifs }

/// Accès à l'application (tuiles).
enum _Acces { tous, inscrits, sansApp, sansPin }

enum _Tri { nom, appartement, statut }

class ResidentsScreen extends ConsumerStatefulWidget {
  const ResidentsScreen({super.key});

  @override
  ConsumerState<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends ConsumerState<ResidentsScreen> {
  final _searchCtrl = TextEditingController();
  String _recherche = '';
  _Activite _activite = _Activite.actifs;
  _Acces _acces = _Acces.tous;
  _Tri _tri = _Tri.appartement;
  bool _croissant = true;
  int _page = 0;
  int _parPage = 10;

  /// `null` : choisi selon la largeur (grille sur téléphone, tableau sinon).
  ModeAffichage? _mode;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  ResidentNotifier get _notifier => ref.read(residentNotifierProvider.notifier);

  Future<void> _charger() => _notifier.loadResidents();

  void _changer(VoidCallback maj) => setState(() {
        maj();
        _page = 0;
      });

  void _trier(_Tri tri) => _changer(() {
        _croissant = _tri == tri ? !_croissant : true;
        _tri = tri;
      });

  void _effacerFiltres() {
    _searchCtrl.clear();
    _changer(() {
      _recherche = '';
      _activite = _Activite.tous;
      _acces = _Acces.tous;
    });
  }

  bool _deLActivite(Resident r) => switch (_activite) {
        _Activite.tous => true,
        _Activite.actifs => r.isActif,
        _Activite.inactifs => !r.isActif,
      };

  static bool _deLAcces(Resident r, _Acces a) => switch (a) {
        _Acces.tous => true,
        _Acces.inscrits => r.aApplication,
        _Acces.sansApp => !r.aApplication,
        _Acces.sansPin => r.aApplication && !r.aPin,
      };

  List<Resident> _lignes(List<Resident> tous) {
    final q = _recherche.trim().toLowerCase();
    int parNom(Resident a, Resident b) =>
        a.nomComplet.toLowerCase().compareTo(b.nomComplet.toLowerCase());
    int sens(int c) => _croissant ? c : -c;
    return tous.where((r) {
      if (!_deLActivite(r) || !_deLAcces(r, _acces)) return false;
      return q.isEmpty ||
          r.nomComplet.toLowerCase().contains(q) ||
          (r.numeroAppartement?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) {
        final c = switch (_tri) {
          _Tri.nom => parNom(a, b),
          _Tri.appartement => comparerNumeros(
              a.numeroAppartement ?? '', b.numeroAppartement ?? ''),
          _Tri.statut => a.statut.compareTo(b.statut),
        };
        return c != 0 ? sens(c) : parNom(a, b);
      });
  }

  String _descriptionFiltres() {
    final f = <String>[
      if (_recherche.trim().isNotEmpty) 'Recherche : "${_recherche.trim()}"',
      if (_activite == _Activite.actifs) 'Actifs',
      if (_activite == _Activite.inactifs) 'Inactifs',
      if (_acces == _Acces.inscrits) 'Inscrits à l’application',
      if (_acces == _Acces.sansApp) 'Sans application',
      if (_acces == _Acces.sansPin) 'Inscrits sans PIN',
    ];
    return f.isEmpty ? 'Tous les résidents' : f.join(' · ');
  }

  // ── Actions ────────────────────────────────────────────

  Future<void> _ouvrirCreation() async {
    var avecPin = false;
    final cree = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreerResidentDialog(
        onConfirmer: ({
          required String aptId,
          required String nom,
          required String prenom,
          required bool aApplication,
          required String? pin,
        }) {
          avecPin = pin != null;
          return _signalerSiEchec(pin == null
              ? _notifier.creerResident(aptId, nom, prenom, aApplication)
              : _notifier.creerResidentAvecPin(
                  aptId, nom, prenom, aApplication, pin));
        },
      ),
    );
    if (!mounted) return;
    if (cree == true) {
      NotificationApp.succes(
        context,
        avecPin
            ? 'Le résident a été créé avec son PIN.'
            : 'Le résident a été enregistré (sans application).',
      );
    }
  }

  Future<void> _ouvrirPin(Resident resident) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => PinAttributionDialog(
        nomComplet: resident.nomComplet,
        remplacement: resident.aPin,
        onConfirmer: (pin) =>
            _signalerSiEchec(_notifier.attribuerPin(resident.id, pin)),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      NotificationApp.succes(
        context,
        resident.aPin
            ? 'Le PIN de ${resident.nomComplet} a été modifié.'
            : 'Un PIN a été attribué à ${resident.nomComplet}.',
      );
    }
  }

  Future<void> _confirmerDesactivation(Resident resident) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => DesactivationDialog(
        nomComplet: resident.nomComplet,
        onConfirmer: () =>
            _signalerSiEchec(_notifier.desactiverResident(resident.id)),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      NotificationApp.succes(
          context, '${resident.nomComplet} a été désactivé(e).');
    }
  }

  Future<void> _activer(Resident resident) async {
    final ok = await _notifier.activerResident(resident.id);
    if (!mounted) return;
    if (ok) {
      NotificationApp.succes(
          context, '${resident.nomComplet} a été réactivé(e).');
    } else {
      _signalerErreur();
    }
  }

  Future<void> _basculerApplication(Resident resident) async {
    final ok =
        await _notifier.toggleApplication(resident.id, !resident.aApplication);
    if (!mounted) return;
    if (ok) {
      NotificationApp.succes(
        context,
        resident.aApplication
            ? '${resident.nomComplet} est maintenant « Sans app ».'
            : '${resident.nomComplet} est maintenant inscrit(e) à l’application.',
      );
    } else {
      _signalerErreur();
    }
  }

  /// Action lancée depuis un dialogue : en cas d'échec, le dialogue reste
  /// ouvert et l'erreur s'affiche tout de suite.
  Future<bool> _signalerSiEchec(Future<bool> action) async {
    final ok = await action;
    if (!ok && mounted) _signalerErreur();
    return ok;
  }

  /// Affiche l'erreur laissée par la dernière action.
  void _signalerErreur() {
    final erreur = ref.read(residentNotifierProvider).error;
    if (erreur == null) return;
    AppFeedback.showError(context, erreur);
  }

  void _exporterPdf(List<Resident> lignes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResidentsPdfPreviewScreen(
          residents: lignes,
          filterDescription: _descriptionFiltres(),
          generatedBy:
              ref.read(employeeCourantProvider)?.nomComplet ?? 'CleanOps',
        ),
      ),
    );
  }

  void _exporterExcel(List<Resident> lignes) {
    try {
      const GenerateResidentsExcel()(
        residents: lignes,
        filterDescription: _descriptionFiltres(),
      );
      showExportSuccess(
          context, 'La liste Excel des résidents a été téléchargée.');
    } catch (error) {
      AppFeedback.showError(context, error);
    }
  }

  // ── Construction ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(residentNotifierProvider);
    final compact = estCompact(context);
    final mode =
        compact ? ModeAffichage.grille : (_mode ?? ModeAffichage.tableau);
    final marge = compact ? 12.0 : 24.0;

    final tous = state.residents;
    final lignes = _lignes(tous);
    final nbPages = lignes.isEmpty ? 1 : ((lignes.length - 1) ~/ _parPage) + 1;
    final page = _page.clamp(0, nbPages - 1);
    final visibles = lignes.skip(page * _parPage).take(_parPage).toList();

    FiltreSection filtre(_Activite a, IconData icone, String info) =>
        FiltreSection(
          icone: icone,
          infoBulle: info,
          actif: _activite == a,
          onTap: () => _changer(() => _activite = a),
        );

    final recherche = ChampRecherche(
      controller: _searchCtrl,
      indice: 'Rechercher un nom ou un appartement',
      onChanged: (v) => _changer(() => _recherche = v),
    );
    final ajouter = FilledButton.icon(
      onPressed: _ouvrirCreation,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.rouge,
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      icon: const Icon(Icons.person_add_rounded, size: 18),
      label: Text(compact ? 'Ajouter' : 'Ajouter un résident'),
    );

    Widget corps;
    if (state.isLoading && tous.isEmpty) {
      corps = const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.rouge)),
      );
    } else if (state.error != null && tous.isEmpty) {
      corps = CarteContenu(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: AppErrorNotice(error: state.error!, onRetry: _charger),
      );
    } else if (tous.isEmpty) {
      corps = _EtatVide(onAdd: _ouvrirCreation);
    } else if (lignes.isEmpty) {
      corps = CarteContenu(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          children: [
            const Text(
              'Aucun résident ne correspond à votre recherche ou filtre.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grisDark),
            ),
            const SizedBox(height: AppSizes.md),
            OutlinedButton.icon(
              onPressed: _effacerFiltres,
              icon: const Icon(Icons.clear_rounded),
              label: const Text('Effacer les filtres'),
            ),
          ],
        ),
      );
    } else {
      corps = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == ModeAffichage.tableau)
            _TableauResidents(
              lignes: visibles,
              premierNumero: page * _parPage + 1,
              tri: _tri,
              croissant: _croissant,
              onTrier: _trier,
              onPin: _ouvrirPin,
              onDesactiver: _confirmerDesactivation,
              onActiver: _activer,
              onBasculerApplication: _basculerApplication,
            )
          else
            _GrilleResidents(
              lignes: visibles,
              onPin: _ouvrirPin,
              onDesactiver: _confirmerDesactivation,
              onActiver: _activer,
              onBasculerApplication: _basculerApplication,
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
        icone: Icons.people_alt_rounded,
        titre: 'Résidents',
        sousTitre: tous.isEmpty
            ? 'Occupants des appartements de la résidence'
            : 'Résidence — ${state.totalActifs} actifs · '
                '${state.totalInscrits} inscrits à l’application · '
                '${state.totalSansApp} sans application',
      ),
      contenu: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _charger,
        child: ListView(
          padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
              .plusBarre(context),
          children: [
            BarreSection(
              titre: 'Résidents (${lignes.length})',
              onRetour: () => context.backOrHome(AppRoutes.employerDashboard),
              filtres: [
                filtre(
                    _Activite.tous, Icons.groups_rounded, 'Tous les résidents'),
                filtre(_Activite.actifs, Icons.person_rounded, 'Actifs'),
                filtre(
                    _Activite.inactifs, Icons.person_off_outlined, 'Inactifs'),
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
            if (tous.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              _FiltreAcces(
                residents: tous.where(_deLActivite).toList(),
                selection: _acces,
                onChanged: (a) => _changer(() => _acces = a),
              ),
            ],
            const SizedBox(height: AppSizes.md),
            if (compact)
              Row(
                children: [
                  Expanded(child: recherche),
                  const SizedBox(width: AppSizes.sm),
                  ajouter,
                ],
              )
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
                  const SizedBox(width: AppSizes.md),
                  ajouter,
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

// ── Tuiles d'accès à l'application ─────────────────────────

class _FiltreAcces extends StatelessWidget {
  final List<Resident> residents;
  final _Acces selection;
  final ValueChanged<_Acces> onChanged;

  const _FiltreAcces({
    required this.residents,
    required this.selection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    _Tuile tuile(_Acces a, IconData icone, Color couleur, String libelle) =>
        _Tuile(
          icone: icone,
          couleur: couleur,
          libelle: libelle,
          nombre: residents
              .where((r) => _ResidentsScreenState._deLAcces(r, a))
              .length,
          actif: selection == a,
          alerte: a == _Acces.sansPin,
          onTap: () =>
              onChanged(selection == a && a != _Acces.tous ? _Acces.tous : a),
        );

    final tuiles = [
      tuile(_Acces.tous, Icons.groups_rounded, AppColors.rouge, 'Tous'),
      tuile(_Acces.inscrits, Icons.phone_iphone_rounded, AppColors.fait,
          'Inscrits à l’app'),
      tuile(_Acces.sansApp, Icons.phonelink_erase_rounded, AppColors.aVerifier,
          'Sans application'),
      tuile(_Acces.sansPin, Icons.key_off_rounded, AppColors.refus,
          'Inscrits sans PIN'),
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

class _Tuile extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String libelle;
  final int nombre;
  final bool actif;

  /// Mise en évidence quand il y a des cas à régler (ex. PIN manquant).
  final bool alerte;
  final VoidCallback onTap;

  const _Tuile({
    required this.icone,
    required this.couleur,
    required this.libelle,
    required this.nombre,
    required this.actif,
    required this.alerte,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final aSignaler = alerte && nombre > 0;
    return Material(
      color: actif
          ? AppColors.rouge.withValues(alpha: 0.06)
          : aSignaler
              ? couleur.withValues(alpha: 0.05)
              : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: actif
              ? AppColors.rouge
              : aSignaler
                  ? couleur.withValues(alpha: 0.4)
                  : AppColors.grisMedium,
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
                    Text(
                      '$nombre',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: aSignaler ? couleur : AppColors.noir,
                        height: 1.1,
                      ),
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

// ── Tableau ────────────────────────────────────────────────

const _styleEnTete = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.grisDark,
);

class _TableauResidents extends StatelessWidget {
  final List<Resident> lignes;
  final int premierNumero;
  final _Tri tri;
  final bool croissant;
  final ValueChanged<_Tri> onTrier;
  final ValueChanged<Resident> onPin;
  final ValueChanged<Resident> onDesactiver;
  final ValueChanged<Resident> onActiver;
  final ValueChanged<Resident> onBasculerApplication;

  const _TableauResidents({
    required this.lignes,
    required this.premierNumero,
    required this.tri,
    required this.croissant,
    required this.onTrier,
    required this.onPin,
    required this.onDesactiver,
    required this.onActiver,
    required this.onBasculerApplication,
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
                    width: 40, child: Text('N°', style: _styleEnTete)),
                Expanded(flex: 4, child: entete('Résident', _Tri.nom)),
                Expanded(
                    flex: 3, child: entete('Appartement', _Tri.appartement)),
                Expanded(flex: 2, child: entete('Application', _Tri.statut)),
                const Expanded(
                    flex: 2, child: Text('PIN', style: _styleEnTete)),
                const SizedBox(width: 48),
              ],
            ),
          ),
          for (final (i, r) in lignes.indexed) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.grisMedium),
            _LigneResident(
              resident: r,
              numero: premierNumero + i,
              onPin: () => onPin(r),
              onDesactiver: () => onDesactiver(r),
              onActiver: () => onActiver(r),
              onBasculerApplication: () => onBasculerApplication(r),
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
              Text(libelle, style: _styleEnTete.copyWith(color: couleur)),
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

class _LigneResident extends StatelessWidget {
  final Resident resident;
  final int numero;
  final VoidCallback onPin;
  final VoidCallback onDesactiver;
  final VoidCallback onActiver;
  final VoidCallback onBasculerApplication;

  const _LigneResident({
    required this.resident,
    required this.numero,
    required this.onPin,
    required this.onDesactiver,
    required this.onActiver,
    required this.onBasculerApplication,
  });

  @override
  Widget build(BuildContext context) {
    final r = resident;
    const style = TextStyle(fontSize: 13, color: AppColors.noir);
    return Container(
      color: r.isActif ? null : AppColors.grisLight.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('$numero', style: style)),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                AvatarResident(resident: r),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.nomComplet,
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(
                      fontWeight: FontWeight.w600,
                      color: r.isActif ? AppColors.noir : AppColors.grisDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: r.numeroAppartement == null
                ? const Text('—',
                    style: TextStyle(fontSize: 13, color: AppColors.grisText))
                : Row(
                    children: [
                      Text('Apt ${r.numeroAppartement}',
                          style: style.copyWith(fontWeight: FontWeight.w600)),
                      if (r.tailleAppartement != null) ...[
                        const SizedBox(width: 6),
                        BadgeTaille(taille: r.tailleAppartement!),
                      ],
                    ],
                  ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: BadgeApplicationResident(resident: r),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: BadgePinResident(resident: r),
            ),
          ),
          SizedBox(
            width: 48,
            child: MenuResident(
              resident: r,
              onPin: onPin,
              onDesactiver: onDesactiver,
              onActiver: onActiver,
              onBasculerApplication: onBasculerApplication,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grille ─────────────────────────────────────────────────

class _GrilleResidents extends StatelessWidget {
  final List<Resident> lignes;
  final ValueChanged<Resident> onPin;
  final ValueChanged<Resident> onDesactiver;
  final ValueChanged<Resident> onActiver;
  final ValueChanged<Resident> onBasculerApplication;

  const _GrilleResidents({
    required this.lignes,
    required this.onPin,
    required this.onDesactiver,
    required this.onActiver,
    required this.onBasculerApplication,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      final colonnes = math.max(1, (c.maxWidth + ecart) ~/ (320 + ecart));
      final largeur = (c.maxWidth - ecart * (colonnes - 1)) / colonnes;
      return Wrap(
        spacing: ecart,
        runSpacing: ecart,
        children: [
          for (final r in lignes)
            SizedBox(
              width: largeur,
              child: ResidentListItem(
                key: ValueKey(r.id),
                resident: r,
                onPin: () => onPin(r),
                onDesactiver: () => onDesactiver(r),
                onActiver: () => onActiver(r),
                onBasculerApplication: () => onBasculerApplication(r),
              ),
            ),
        ],
      );
    });
  }
}

// ── État vide ──────────────────────────────────────────────

class _EtatVide extends StatelessWidget {
  final VoidCallback onAdd;
  const _EtatVide({required this.onAdd});

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
            child: const Icon(Icons.people_alt_rounded,
                size: 48, color: AppColors.rouge),
          ),
          const SizedBox(height: AppSizes.md),
          const Text(
            'Aucun résident',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.noir),
          ),
          const SizedBox(height: AppSizes.sm),
          const Text(
            'Ajoutez les occupants des appartements\npour leur donner accès à leur espace.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisDark, height: 1.5),
          ),
          const SizedBox(height: AppSizes.lg),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Ajouter un résident'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rouge,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
