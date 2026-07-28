import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/stat_semaine.dart';
import '../../domain/entities/stat_preposee.dart';
import '../../domain/entities/stat_appartement.dart';
import '../../domain/repositories/statistiques_repository.dart';
import '../datasources/statistiques_datasource.dart';

class StatistiquesRepositoryImpl implements StatistiquesRepository {
  final StatistiquesDatasource _ds;
  const StatistiquesRepositoryImpl(this._ds);

  @override
  Future<Either<Failure, List<StatSemaine>>> getStatSemaine() async {
    try {
      return Right(await _ds.getStatSemaine());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<StatPreposee>>> getStatParPreposee({
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    try {
      return Right(await _ds.getStatParPreposee(
          dateDebut: dateDebut, dateFin: dateFin));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<StatAppartement>>> getTopAppartementsProblematiques() async {
    try {
      return Right(await _ds.getTopAppartementsProblematiques());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
