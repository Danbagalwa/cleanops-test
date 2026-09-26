import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/dialogue_app.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/export_menu_button.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pdf/domain/usecases/generate_employes_export.dart';
import '../../../pdf/presentation/screens/employes_pdf_preview_screen.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';
import '../../domain/usecases/add_employe.dart';
import '../../domain/usecases/update_employe.dart';
import '../providers/employes_provider.dart';
import '../widgets/employe_form_widget.dart';
import '../widgets/employe_list_item.dart';

const _kRolesFiltres = [
  RoleType.employe,
  RoleType.superviseurMenage,
  RoleType.reception,
  RoleType.direction,
];

enum _Statut { tous, actifs, inactifs }

enum _Tri { nom, role, statut }

class EmployesScreen extends ConsumerStatefulWidget {
  const EmployesScreen({super.key});

  @override
  ConsumerState<EmployesScreen> createState() => _EmployesScreenState();
}

class _EmployesScreenState extends ConsumerState<EmployesScreen> {
  final _searchCtrl = TextEditingController();
  String _recherche = '';
  RoleType? _role;
  _Statut _statut = _Statut.tous;
  _Tri _tri = _Tri.nom;
  bool _croissant = true;
  int _page = 0;
  int _parPage = 10;

  /// `null` : choisi selon la largeur (grille sur téléphone, tableau sinon).
  ModeAffichage? _mode;

