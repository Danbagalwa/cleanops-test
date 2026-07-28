import 'package:flutter/material.dart';

class PdfPreviewScreen extends StatelessWidget {
  final String? employeeId;
  final int? numeroSemaine;
  const PdfPreviewScreen({super.key, this.employeeId, this.numeroSemaine});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('PDF Preview')));
  }
}
