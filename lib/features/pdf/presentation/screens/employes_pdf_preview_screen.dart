import 'package:flutter/material.dart';

import '../../../../core/widgets/lecteur_pdf.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../domain/usecases/generate_employes_export.dart';

class EmployesPdfPreviewScreen extends StatelessWidget {
  final List<Employee> employees;
  final String filterDescription;
  final String generatedBy;

  const EmployesPdfPreviewScreen({
    super.key,
    required this.employees,
    required this.filterDescription,
    required this.generatedBy,
  });

  @override
  Widget build(BuildContext context) {
    return LecteurPdf(
      titre: 'Liste des employés',
      sousTitre: filterDescription,
      icone: Icons.group_rounded,
      nomFichier: 'liste-employes.pdf',
      generer: () => const GenerateEmployesPdf()(
        employees: employees,
        filterDescription: filterDescription,
        generatedBy: generatedBy,
      ),
    );
  }
}
