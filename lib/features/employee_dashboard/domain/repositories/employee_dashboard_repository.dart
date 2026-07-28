import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/semaine.dart';

abstract class EmployeeDashboardRepository {
  Future<Either<Failure, Semaine>> getSemaineCourante({
    required String employeeId,
  });

  Future<Either<Failure, String?>> getMessageSemaine();
}