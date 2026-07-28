import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/semaine_helper.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../appartements/presentation/providers/appartements_provider.dart';
import '../../../employes/presentation/providers/employes_provider.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../../domain/entities/planning_template.dart';
import '../providers/planning_provider.dart';
import '../widgets/planning_grid_widget.dart';

const _kJours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];
const _kJoursCourts = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];

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
        employeeName: emp != null
            ? '${emp.prenom} ${emp.nom}'
            : (isResponsable ? '...' : '${employee?.prenom ?? ''} ${employee?.nom ?? ''}'),
        isResponsable: isResponsable,
        providerKey: isResponsable ? null : _employeeVue,
        onBack: isResponsable
            ? () => setState(() => _employeeVue = null)
            : null,
      );
    }

    // Vue équipe — responsable uniquement
    return _TeamView(
      onEmployeeSelected: (emp) {
        setState(() => _employeeVue = emp.id);
      },
    );
  }
}

// ── Vue équipe ────────────────────────────────────────────
class _TeamView extends ConsumerWidget {
  final ValueChanged<Employee> onEmployeeSelected;

  const _TeamView({required this.onEmployeeSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planningState = ref.watch(planningNotifierProvider(null));
    final employesState = ref.watch(employesNotifierProvider);
    final semaineCourante = SemaineHelper.semaineCourante;
    final semaine = planningState.semaineVue;
    final employes =
        employesState.employes.where((e) => e.isActif).toList();

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Planning équipe',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              SemaineHelper.libelleSemaineCourante,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Sélecteur de semaine du cycle ──────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
            child: Row(
              children: [
                const Text(
                  'Semaine cycle :',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grisDark,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                ...List.generate(4, (i) {
                  final s = i + 1;
                  final isCurrent = s == semaineCourante;
                  final isSelected = s == semaine;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => ref
                          .read(planningNotifierProvider(null).notifier)
                          .changerSemaine(s),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 40,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.rouge
                              : AppColors.grisLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrent && !isSelected
                                ? AppColors.rouge
                                : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'S$s',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : isCurrent
                                    ? AppColors.rouge
                                    : AppColors.grisDark,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                if (planningState.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.rouge,
                    ),
                  ),
              ],
            ),
          ),

          if (planningState.error != null)
            _ErrorBanner(planningState.error!),

          // ── Tableau ────────────────────────────────────
          Expanded(
            child: planningState.isLoading && planningState.templates.isEmpty
                ? const AppSkeletonGrid()
                : employes.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun employé actif.',
                          style: TextStyle(color: AppColors.grisText),
                        ),
                      )
                    : _TeamTable(
                        employes: employes,
                        templates: planningState.templates
                            .where((t) => t.numeroSemaine == semaine)
                            .toList(),
                        onEmployeeSelected: onEmployeeSelected,
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Tableau équipe ────────────────────────────────────────
class _TeamTable extends StatelessWidget {
  final List<Employee> employes;
  final List<PlanningTemplate> templates;
  final ValueChanged<Employee> onEmployeeSelected;

  const _TeamTable({
    required this.employes,
    required this.templates,
    required this.onEmployeeSelected,
  });

  @override
  Widget build(BuildContext context) {
    const double nameWidth = 150.0;
    const double minDayWidth = 90.0;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Container(
            // Remplit toute la largeur disponible (jusqu'à 1100 px) et toute
            // la hauteur, afin que LayoutBuilder reçoive des contraintes serrées
            // et que Expanded(ListView) fonctionne correctement.
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.grisMedium),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Largeur des colonnes jours calculée pour remplir exactement
                // l'espace disponible, avec un minimum pour rester lisible.
                final dayWidth = ((constraints.maxWidth - nameWidth) / 5)
                    .clamp(minDayWidth, 200.0);
                final tableWidth = nameWidth + dayWidth * 5;
                // Défilement horizontal uniquement si l'écran est trop étroit
                final needsScroll = tableWidth > constraints.maxWidth + 0.5;

                final table = Column(
                  children: [
                    _TeamHeaderRow(
                        nameWidth: nameWidth, dayWidth: dayWidth),
                    const Divider(
                        height: 1, thickness: 1, color: AppColors.grisMedium),
                    Expanded(
                      child: ListView.separated(
                        itemCount: employes.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.grisMedium,
                        ),
                        itemBuilder: (context, i) {
                          final emp = employes[i];
                          final empTemplates = templates
                              .where((t) => t.employeeId == emp.id)
                              .toList();
                          return _TeamEmployeeRow(
                            employee: emp,
                            templates: empTemplates,
                            nameWidth: nameWidth,
                            dayWidth: dayWidth,
                            onTap: () => onEmployeeSelected(emp),
                          );
                        },
                      ),
                    ),
                  ],
                );

                if (needsScroll) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: tableWidth, child: table),
                  );
                }
                return table;
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamHeaderRow extends StatelessWidget {
  final double nameWidth;
  final double dayWidth;

  const _TeamHeaderRow({required this.nameWidth, required this.dayWidth});

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.grisText,
      letterSpacing: 0.3,
    );

    return Container(
      color: AppColors.grisLight,
      child: Row(
        children: [
          SizedBox(
            width: nameWidth,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('EMPLOYÉE', style: labelStyle),
            ),
          ),
          ..._kJoursCourts.map(
            (j) => SizedBox(
              width: dayWidth,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(j.toUpperCase(), style: labelStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamEmployeeRow extends StatelessWidget {
  final Employee employee;
  final List<PlanningTemplate> templates;
  final double nameWidth;
  final double dayWidth;
  final VoidCallback onTap;

  const _TeamEmployeeRow({
    required this.employee,
    required this.templates,
    required this.nameWidth,
    required this.dayWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.rouge.withValues(alpha: 0.04),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom
          SizedBox(
            width: nameWidth,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        AppColors.rouge.withValues(alpha: 0.12),
                    child: Text(
                      '${employee.prenom.isNotEmpty ? employee.prenom[0] : ''}${employee.nom.isNotEmpty ? employee.nom[0] : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.rouge,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      employee.prenom,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.noir,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Cellules jours
          ..._kJours.map((jour) {
            final amSlots = templates
                .where((t) =>
                    t.jour == jour &&
                    t.periode == PeriodeType.am)
                .toList()
              ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));
            final pmSlots = templates
                .where((t) =>
                    t.jour == jour &&
                    t.periode == PeriodeType.pm)
                .toList()
              ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));

            return SizedBox(
              width: dayWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (amSlots.isNotEmpty)
                      _TeamCellGroup(
                        slots: amSlots,
                        color: AppColors.absent,
                        label: 'AM',
                      ),
                    if (amSlots.isNotEmpty && pmSlots.isNotEmpty)
                      const SizedBox(height: 3),
                    if (pmSlots.isNotEmpty)
                      _TeamCellGroup(
                        slots: pmSlots,
                        color: AppColors.aVerifier,
                        label: 'PM',
                      ),
                    if (amSlots.isEmpty && pmSlots.isEmpty)
                      const Text(
                        '—',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.grisMedium,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
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
    return Wrap(
      spacing: 3,
      runSpacing: 2,
      children: slots.map((t) {
        final numero = t.appartement?.numero ?? '?';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            numero,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Vue individuelle ──────────────────────────────────────
class _IndividualView extends ConsumerWidget {
  final String employeeId;
  final String employeeName;
  final bool isResponsable;
  final String? providerKey;
  final VoidCallback? onBack;

  const _IndividualView({
    required this.employeeId,
    required this.employeeName,
    required this.isResponsable,
    required this.providerKey,
    this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planningState = ref.watch(planningNotifierProvider(providerKey));

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        elevation: 0,
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: onBack,
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              employeeName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              'Planning — cycle 4 semaines',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (planningState.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: AppSizes.md),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: planningState.isLoading && planningState.templates.isEmpty
          ? const AppSkeletonGrid()
          : planningState.error != null && planningState.templates.isEmpty
              ? _ErrorState(
                  message: planningState.error!,
                  onRetry: () => ref
                      .read(planningNotifierProvider(providerKey).notifier)
                      .charger(),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: PlanningGridWidget(
                      employeeId: employeeId,
                      canEdit: isResponsable,
                      providerKey: providerKey,
                    ),
                  ),
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
      color: AppColors.rouge.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: 6,
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
