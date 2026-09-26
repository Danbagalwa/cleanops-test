import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/widgets/lecteur_pdf.dart';
import '../../../reception/domain/reception_messages_models.dart';
import '../../domain/usecases/generate_messages_reception_export.dart';

class MessagesReceptionPdfPreviewScreen extends StatelessWidget {
  final List<MessageTransmis> messages;
  final String filtres;
  final String generatedBy;

  const MessagesReceptionPdfPreviewScreen({
    super.key,
    required this.messages,
    required this.filtres,
    required this.generatedBy,
  });

  @override
  Widget build(BuildContext context) {
    return LecteurPdf(
      titre: 'Messages de la réception',
      sousTitre: filtres,
      icone: Icons.support_agent_rounded,
      nomFichier: 'messages-reception.pdf',
      format: PdfPageFormat.a4.landscape,
      generer: () => const GenerateMessagesReceptionPdf()(
        messages: messages,
        filtres: filtres,
        generatedBy: generatedBy,
      ),
    );
  }
}
