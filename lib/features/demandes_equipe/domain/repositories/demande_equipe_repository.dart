import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/demande_equipe.dart';
import '../entities/document_demande.dart';

abstract class DemandeEquipeRepository {
  Future<Either<Failure, List<DemandeEquipe>>> getMesDemandes(
      String employeeId);

  Future<Either<Failure, DemandeEquipe>> creerDemande({
    required String employeeId,
    required String employeePrenom,
    required String employeeNom,
    required TypeDemandeEquipe type,
    required DateTime dateDebut,
    DateTime? dateFin,
    required String motif,
  });

  Future<Either<Failure, List<DemandeEquipe>>> getAllDemandes();

  /// `approuve` null : la demande est seulement marquée comme vue (cas des
  /// demandes de type "Autre", qui ne s'approuvent ni ne se refusent).
  Future<Either<Failure, DemandeEquipe>> traiterDemande({
    required String demandeId,
    required String traiteParId,
    required bool? approuve,
    String? note,
  });

  Future<Either<Failure, void>> joindreDocument({
    required String demandeId,
    required String employeeId,
    required String nom,
    required String typeMime,
    required Uint8List octets,
  });

  Future<Either<Failure, DocumentDemande>> lireDocument(String demandeId);
}
