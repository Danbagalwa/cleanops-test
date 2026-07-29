import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../resident_espace/domain/entities/tache_resident.dart';
import '../../domain/usecases/generate_resident_cleaning_dates_pdf.dart';

class ResidentCleaningDatesPdfScreen extends StatelessWidget {
  final List<TacheResident> taches;
  final String residentName;
  final String apartmentNumber;

  const ResidentCleaningDatesPdfScreen({
    super.key,
    required this.taches,
    required this.residentName,
    required this.apartmentNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        title: const Text(
          'Mes dates de ménage',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: PdfPreview(
        build: (_) => _buildPdf(),
        initialPageFormat: PdfPageFormat.a4,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: 'mes-dates-de-menage.pdf',
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: AppColors.rouge),
        ),
        onError: (_, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppErrorNotice(error: error),
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _buildPdf() {
    return const GenerateResidentCleaningDatesPdf()(
      taches: taches,
      residentName: residentName,
      apartmentNumber: apartmentNumber,
    );
  }
}
