import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/planning_template.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';

abstract class PlanningRepository {
  Future<Either<Failure, List<PlanningTemplate>>> getTemplates({
    String? employeeId,
  });

  Future<Either<Failure, PlanningTemplate>> ajouterSlot({
    required String employeeId,
    required String appartementId,
    required int numeroSemaine,
    required String jour,
    required PeriodeType periode,
    required int numeroTache,
  });

  Future<Either<Failure, PlanningTemplate>> deplacerSlot({
    required String id,
    required String employeeId,
    required String jour,
    required PeriodeType periode,
    required int numeroTache,
  });

  Future<Either<Failure, void>> supprimerSlot(String id);
}
