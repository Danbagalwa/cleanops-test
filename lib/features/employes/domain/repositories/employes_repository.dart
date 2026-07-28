import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/employee.dart';

abstract class EmployesRepository {
  Future<Either<Failure, List<Employee>>> getEmployes();

  Future<Either<Failure, Employee>> addEmploye({
    required String nom,
    required String prenom,
    required RoleType role,
    String? numeroPointeuse,
    String? motDePasse,
  });

  Future<Either<Failure, Employee>> updateEmploye({
    required String id,
    required String nom,
    required String prenom,
    required RoleType role,
    required bool isActif,
    String? numeroPointeuse,
    String? motDePasse,
  });

  Future<Either<Failure, void>> toggleActif(String id, {required bool isActif});
}
