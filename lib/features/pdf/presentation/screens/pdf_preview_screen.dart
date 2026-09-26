import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/widgets/lecteur_pdf.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employes/presentation/providers/employes_provider.dart';
import '../../../planning/domain/entities/planning_template.dart';
import '../../../planning/presentation/providers/planning_provider.dart';
import '../../domain/usecases/generate_pdf_all.dart';
import '../../domain/usecases/generate_pdf_employee.dart';

class PdfPreviewScreen extends ConsumerStatefulWidget {
  final String? employeeId;
  final int? numeroSemaine;

  const PdfPreviewScreen({
    super.key,
    this.employeeId,
    this.numeroSemaine,
  });

  bool get isIndividual => employeeId != null;

  @override
  ConsumerState<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends ConsumerState<PdfPreviewScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  Future<void> _loadData() async {
    final providerKey = widget.employeeId;
    final planningState = ref.read(planningNotifierProvider(providerKey));
    final employeesState = ref.read(employesNotifierProvider);

    final futures = <Future<void>>[];
    if (planningState.templates.isEmpty && !planningState.isLoading) {
      futures.add(
        ref.read(planningNotifierProvider(providerKey).notifier).charger(),
      );
    }
    if (employeesState.employes.isEmpty && !employeesState.isLoading) {
      futures.add(ref.read(employesNotifierProvider.notifier).charger());
    }
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    final providerKey = widget.employeeId;
    final planningState = ref.watch(planningNotifierProvider(providerKey));
    final employeesState = ref.watch(employesNotifierProvider);
    final currentEmployee = ref.watch(employeeCourantProvider);
    final isLoading = planningState.isLoading || employeesState.isLoading;
    final error = planningState.error ?? employeesState.error;
    final employee = widget.isIndividual
        ? _findEmployee(
            employeesState.employes,
            widget.employeeId!,
            currentEmployee,
          )
        : null;

    return LecteurPdf(
      titre:
          widget.isIndividual ? 'Planning personnel' : 'Planning de l’équipe',
      sousTitre: widget.isIndividual
          ? (employee?.nomComplet ?? 'Préparation du document…')
          : 'Semaine ${widget.numeroSemaine ?? 1} du cycle',
      icone: Icons.calendar_month_rounded,
      nomFichier: _fileName(employee),
      format:
          widget.isIndividual ? PdfPageFormat.a4 : PdfPageFormat.a4.landscape,
      chargement: isLoading,
      erreur: error ??
          (widget.isIndividual && employee == null
              ? 'Cet employé est introuvable. Revenez au planning '
                  'et sélectionnez-le à nouveau.'
              : null),
      onReessayer: _loadData,
      generer: () => _buildDocument(
        currentEmployee: currentEmployee,
        selectedEmployee: employee,
        employees: employeesState.employes,
        templates: planningState.templates,
      ),
    );
  }

  Future<Uint8List> _buildDocument({
    required Employee? currentEmployee,
    required Employee? selectedEmployee,
    required List<Employee> employees,
    required List<PlanningTemplate> templates,
  }) {
    final generatedBy = currentEmployee?.nomComplet ?? 'CleanOps';

    if (widget.isIndividual) {
      return const GeneratePdfEmployee()(
        employee: selectedEmployee!,
        templates: templates,
        numeroSemaine: widget.numeroSemaine,
        generatedBy: generatedBy,
      );
    }

    return const GeneratePdfAll()(
      employees: employees,
      templates: templates,
      numeroSemaine: widget.numeroSemaine ?? 1,
      generatedBy: generatedBy,
    );
  }

  Employee? _findEmployee(
    List<Employee> employees,
    String id,
    Employee? currentEmployee,
  ) {
    for (final employee in employees) {
      if (employee.id == id) return employee;
    }
    return currentEmployee?.id == id ? currentEmployee : null;
  }

  String _fileName(Employee? employee) {
    if (employee != null) {
      final safeName = employee.nomComplet
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      return 'planning-$safeName.pdf';
    }
    return 'planning-equipe-semaine-${widget.numeroSemaine ?? 1}.pdf';
  }
}
