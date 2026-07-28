import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/planning_template.dart';
import '../repositories/planning_repository.dart';

class GetPlanningEmployee {
  final PlanningRepository _repository;
  const GetPlanningEmployee(this._repository);

  Future<Either<Failure, List<PlanningTemplate>>> call({
    String? employeeId,
  }) =>
      _repository.getTemplates(employeeId: employeeId);
}
