import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/employee.dart';
import '../repositories/employes_repository.dart';

class AddEmployeParams {
  final String nom;
  final String prenom;
  final RoleType role;
  final String? numeroPointeuse;
  final String? motDePasse;

  const AddEmployeParams({
    required this.nom,
    required this.prenom,
    required this.role,
    this.numeroPointeuse,
    this.motDePasse,
  });
}

class AddEmploye {
  final EmployesRepository _repository;
  const AddEmploye(this._repository);

  Future<Either<Failure, Employee>> call(AddEmployeParams p) =>
      _repository.addEmploye(
        nom: p.nom,
        prenom: p.prenom,
        role: p.role,
        numeroPointeuse: p.numeroPointeuse,
        motDePasse: p.motDePasse,
      );
}
