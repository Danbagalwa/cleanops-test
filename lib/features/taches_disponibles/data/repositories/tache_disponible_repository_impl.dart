import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/tache_disponible.dart';
import '../../domain/repositories/tache_disponible_repository.dart';
import '../datasources/tache_disponible_datasource.dart';

class TacheDisponibleRepositoryImpl implements TacheDisponibleRepository {
  final TacheDisponibleDatasource _ds;
  const TacheDisponibleRepositoryImpl(this._ds);

  @override
  Future<Either<Failure, List<TacheDisponible>>> getTachesDisponibles({
    required String employeeId,
    required DateTime date,
  }) async {
    try {
      final result =
          await _ds.getTachesDisponibles(employeeId: employeeId, date: date);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, TacheDisponible>> libererTache({
    required String tacheJourId,
    required String libereParId,
    required MotifDisponible motif,
    String? employeeVisibleId,
  }) async {
    try {
      final result = await _ds.libererTache(
        tacheJourId: tacheJourId,
        libereParId: libereParId,
        motif: motif,
        employeeVisibleId: employeeVisibleId,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, TacheDisponible>> prendreEnCharge({
    required String tacheDisponibleId,
    required String employeeId,
  }) async {
    try {
      final result = await _ds.prendreEnCharge(
        tacheDisponibleId: tacheDisponibleId,
        employeeId: employeeId,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
