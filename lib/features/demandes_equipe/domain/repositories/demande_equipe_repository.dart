import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/demande_equipe.dart';

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

  Future<Either<Failure, DemandeEquipe>> traiterDemande({
    required String demandeId,
    required String traiteParId,
    required bool approuve,
    String? note,
  });
}
