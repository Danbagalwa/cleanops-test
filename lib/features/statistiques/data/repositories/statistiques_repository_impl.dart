import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/statistiques_menages.dart';
import '../../domain/repositories/statistiques_repository.dart';
import '../datasources/statistiques_datasource.dart';

class StatistiquesRepositoryImpl implements StatistiquesRepository {
  final StatistiquesDatasource _ds;
  const StatistiquesRepositoryImpl(this._ds);

  @override
  Future<Either<Failure, StatistiquesMenages>> getStatistiques({
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    try {
      final menages =
          await _ds.getMenages(dateDebut: dateDebut, dateFin: dateFin);
      return Right(StatistiquesMenages(
        dateDebut: dateDebut,
        dateFin: dateFin,
        menages: menages,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
