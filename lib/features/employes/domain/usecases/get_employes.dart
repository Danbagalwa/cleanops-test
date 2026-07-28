import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/employee.dart';
import '../repositories/employes_repository.dart';

class GetEmployes {
  final EmployesRepository _repository;
  const GetEmployes(this._repository);

  Future<Either<Failure, List<Employee>>> call() =>
      _repository.getEmployes();
}
