import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/semaine.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import '../datasources/employee_dashboard_datasource.dart';

class EmployeeDashboardRepositoryImpl implements EmployeeDashboardRepository {
  final EmployeeDashboardDatasource datasource;
  const EmployeeDashboardRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, Semaine>> getSemaineCourante({
    required String employeeId,
  }) async {
    try {
      final semaine = await datasource.getSemaineCourante(
        employeeId: employeeId,
      );
      return Right(semaine);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inconnue : $e'));
    }
  }

  @override
  Future<Either<Failure, String?>> getMessageSemaine() async {
    try {
      final message = await datasource.getMessageSemaine();
      return Right(message);
    } catch (e) {
      return Left(ServerFailure('Erreur message : $e'));
    }
  }
}