  @override
  void initState() {
    super.initState();
    Future.microtask(_charger);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() =>
      ref.read(employesNotifierProvider.notifier).charger();

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
      _role = null;
      _statut = _Statut.tous;
    });
  }

  bool _duStatut(Employee e) => switch (_statut) {
        _Statut.tous => true,
        _Statut.actifs => e.isActif,
        _Statut.inactifs => !e.isActif,
      };

  List<Employee> _lignes(List<Employee> tous) {
    final q = _recherche.trim().toLowerCase();
    int parNom(Employee a, Employee b) =>
        a.nomComplet.toLowerCase().compareTo(b.nomComplet.toLowerCase());
    int sens(int c) => _croissant ? c : -c;
    return tous.where((e) {
      if (_role != null && e.role != _role) return false;
      if (!_duStatut(e)) return false;
      return q.isEmpty ||
          e.nomComplet.toLowerCase().contains(q) ||
          (e.numeroPointeuse?.contains(q) ?? false);
    }).toList()
      ..sort((a, b) {
        final c = switch (_tri) {
          _Tri.nom => 0,
          _Tri.role => roleDisplay(a.role).compareTo(roleDisplay(b.role)),
          _Tri.statut => (a.isActif ? 0 : 1).compareTo(b.isActif ? 0 : 1),
        };
        return c != 0
            ? sens(c)
            : (_tri == _Tri.nom ? sens(parNom(a, b)) : parNom(a, b));
      });
  }

  String _descriptionFiltres() {
    final filtres = <String>[
      if (_recherche.trim().isNotEmpty) 'Recherche : "${_recherche.trim()}"',
      if (_role != null) 'Rôle : ${roleDisplay(_role!)}',
      if (_statut == _Statut.actifs) 'Statut : actifs',
      if (_statut == _Statut.inactifs) 'Statut : inactifs',
    ];
    return filtres.isEmpty ? 'Tous les employés' : filtres.join(' · ');
  }

  // ── Actions ────────────────────────────────────────────

  void _ouvrirFormulaire({Employee? employe}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormDialog(employe: employe),
    );
  }

  Future<void> _confirmerToggle(Employee emp) async {
    final desactiver = emp.isActif;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogueApp(
        titre: desactiver ? 'Désactiver l’employé' : 'Activer l’employé',
        largeur: 440,
        libelleAction: desactiver ? 'Désactiver' : 'Activer',
        libelleSecondaire: 'Annuler',
        onFermer: () => Navigator.of(ctx).pop(false),
        onAction: () => Navigator.of(ctx).pop(true),
        contenu: Text(
          desactiver
              ? '${emp.nomComplet} ne sera plus affiché dans le planning.'
              : '${emp.nomComplet} sera à nouveau disponible dans le planning.',
          style: const TextStyle(
              fontSize: 14, height: 1.4, color: AppColors.grisDark),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final succes = await ref
        .read(employesNotifierProvider.notifier)
        .toggleActif(emp.id, isActif: !emp.isActif);
    if (!mounted) return;
    if (succes) {
      NotificationApp.succes(
        context,
        desactiver
            ? '${emp.nomComplet} a été désactivé(e).'
            : '${emp.nomComplet} a été réactivé(e).',
      );
    } else {
      AppFeedback.showError(
          context, ref.read(employesNotifierProvider).error ?? 'Échec.');
    }
  }

  VoidCallback? _planning(Employee e) => e.role == RoleType.employe
      ? () => context.go('${AppRoutes.planning}?employeeId=${e.id}')
      : null;

  void _exporterPdf(List<Employee> lignes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmployesPdfPreviewScreen(
          employees: lignes,
          filterDescription: _descriptionFiltres(),
          generatedBy:
              ref.read(employeeCourantProvider)?.nomComplet ?? 'CleanOps',
        ),
      ),
    );
  }

  void _exporterExcel(List<Employee> lignes) {
    try {
      const GenerateEmployesExcel()(
        employees: lignes,
        filterDescription: _descriptionFiltres(),
      );
      showExportSuccess(
          context, 'La liste Excel des employés a été téléchargée.');
    } catch (error) {
      AppFeedback.showError(context, error);
    }
  }

  // ── Construction ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employesNotifierProvider);
    final compact = estCompact(context);
    final mode =
        compact ? ModeAffichage.grille : (_mode ?? ModeAffichage.tableau);
    final marge = compact ? 12.0 : 24.0;

    final tous = state.employes;
    final actifs = tous.where((e) => e.isActif).length;
    final lignes = _lignes(tous);
    final nbPages = lignes.isEmpty ? 1 : ((lignes.length - 1) ~/ _parPage) + 1;
    final page = _page.clamp(0, nbPages - 1);
    final visibles = lignes.skip(page * _parPage).take(_parPage).toList();

    FiltreSection filtre(_Statut s, IconData icone, String info) =>
        FiltreSection(
          icone: icone,
          infoBulle: info,
          actif: _statut == s,
          onTap: () => _changer(() => _statut = s),
        );

    final recherche = ChampRecherche(
      controller: _searchCtrl,
      indice: 'Rechercher par nom ou n° de pointeuse',
      onChanged: (v) => _changer(() => _recherche = v),
    );
    final ajouter = FilledButton.icon(
      onPressed: () => _ouvrirFormulaire(),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.rouge,
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      icon: const Icon(Icons.person_add_rounded, size: 18),
      label: Text(compact ? 'Ajouter' : 'Ajouter un employé'),
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
      corps = _EtatVide(onAdd: () => _ouvrirFormulaire());
    } else if (lignes.isEmpty) {
      corps = CarteContenu(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          children: [
            const Text(
              'Aucun employé ne correspond à votre recherche ou filtre.',
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
            _TableauEmployes(
              lignes: visibles,
              premierNumero: page * _parPage + 1,
              tri: _tri,
              croissant: _croissant,
              onTrier: _trier,
              onModifier: (e) => _ouvrirFormulaire(employe: e),
              onToggle: _confirmerToggle,
              onPlanning: _planning,
            )
          else
            _GrilleEmployes(
              lignes: visibles,
              onModifier: (e) => _ouvrirFormulaire(employe: e),
              onToggle: _confirmerToggle,
              onPlanning: _planning,
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
        icone: Icons.badge_rounded,
        titre: 'Employés',
        sousTitre: tous.isEmpty
            ? 'Équipe de la résidence'
            : 'Équipe de la résidence — ${tous.length} employés, '
                '$actifs actif${actifs > 1 ? 's' : ''}',
      ),
      contenu: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _charger,
        child: ListView(
          padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
              .plusBarre(context),
          children: [
            BarreSection(
              titre: 'Employés (${lignes.length})',
              onRetour: () => context.backOrHome(AppRoutes.employerDashboard),
              filtres: [
                filtre(_Statut.tous, Icons.groups_rounded, 'Tous les employés'),
                filtre(_Statut.actifs, Icons.person_rounded, 'Actifs'),
                filtre(_Statut.inactifs, Icons.person_off_outlined, 'Inactifs'),
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
              _FiltreRoles(
                employes: tous.where(_duStatut).toList(),
                selection: _role,
                onChanged: (r) => _changer(() => _role = r),
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

// ── Filtre par rôle (avec effectifs) ───────────────────────

class _FiltreRoles extends StatelessWidget {
  final List<Employee> employes;
  final RoleType? selection;
  final ValueChanged<RoleType?> onChanged;

  const _FiltreRoles({
    required this.employes,
    required this.selection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tuiles = [
      _TuileRole(
        icone: Icons.groups_rounded,
        couleur: AppColors.rouge,
        libelle: 'Tous les rôles',
        nombre: employes.length,
        actif: selection == null,
        onTap: () => onChanged(null),
      ),
      for (final r in _kRolesFiltres)
        _TuileRole(
          icone: _iconeRole(r),
          couleur: roleColor(r),
          libelle: roleDisplay(r),
          nombre: employes.where((e) => e.role == r).length,
          actif: selection == r,
          onTap: () => onChanged(selection == r ? null : r),
        ),
    ];

    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      const minimum = 150.0;
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

IconData _iconeRole(RoleType r) => switch (r) {
      RoleType.employe => Icons.cleaning_services_rounded,
      RoleType.superviseurMenage => Icons.supervisor_account_rounded,
      RoleType.reception => Icons.support_agent_rounded,
      RoleType.direction => Icons.business_center_rounded,
      _ => Icons.person_rounded,
    };

class _TuileRole extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String libelle;
  final int nombre;
  final bool actif;
  final VoidCallback onTap;

  const _TuileRole({
    required this.icone,
    required this.couleur,
    required this.libelle,
    required this.nombre,
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
                    Text(
                      '$nombre',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.noir,
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

class _TableauEmployes extends StatelessWidget {
  final List<Employee> lignes;
  final int premierNumero;
  final _Tri tri;
  final bool croissant;
  final ValueChanged<_Tri> onTrier;
  final ValueChanged<Employee> onModifier;
  final ValueChanged<Employee> onToggle;
  final VoidCallback? Function(Employee) onPlanning;

  const _TableauEmployes({
    required this.lignes,
    required this.premierNumero,
    required this.tri,
    required this.croissant,
    required this.onTrier,
    required this.onModifier,
    required this.onToggle,
    required this.onPlanning,
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
                Expanded(flex: 4, child: entete('Employé', _Tri.nom)),
                Expanded(flex: 3, child: entete('Rôle', _Tri.role)),
                const Expanded(
                    flex: 2, child: Text('Pointeuse', style: _styleEnTete)),
                Expanded(flex: 2, child: entete('Statut', _Tri.statut)),
                const SizedBox(width: 48),
              ],
            ),
          ),
          for (final (i, e) in lignes.indexed) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.grisMedium),
            _LigneEmploye(
              employe: e,
              numero: premierNumero + i,
              onModifier: () => onModifier(e),
              onToggle: () => onToggle(e),
              onPlanning: onPlanning(e),
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

class _LigneEmploye extends StatelessWidget {
  final Employee employe;
  final int numero;
  final VoidCallback onModifier;
  final VoidCallback onToggle;
  final VoidCallback? onPlanning;

  const _LigneEmploye({
    required this.employe,
    required this.numero,
    required this.onModifier,
    required this.onToggle,
    required this.onPlanning,
  });

  @override
  Widget build(BuildContext context) {
    final e = employe;
    final couleur = roleColor(e.role);
    const style = TextStyle(fontSize: 13, color: AppColors.noir);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onModifier,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 40, child: Text('$numero', style: style)),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Opacity(
                      opacity: e.isActif ? 1 : 0.5,
                      child: AvatarProfil(
                        proprietaire: ProprietairePhoto.de(e),
                        initiales: initialesEmploye(e),
                        rayon: 16,
                        couleurFond: couleur.withValues(alpha: 0.15),
                        couleurTexte: couleur,
                        tailleTexte: 12,
                        poidsTexte: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.nomComplet,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              e.isActif ? AppColors.noir : AppColors.grisDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BadgeRole(role: e.role),
                ),
              ),
              Expanded(
                flex: 2,
                child: e.numeroPointeuse == null
                    ? const Text('—',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.grisText))
                    : Row(
                        children: [
                          const Icon(Icons.fingerprint_rounded,
                              size: 14, color: AppColors.grisText),
                          const SizedBox(width: 4),
                          Text(e.numeroPointeuse!,
                              style: style.copyWith(color: AppColors.grisDark)),
                        ],
                      ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BadgeStatutEmploye(actif: e.isActif),
                ),
              ),
              SizedBox(
                width: 48,
                child: MenuEmploye(
                  employe: e,
                  onEdit: onModifier,
                  onToggleActif: onToggle,
                  onPlanning: onPlanning,
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

class _GrilleEmployes extends StatelessWidget {
  final List<Employee> lignes;
  final ValueChanged<Employee> onModifier;
  final ValueChanged<Employee> onToggle;
  final VoidCallback? Function(Employee) onPlanning;

  const _GrilleEmployes({
    required this.lignes,
    required this.onModifier,
    required this.onToggle,
    required this.onPlanning,
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
          for (final e in lignes)
            SizedBox(
              width: largeur,
              child: EmployeListItem(
                employe: e,
                onEdit: () => onModifier(e),
                onToggleActif: () => onToggle(e),
                onPlanning: onPlanning(e),
              ),
            ),
        ],
      );
    });
  }
}

// ── Dialog formulaire ─────────────────────────────────────

class _FormDialog extends ConsumerWidget {
  final Employee? employe;
  const _FormDialog({this.employe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      employesNotifierProvider.select((s) => s.isLoading),
    );

    return EmployeFormWidget(
      employe: employe,
      isLoading: isLoading,
      canEditNumeroPointeuse: ref.watch(roleActuelProvider) == RoleType.admin,
      onSave: ({
        required String nom,
        required String prenom,
        required RoleType role,
        String? numeroPointeuse,
        String? motDePasse,
        required bool isActif,
      }) async {
        final notifier = ref.read(employesNotifierProvider.notifier);
        final bool ok;

        if (employe == null) {
          ok = await notifier.ajouter(AddEmployeParams(
            nom: nom,
            prenom: prenom,
            role: role,
            numeroPointeuse: numeroPointeuse,
            motDePasse: motDePasse,
          ));
        } else {
          ok = await notifier.modifier(UpdateEmployeParams(
            id: employe!.id,
            nom: nom,
            prenom: prenom,
            role: role,
            isActif: isActif,
            numeroPointeuse: numeroPointeuse,
            motDePasse: motDePasse,
          ));
        }

        if (!context.mounted) return;
        if (ok) {
          Navigator.of(context).pop();
          NotificationApp.succes(
            context,
            employe == null
                ? '$prenom $nom a été ajouté(e) à l’équipe.'
                : 'Les informations de $prenom $nom ont été enregistrées.',
          );
        } else {
          final error = ref.read(employesNotifierProvider).error;
          if (error != null) AppFeedback.showError(context, error);
        }
      },
    );
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
            child: const Icon(Icons.group_rounded,
                size: 48, color: AppColors.rouge),
          ),
          const SizedBox(height: AppSizes.md),
          const Text(
            'Aucun employé',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.noir),
          ),
          const SizedBox(height: AppSizes.sm),
          const Text(
            'Ajoutez votre premier employé\npour commencer la configuration.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisDark, height: 1.5),
          ),
          const SizedBox(height: AppSizes.lg),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Ajouter un employé'),
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
