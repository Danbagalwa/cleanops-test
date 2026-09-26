import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/widgets/lecteur_pdf.dart';
import '../../../messages_semaine/domain/entities/message_semaine.dart';
import '../../domain/usecases/generate_messages_semaine_export.dart';

class MessagesSemainePdfPreviewScreen extends StatelessWidget {
  final List<MessageSemaine> messages;
  final String filtres;
  final String generatedBy;

  const MessagesSemainePdfPreviewScreen({
    super.key,
    required this.messages,
    required this.filtres,
    required this.generatedBy,
  });

  @override
  Widget build(BuildContext context) {
    return LecteurPdf(
      titre: 'Messages de la semaine',
      sousTitre: filtres,
      icone: Icons.campaign_rounded,
      nomFichier: 'messages-semaine.pdf',
      format: PdfPageFormat.a4.landscape,
      generer: () => const GenerateMessagesSemainePdf()(
        messages: messages,
        filtres: filtres,
        generatedBy: generatedBy,
      ),
    );
  }
}
