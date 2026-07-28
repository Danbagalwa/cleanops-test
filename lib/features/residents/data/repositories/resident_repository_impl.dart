import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/resident.dart';
import '../../domain/repositories/resident_repository.dart';
import '../datasources/resident_remote_datasource.dart';

class ResidentRepositoryImpl implements ResidentRepository {
  final ResidentRemoteDatasource _ds;
  const ResidentRepositoryImpl(this._ds);

  @override
  Future<Either<Failure, List<Resident>>> getResidents() async {
    try {
      return Right(await _ds.getResidents());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Resident?>> getResidentByAppartement(
      String appartementId) async {
    try {
      return Right(await _ds.getResidentByAppartement(appartementId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Resident>> creerResident(
    String appartementId,
    String nom,
    String prenom,
    bool aApplication,
  ) async {
    try {
      return Right(
          await _ds.creerResident(appartementId, nom, prenom, aApplication));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Resident>> attribuerPin(
      String residentId, String pin) async {
    try {
      return Right(await _ds.attribuerPin(residentId, pin));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Resident>> desactiverResident(
      String residentId, String desactiveParId) async {
    try {
      return Right(
          await _ds.desactiverResident(residentId, desactiveParId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Resident>> activerResident(
      String residentId) async {
    try {
      return Right(await _ds.activerResident(residentId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Resident>> toggleApplication(
      String residentId, bool aApplication) async {
    try {
      return Right(
          await _ds.toggleApplication(residentId, aApplication));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
