import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/progression_jour.dart';
import '../../domain/repositories/employer_dashboard_repository.dart';
import '../datasources/employer_dashboard_datasource.dart';

class EmployerDashboardRepositoryImpl implements EmployerDashboardRepository {
  final EmployerDashboardDatasource _ds;
  const EmployerDashboardRepositoryImpl(this._ds);

  @override
  Future<Either<Failure, List<ProgressionJour>>> getProgressionJour() async {
    try {
      final result = await _ds.getProgressionJour();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
