import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/semaine_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/export_menu_button.dart' show showExportSuccess;
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../photo_profil/domain/photo_profil_models.dart';
import '../../../photo_profil/presentation/widgets/avatar_profil.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../appartements/presentation/providers/appartements_provider.dart';
import '../../../employes/presentation/providers/employes_provider.dart';
import '../../../pdf/domain/usecases/generate_planning_excel.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../../domain/entities/planning_template.dart';
import '../providers/planning_provider.dart';
import '../widgets/planning_grid_widget.dart';

const _kJours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];
const _kJoursCourts = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];

/// Filtres S1 à S4 de la barre de section ; un point marque la semaine en
/// cours du cycle.
List<FiltreSection> _filtresSemaines(int active, ValueChanged<int> onChoix) {
  final courante = SemaineHelper.semaineCourante;
  return [
    for (var s = 1; s <= 4; s++)
      FiltreSection(
        libelle: 'S$s',
        infoBulle: 'Semaine $s du cycle${s == courante ? ' (en cours)' : ''}',
        actif: s == active,
        pastille: s == courante,
        onTap: () => onChoix(s),
      ),
  ];
}

String _titreSemaine(int semaine) =>
    'Semaine $semaine${semaine == SemaineHelper.semaineCourante ? ' (en cours)' : ''}';

class PlanningScreen extends ConsumerStatefulWidget {
  final String? employeeId;
  const PlanningScreen({super.key, this.employeeId});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  // null = vue équipe, non-null = vue individuelle
  String? _employeeVue;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final employee = ref.read(employeeCourantProvider);
      final isResponsable = employee?.isResponsable ?? false;

      // Appartements toujours nécessaires (dialog ajout de slot)
      final apptState = ref.read(appartementsNotifierProvider);
      if (apptState.appartements.isEmpty && !apptState.isLoading) {
        ref.read(appartementsNotifierProvider.notifier).charger();
      }

      if (!isResponsable) {
        // Préposée → toujours sa propre vue individuelle
        setState(() => _employeeVue = employee?.id);
        ref.read(planningNotifierProvider(employee?.id).notifier).charger();
      } else if (widget.employeeId != null) {
        // Responsable arrivant depuis le dashboard avec un employeeId
        setState(() => _employeeVue = widget.employeeId);
        ref.read(planningNotifierProvider(null).notifier).charger();
        final employesState = ref.read(employesNotifierProvider);
        if (employesState.employes.isEmpty && !employesState.isLoading) {
          ref.read(employesNotifierProvider.notifier).charger();
        }
      } else {
        // Responsable → vue équipe (charge tous les templates)
        ref.read(planningNotifierProvider(null).notifier).charger();
        ref.read(employesNotifierProvider.notifier).charger();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(employeeCourantProvider);
    final isResponsable = employee?.isResponsable ?? false;

    if (_employeeVue != null) {
      final employes = ref.watch(employesNotifierProvider).employes;
      final emp = employes.where((e) => e.id == _employeeVue).firstOrNull;

      return _IndividualView(
        employeeId: _employeeVue!,
        employee: emp ?? (employee?.id == _employeeVue ? employee : null),
        employeeName: emp != null
            ? '${emp.prenom} ${emp.nom}'
            : (isResponsable
                ? '...'
                : '${employee?.prenom ?? ''} ${employee?.nom ?? ''}'),
        isResponsable: isResponsable,
        providerKey: isResponsable ? null : _employeeVue,
        onBack:
            isResponsable ? () => setState(() => _employeeVue = null) : null,
      );
    }

    // Vue équipe — responsable uniquement
    return _TeamView(
      onEmployeeSelected: (emp) => setState(() => _employeeVue = emp.id),
    );
  }
}

// ══ Vue équipe ════════════════════════════════════════════

class _TeamView extends ConsumerStatefulWidget {
  final ValueChanged<Employee> onEmployeeSelected;

  const _TeamView({required this.onEmployeeSelected});

  @override
  ConsumerState<_TeamView> createState() => _TeamViewState();
}

class _TeamViewState extends ConsumerState<_TeamView> {
  String _recherche = '';
  int _page = 0;
  int _parPage = 10;

