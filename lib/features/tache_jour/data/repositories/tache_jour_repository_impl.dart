import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/tache_jour.dart';
import '../../domain/repositories/tache_jour_repository.dart';
import '../datasources/tache_jour_datasource.dart';

class TacheJourRepositoryImpl implements TacheJourRepository {
  final TacheJourDatasource _datasource;
  const TacheJourRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<TacheJour>>> getTachesDuJour({
    required String employeeId,
    required String dateStr,
  }) async {
    try {
      final list = await _datasource.getTachesDuJour(
        employeeId: employeeId,
        dateStr: dateStr,
      );
      return Right(list);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TacheJour>> updateStatut({
    required String id,
    required StatutTache statut,
    String? motifAbsent,
  }) async {
    try {
      final t = await _datasource.updateStatut(
        id: id,
        statut: statut,
        motifAbsent: motifAbsent,
      );
      return Right(t);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
