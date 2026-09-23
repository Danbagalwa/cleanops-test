import 'package:file_picker/file_picker.dart';

import '../domain/entities/fichier_choisi.dart';
import '../domain/selecteur_document.dart';

/// Sélecteur réel, fondé sur `file_picker`.
class SelecteurDocumentFilePicker implements SelecteurDocument {
  @override
  Future<FichierChoisi?> choisir({required List<String> extensions}) async {
    final fichiers = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (fichiers.isEmpty) return null;

    final fichier = fichiers.first;
    return FichierChoisi(
      nom: fichier.name,
      extension: fichier.extension,
      octets: await fichier.readAsBytes(),
    );
  }
}