  /// `null` : choisi selon la largeur (grille sur téléphone, tableau sinon).
  ModeAffichage? _mode;

  Future<void> _recharger() async {
    await Future.wait([
      ref.read(planningNotifierProvider(null).notifier).charger(),
      ref.read(employesNotifierProvider.notifier).charger(),
    ]);
  }

  void _exporterExcel(
    List<Employee> employes,
    List<PlanningTemplate> templates,
    int semaine,
  ) {
    try {
      const GeneratePlanningExcel().team(
        employees: employes,
        templates: templates,
        numeroSemaine: semaine,
      );
      showExportSuccess(
          context, 'Le planning Excel de l’équipe a été téléchargé.');
    } catch (error) {
      AppFeedback.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planningState = ref.watch(planningNotifierProvider(null));
    final employesState = ref.watch(employesNotifierProvider);
    final semaine = planningState.semaineVue;
    final compact = estCompact(context);
    final mode =
        compact ? ModeAffichage.grille : (_mode ?? ModeAffichage.tableau);

    // Le planning ne concerne que les préposées : les autres rôles
    // (admin, réception...) n'y apparaissent pas.
    final employes = employesState.employes
        .where((e) => e.isActif && e.role == RoleType.employe)
        .toList()
      ..sort(
          (a, b) => a.prenom.toLowerCase().compareTo(b.prenom.toLowerCase()));
    final templates = planningState.templates
        .where((t) => t.numeroSemaine == semaine)
        .toList();

    final q = _recherche.trim().toLowerCase();
    final filtrees = employes
        .where((e) =>
            q.isEmpty ||
            e.prenom.toLowerCase().contains(q) ||
            e.nom.toLowerCase().contains(q))
        .toList();
    final nbPages =
        filtrees.isEmpty ? 1 : ((filtrees.length - 1) ~/ _parPage) + 1;
    final page = _page.clamp(0, nbPages - 1);
    final visibles = filtrees.skip(page * _parPage).take(_parPage).toList();
    final chargementInitial =
        planningState.isLoading && planningState.templates.isEmpty;

    final recherche = ChampRecherche(
      indice: 'Rechercher une préposée par prénom ou nom',
      onChanged: (v) => setState(() {
        _recherche = v;
        _page = 0;
      }),
    );

    Widget contenu;
    if (chargementInitial || (employesState.isLoading && employes.isEmpty)) {
      contenu = const CarteContenu(
        padding: EdgeInsets.all(AppSizes.xl),
        child: Center(child: CircularProgressIndicator(color: AppColors.rouge)),
      );
    } else if (employes.isEmpty) {
      contenu = const _Message('Aucune préposée active.');
    } else if (filtrees.isEmpty) {
      contenu =
          _Message('Aucune préposée ne correspond à « ${_recherche.trim()} ».');
    } else if (mode == ModeAffichage.tableau) {
      contenu = _TableauEquipe(
        employes: visibles,
        templates: templates,
        premierNumero: page * _parPage + 1,
        onOuvrir: widget.onEmployeeSelected,
      );
    } else {
      contenu = _GrilleEquipe(
        employes: visibles,
        templates: templates,
        onOuvrir: widget.onEmployeeSelected,
      );
    }

    return PageAvecEnTete(
      chargement: planningState.isLoading,
      enTete: EnTetePage(
        icone: Icons.calendar_month_rounded,
        titre: 'Planning équipe',
        sousTitre:
            'Cycle de 4 semaines — ${SemaineHelper.libelleSemaineCourante}',
      ),
      contenu: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _recharger,
        child: ListView(
          padding:
              const EdgeInsets.only(bottom: AppSizes.lg).plusBarre(context),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 24, AppSizes.lg, compact ? 12 : 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BarreSection(
                    titre: '${_titreSemaine(semaine)} — '
                        '${employes.length} préposée${employes.length > 1 ? 's' : ''}',
                    onRetour: () =>
                        context.backOrHome(AppRoutes.employerDashboard),
                    filtres: _filtresSemaines(
                      semaine,
                      (s) => ref
                          .read(planningNotifierProvider(null).notifier)
                          .changerSemaine(s),
                    ),
                    actions: [
                      ActionSection(
                        icone: Icons.print_rounded,
                        infoBulle: 'Imprimer ou exporter en PDF',
                        onPressed: planningState.isLoading
                            ? null
                            : () => context.push(Uri(
                                  path: '/pdf',
                                  queryParameters: {'semaine': '$semaine'},
                                ).toString()),
                      ),
                      ActionSection(
                        icone: Icons.download_rounded,
                        infoBulle: 'Télécharger en Excel',
                        onPressed: planningState.isLoading
                            ? null
                            : () => _exporterExcel(
                                employes, planningState.templates, semaine),
                      ),
                      ActionSection(
                        icone: Icons.refresh_rounded,
                        infoBulle: 'Actualiser',
                        onPressed: planningState.isLoading ? null : _recharger,
                      ),
                    ],
                  ),
                  if (planningState.error != null) ...[
                    const SizedBox(height: AppSizes.sm),
                    _ErrorBanner(planningState.error!),
                  ],
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
                  const SizedBox(height: AppSizes.md),
                  contenu,
                  const SizedBox(height: AppSizes.md),
                  BarrePagination(
                    page: page,
                    parPage: _parPage,
                    total: filtrees.length,
                    onPage: (p) => setState(() => _page = p),
                    onParPage: (n) => setState(() {
                      _parPage = n;
                      _page = 0;
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String texte;
  const _Message(this.texte);

  @override
  Widget build(BuildContext context) => CarteContenu(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Text(
          texte,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.grisDark),
        ),
      );
}

/// Créneaux d'une préposée pour un jour : AM (bleu) puis PM (jaune).
List<PlanningTemplate> _creneaux(
  List<PlanningTemplate> templates,
  String jour,
  PeriodeType periode,
) =>
    templates.where((t) => t.jour == jour && t.periode == periode).toList()
      ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));

class _CelluleJour extends StatelessWidget {
  final List<PlanningTemplate> templates;
  final String jour;

  const _CelluleJour({required this.templates, required this.jour});

  @override
  Widget build(BuildContext context) {
    final am = _creneaux(templates, jour, PeriodeType.am);
    final pm = _creneaux(templates, jour, PeriodeType.pm);
    if (am.isEmpty && pm.isEmpty) {
      return const Text('—',
          style: TextStyle(fontSize: 12, color: AppColors.grisText));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (am.isNotEmpty)
          _TeamCellGroup(slots: am, color: AppColors.absent, label: 'AM'),
        if (am.isNotEmpty && pm.isNotEmpty) const SizedBox(height: 3),
        if (pm.isNotEmpty)
          _TeamCellGroup(slots: pm, color: AppColors.aVerifier, label: 'PM'),
      ],
    );
  }
}

// ── Affichage tableau ─────────────────────────────────────

const _styleEnTete = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.grisDark,
);

class _TableauEquipe extends StatelessWidget {
  final List<Employee> employes;
  final List<PlanningTemplate> templates;
  final int premierNumero;
  final ValueChanged<Employee> onOuvrir;

  const _TableauEquipe({
    required this.employes,
    required this.templates,
    required this.premierNumero,
    required this.onOuvrir,
  });

  @override
  Widget build(BuildContext context) {
    const numW = 40.0, nomW = 180.0, actW = 48.0, marges = 32.0;

    return CarteContenu(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final jourW =
              ((constraints.maxWidth - numW - nomW - actW - marges) / 5)
                  .clamp(96.0, 240.0);
          final largeur = numW + nomW + actW + marges + jourW * 5;
          final jours = jourW >= 110 ? _kJours : _kJoursCourts;

          final table = Column(
            children: [
              Container(
                color: const Color(0xFFF7F8FA),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const SizedBox(
                        width: numW, child: Text('N°', style: _styleEnTete)),
                    const SizedBox(
                        width: nomW,
                        child: Text('Préposée', style: _styleEnTete)),
                    for (final j in jours)
                      SizedBox(
                          width: jourW, child: Text(j, style: _styleEnTete)),
                    const SizedBox(width: actW),
                  ],
                ),
              ),
              for (final (i, emp) in employes.indexed) ...[
                const Divider(
                    height: 1, thickness: 1, color: AppColors.grisMedium),
                InkWell(
                  onTap: () => onOuvrir(emp),
                  hoverColor: AppColors.rouge.withValues(alpha: 0.04),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: numW,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${premierNumero + i}',
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                        SizedBox(
                          width: nomW,
                          child: Row(
                            children: [
                              _Avatar(emp, rayon: 15),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${emp.prenom} ${emp.nom}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.noir,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final jour in _kJours)
                          SizedBox(
                            width: jourW,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6, top: 4),
                              child: _CelluleJour(
                                templates: templates
                                    .where((t) => t.employeeId == emp.id)
                                    .toList(),
                                jour: jour,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: actW,
                          child:
                              _MenuPreposee(employee: emp, onOuvrir: onOuvrir),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );

          // Défilement horizontal uniquement si l'écran est trop étroit.
          if (largeur > constraints.maxWidth + 0.5) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: largeur, child: table),
            );
          }
          return table;
        },
      ),
    );
  }
}

// ── Affichage grille ──────────────────────────────────────

class _GrilleEquipe extends StatelessWidget {
  final List<Employee> employes;
  final List<PlanningTemplate> templates;
  final ValueChanged<Employee> onOuvrir;

