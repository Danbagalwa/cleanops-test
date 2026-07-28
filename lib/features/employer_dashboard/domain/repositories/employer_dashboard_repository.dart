import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/progression_jour.dart';

abstract class EmployerDashboardRepository {
  Future<Either<Failure, List<ProgressionJour>>> getProgressionJour();
}
