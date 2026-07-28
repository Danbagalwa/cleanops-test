import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/semaine.dart';
import '../repositories/employee_dashboard_repository.dart';

class GetSemaineCourante {
  final EmployeeDashboardRepository repository;
  const GetSemaineCourante(this.repository);

  Future<Either<Failure, Semaine>> call({
    required String employeeId,
  }) {
    return repository.getSemaineCourante(employeeId: employeeId);
  }
}