import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/error_widget.dart';
import '../providers/demande_equipe_provider.dart';

/// Affiche le document joint à une demande : aperçu PDF (impression/partage
/// inclus) ou image plein écran.
class DocumentDemandeScreen extends ConsumerWidget {
  final String demandeId;
  final String nom;

  const DocumentDemandeScreen({
    super.key,
    required this.demandeId,
    required this.nom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(documentDemandeProvider(demandeId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        title: Text(nom, overflow: TextOverflow.ellipsis),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppErrorNotice(
              error: e,
              onRetry: () => ref.invalidate(documentDemandeProvider(demandeId)),
            ),
          ),
        ),
        data: (doc) => doc.estPdf
            ? PdfPreview(
                build: (_) async => doc.octets,
                allowPrinting: true,
                allowSharing: true,
                canChangePageFormat: false,
                canChangeOrientation: false,
                pdfFileName: doc.nom,
                loadingWidget: const Center(
                  child: CircularProgressIndicator(color: AppColors.rouge),
                ),
              )
            : InteractiveViewer(
                child: Center(child: Image.memory(doc.octets)),
              ),
      ),
    );
  }
}