  const _GrilleEquipe({
    required this.employes,
    required this.templates,
    required this.onOuvrir,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const ecart = AppSizes.sm;
        final colonnes =
            math.max(1, (constraints.maxWidth + ecart) ~/ (320 + ecart));
        final largeur =
            (constraints.maxWidth - ecart * (colonnes - 1)) / colonnes;
        return Wrap(
          spacing: ecart,
          runSpacing: ecart,
          children: [
            for (final emp in employes)
              SizedBox(
                width: largeur,
                child: _CartePreposee(
                  employee: emp,
                  templates:
                      templates.where((t) => t.employeeId == emp.id).toList(),
                  onOuvrir: onOuvrir,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CartePreposee extends StatelessWidget {
  final Employee employee;
  final List<PlanningTemplate> templates;
  final ValueChanged<Employee> onOuvrir;

  const _CartePreposee({
    required this.employee,
    required this.templates,
    required this.onOuvrir,
  });

  @override
  Widget build(BuildContext context) {
    final nbAppts = templates.map((t) => t.appartementId).toSet().length;
    return CarteContenu(
      child: InkWell(
        onTap: () => onOuvrir(employee),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(employee, rayon: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${employee.prenom} ${employee.nom}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.noir,
                          ),
                        ),
                        Text(
                          nbAppts == 0
                              ? 'Aucun appartement cette semaine'
                              : '$nbAppts appartement${nbAppts > 1 ? 's' : ''} cette semaine',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.grisDark),
                        ),
                      ],
                    ),
                  ),
                  _MenuPreposee(employee: employee, onOuvrir: onOuvrir),
                ],
              ),
              const Divider(height: 20, color: AppColors.grisMedium),
              for (final (i, jour) in _kJours.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          _kJoursCourts[i],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.grisDark,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _CelluleJour(templates: templates, jour: jour),
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

class _Avatar extends StatelessWidget {
  final Employee employee;
  final double rayon;

  const _Avatar(this.employee, {required this.rayon});

  @override
  Widget build(BuildContext context) {
    final e = employee;
    return AvatarProfil(
      proprietaire: ProprietairePhoto.de(e),
      initiales:
          '${e.prenom.isNotEmpty ? e.prenom[0] : ''}${e.nom.isNotEmpty ? e.nom[0] : ''}',
      rayon: rayon,
      couleurFond: AppColors.rouge.withValues(alpha: 0.12),
      couleurTexte: AppColors.rouge,
      tailleTexte: rayon * 0.75,
      poidsTexte: FontWeight.bold,
    );
  }
}

enum _ActionPreposee { ouvrir, pdf }

/// Actions d'une préposée (⋮) : ouvrir son planning, l'exporter en PDF.
class _MenuPreposee extends StatelessWidget {
  final Employee employee;
  final ValueChanged<Employee> onOuvrir;

  const _MenuPreposee({required this.employee, required this.onOuvrir});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ActionPreposee>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.rouge),
      onSelected: (a) {
        switch (a) {
          case _ActionPreposee.ouvrir:
            onOuvrir(employee);
          case _ActionPreposee.pdf:
            context.push(Uri(
              path: '/pdf',
              queryParameters: {'employeeId': employee.id},
            ).toString());
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _ActionPreposee.ouvrir,
          child: Text('Voir et modifier son planning'),
        ),
        PopupMenuItem(
          value: _ActionPreposee.pdf,
          child: Text('Exporter son planning en PDF'),
        ),
      ],
    );
  }
}

class _TeamCellGroup extends StatelessWidget {
  final List<PlanningTemplate> slots;
  final Color color;
  final String label;

  const _TeamCellGroup({
    required this.slots,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Wrap(
        spacing: 3,
        runSpacing: 2,
        children: slots.map((t) {
          final numero = t.appartement?.numero ?? '?';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              numero,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══ Vue individuelle ══════════════════════════════════════

class _IndividualView extends ConsumerStatefulWidget {
  final String employeeId;
  final Employee? employee;
  final String employeeName;
  final bool isResponsable;
  final String? providerKey;
  final VoidCallback? onBack;

  const _IndividualView({
    required this.employeeId,
    required this.employee,
    required this.employeeName,
    required this.isResponsable,
    required this.providerKey,
    this.onBack,
  });

  @override
  ConsumerState<_IndividualView> createState() => _IndividualViewState();
}

class _IndividualViewState extends ConsumerState<_IndividualView> {
  int _semaine = SemaineHelper.semaineCourante;

  void _exporterExcel(List<PlanningTemplate> templates) {
    final selectedEmployee = widget.employee;
    if (selectedEmployee == null) {
      AppFeedback.showError(
        context,
        'Les informations de cet employé sont encore en cours de '
        'chargement. Réessayez dans un instant.',
      );
      return;
    }
    try {
      const GeneratePlanningExcel().employee(
        employee: selectedEmployee,
        templates: templates,
      );
      showExportSuccess(
          context, 'Le planning Excel personnel a été téléchargé.');
    } catch (error) {
      AppFeedback.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planningState =
        ref.watch(planningNotifierProvider(widget.providerKey));
    final compact = estCompact(context);
    final marge = compact ? 12.0 : 24.0;

    Widget grille;
    if (planningState.isLoading && planningState.templates.isEmpty) {
      grille = const AppSkeletonGrid();
    } else if (planningState.error != null && planningState.templates.isEmpty) {
      grille = _ErrorState(
        message: planningState.error!,
        onRetry: () => ref
            .read(planningNotifierProvider(widget.providerKey).notifier)
            .charger(),
      );
    } else {
      grille = CarteContenu(
        child: PlanningGridWidget(
          employeeId: widget.employeeId,
          numeroSemaine: _semaine,
          canEdit: widget.isResponsable,
          providerKey: widget.providerKey,
        ),
      );
    }

    return PageAvecEnTete(
      chargement: planningState.isLoading,
      enTete: EnTetePage(
        icone: Icons.calendar_month_rounded,
        titre: widget.isResponsable
            ? 'Planning de ${widget.employeeName}'
            : 'Mon planning',
        sousTitre:
            'Cycle de 4 semaines — ${SemaineHelper.libelleSemaineCourante}',
      ),
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
                EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.md),
            child: BarreSection(
              titre: _titreSemaine(_semaine),
              onRetour: widget.onBack,
              filtres: _filtresSemaines(
                  _semaine, (s) => setState(() => _semaine = s)),
              actions: [
                ActionSection(
                  icone: Icons.print_rounded,
                  infoBulle: 'Imprimer ou exporter en PDF',
                  onPressed: planningState.isLoading
                      ? null
                      : () => context.push(Uri(
                            path: '/pdf',
                            queryParameters: {'employeeId': widget.employeeId},
                          ).toString()),
                ),
                ActionSection(
                  icone: Icons.download_rounded,
                  infoBulle: 'Télécharger en Excel',
                  onPressed: planningState.isLoading
                      ? null
                      : () => _exporterExcel(planningState.templates),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: marge),
              child: grille,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.rouge),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.rouge),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: AppErrorNotice(error: message, onRetry: onRetry),
      ),
    );
  }
}
