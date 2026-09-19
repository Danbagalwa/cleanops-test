import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/presence.dart';
import '../../domain/repositories/presence_repository.dart';
import '../datasources/presence_datasource.dart';

class PresenceRepositoryImpl implements PresenceRepository {
  final PresenceDatasource _ds;
  const PresenceRepositoryImpl(this._ds);

  @override
  Future<Either<Failure, Presence>> confirmerPresence({
    required String employeeId,
    required DateTime date,
    required StatutPresence statut,
    String? heureDebut,
    String? heureFin,
  }) async {
    try {
      final result = await _ds.confirmerPresence(
        employeeId: employeeId,
        date: date,
        statut: statut,
        heureDebut: heureDebut,
        heureFin: heureFin,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Presence?>> getMaPresence({
    required String employeeId,
    required DateTime date,
  }) async {
    try {
      final result =
          await _ds.getMaPresence(employeeId: employeeId, date: date);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Presence>>> getAbsencesDuJour(
      DateTime date) async {
    try {
      final result = await _ds.getAbsencesDuJour(date);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Presence>>> getPresencesAvecHeures(
      DateTime date) async {
    try {
      final result = await _ds.getPresencesAvecHeures(date);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<void> envoyerAlerteResponsable({
    required String presenceId,
    required List<String> responsableIds,
    required String message,
    required String entityId,
    String type = 'AbsenceValidee',
  }) =>
      _ds.envoyerAlerteResponsable(
        presenceId: presenceId,
        responsableIds: responsableIds,
        message: message,
        entityId: entityId,
        type: type,
      );
}
