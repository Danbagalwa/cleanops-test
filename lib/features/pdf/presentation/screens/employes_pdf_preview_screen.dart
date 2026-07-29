import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/error_widget.dart';
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
    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Liste des employés',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              'Aperçu avant export',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
      body: PdfPreview(
        build: (_) => _buildPdf(),
        initialPageFormat: PdfPageFormat.a4,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: 'liste-employes.pdf',
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: AppColors.rouge),
        ),
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppErrorNotice(error: error),
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _buildPdf() {
    return const GenerateEmployesPdf()(
      employees: employees,
      filterDescription: filterDescription,
      generatedBy: generatedBy,
    );
  }
}
