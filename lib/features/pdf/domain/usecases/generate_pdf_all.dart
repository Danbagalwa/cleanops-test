import 'dart:typed_data';

import '../../../auth/domain/entities/employee.dart';
import '../../../planning/domain/entities/planning_template.dart';
import 'planning_pdf_document.dart';

class GeneratePdfAll {
  const GeneratePdfAll();

  Future<Uint8List> call({
    required List<Employee> employees,
    required List<PlanningTemplate> templates,
    required int numeroSemaine,
    required String generatedBy,
  }) {
    return PlanningPdfDocument.buildTeam(
      employees: employees,
      templates: templates,
      numeroSemaine: numeroSemaine,
      generatedBy: generatedBy,
    );
  }
}
