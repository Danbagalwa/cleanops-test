import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/planning_template.dart';
import '../../domain/repositories/planning_repository.dart';
import '../datasources/planning_datasource.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';

class PlanningRepositoryImpl implements PlanningRepository {
  final PlanningDatasource _datasource;
  const PlanningRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<PlanningTemplate>>> getTemplates({
    String? employeeId,
  }) async {
    try {
      final list = await _datasource.getTemplates(employeeId: employeeId);
      return Right(list);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, PlanningTemplate>> ajouterSlot({
    required String employeeId,
    required String appartementId,
    required int numeroSemaine,
    required String jour,
    required PeriodeType periode,
    required int numeroTache,
  }) async {
    try {
      final t = await _datasource.ajouterSlot(
        employeeId: employeeId,
        appartementId: appartementId,
        numeroSemaine: numeroSemaine,
        jour: jour,
        periode: periode,
        numeroTache: numeroTache,
      );
      return Right(t);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, PlanningTemplate>> deplacerSlot({
    required String id,
    required String employeeId,
    required String jour,
    required PeriodeType periode,
    required int numeroTache,
  }) async {
    try {
      final template = await _datasource.deplacerSlot(
        id: id,
        employeeId: employeeId,
        jour: jour,
        periode: periode,
        numeroTache: numeroTache,
      );
      return Right(template);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> supprimerSlot(String id) async {
    try {
      await _datasource.supprimerSlot(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
