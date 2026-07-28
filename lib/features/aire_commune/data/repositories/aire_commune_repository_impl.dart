import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/reset_aire_commune.dart';
import '../../domain/entities/tache_aire_commune.dart';
import '../../domain/repositories/aire_commune_repository.dart';
import '../datasources/aire_commune_datasource.dart';

class AireCommuneRepositoryImpl implements AireCommuneRepository {
  final AireCommuneDatasource _ds;
  const AireCommuneRepositoryImpl(this._ds);

  @override
  Future<Either<Failure, List<TacheAireCommune>>> getTachesAireCommune() async {
    try {
      return Right(await _ds.getTachesAireCommune());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, TacheAireCommune>> confirmerZone(
      String id, String employeeId) async {
    try {
      return Right(await _ds.confirmerZone(id, employeeId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<TacheAireCommune>>> getTachesByCategorie(
      String categorie) async {
    try {
      return Right(await _ds.getTachesByCategorie(categorie));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> resetSemaineComplete(
      String responsableId) async {
    try {
      await _ds.resetSemaineComplete(responsableId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> annulerConfirmationZone(String zoneId) async {
    try {
      await _ds.annulerConfirmationZone(zoneId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ResetAireCommune>>> getHistoriqueResets() async {
    try {
      return Right(await _ds.getHistoriqueResets());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> getJourResetConfig() async {
    try {
      return Right(await _ds.getJourResetConfig());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateJourReset(String jour) async {
    try {
      await _ds.updateJourReset(jour);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> getResetAutoConfig() async {
    try {
      return Right(await _ds.getResetAutoConfig());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateResetAuto(bool actif) async {
    try {
      await _ds.updateResetAuto(actif);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
