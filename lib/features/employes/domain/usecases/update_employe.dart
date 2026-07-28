import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/employee.dart';
import '../repositories/employes_repository.dart';

class UpdateEmployeParams {
  final String id;
  final String nom;
  final String prenom;
  final RoleType role;
  final bool isActif;
  final String? numeroPointeuse;
  final String? motDePasse;

  const UpdateEmployeParams({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.role,
    required this.isActif,
    this.numeroPointeuse,
    this.motDePasse,
  });
}

class UpdateEmploye {
  final EmployesRepository _repository;
  const UpdateEmploye(this._repository);

  Future<Either<Failure, Employee>> call(UpdateEmployeParams p) =>
      _repository.updateEmploye(
        id: p.id,
        nom: p.nom,
        prenom: p.prenom,
        role: p.role,
        isActif: p.isActif,
        numeroPointeuse: p.numeroPointeuse,
        motDePasse: p.motDePasse,
      );
}
