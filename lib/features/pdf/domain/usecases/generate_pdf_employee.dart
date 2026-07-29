import 'dart:typed_data';

import '../../../auth/domain/entities/employee.dart';
import '../../../planning/domain/entities/planning_template.dart';
import 'planning_pdf_document.dart';

class GeneratePdfEmployee {
  const GeneratePdfEmployee();

  Future<Uint8List> call({
    required Employee employee,
    required List<PlanningTemplate> templates,
    int? numeroSemaine,
    required String generatedBy,
  }) {
    return PlanningPdfDocument.buildEmployee(
      employee: employee,
      templates: templates,
      numeroSemaine: numeroSemaine,
      generatedBy: generatedBy,
    );
  }
}
