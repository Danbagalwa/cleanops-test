import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Le contenu d'un document joint à une demande d'équipe — lu à la demande
/// (jamais chargé avec la liste des demandes, qui ne porte que ses métadonnées).
class DocumentDemande extends Equatable {
  final String nom;
  final String typeMime;
  final Uint8List octets;

  const DocumentDemande({
    required this.nom,
    required this.typeMime,
    required this.octets,
  });

  bool get estPdf => typeMime == 'application/pdf';

  @override
  List<Object?> get props => [nom, typeMime, octets.length];
}
