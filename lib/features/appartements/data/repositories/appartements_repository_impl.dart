import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/appartement.dart';
import '../../domain/repositories/appartements_repository.dart';
import '../datasources/appartements_datasource.dart';

class AppartementsRepositoryImpl implements AppartementsRepository {
  final AppartementsDatasource datasource;
  AppartementsRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, List<Appartement>>> getAppartements() async {
    try {
      final result = await datasource.getAppartements();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Appartement>> addAppartement({
    required String numero,
    required String taille,
    required int minutesBase,
  }) async {
    try {
      final result = await datasource.addAppartement(
        numero: numero,
        taille: taille,
        minutesBase: minutesBase,
      );
      return Right(result);
    } on DoublonException catch (e) {
      return Left(DoublonFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Appartement>> updateAppartement({
    required String id,
    required String numero,
    required String taille,
    required int minutesBase,
  }) async {
    try {
      final result = await datasource.updateAppartement(
        id: id,
        numero: numero,
        taille: taille,
        minutesBase: minutesBase,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAppartement(String id) async {
    try {
      await datasource.deleteAppartement(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
