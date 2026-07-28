import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../domain/repositories/employes_repository.dart';
import '../datasources/employes_datasource.dart';

class EmployesRepositoryImpl implements EmployesRepository {
  final EmployesDatasource _datasource;
  const EmployesRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<Employee>>> getEmployes() async {
    try {
      final list = await _datasource.getEmployes();
      return Right(list);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Employee>> addEmploye({
    required String nom,
    required String prenom,
    required RoleType role,
    String? numeroPointeuse,
    String? motDePasse,
  }) async {
    try {
      final emp = await _datasource.addEmploye(
        nom: nom,
        prenom: prenom,
        role: role,
        numeroPointeuse: numeroPointeuse,
        motDePasse: motDePasse,
      );
      return Right(emp);
    } on DoublonException catch (e) {
      return Left(DoublonFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Employee>> updateEmploye({
    required String id,
    required String nom,
    required String prenom,
    required RoleType role,
    required bool isActif,
    String? numeroPointeuse,
    String? motDePasse,
  }) async {
    try {
      final emp = await _datasource.updateEmploye(
        id: id,
        nom: nom,
        prenom: prenom,
        role: role,
        isActif: isActif,
        numeroPointeuse: numeroPointeuse,
        motDePasse: motDePasse,
      );
      return Right(emp);
    } on DoublonException catch (e) {
      return Left(DoublonFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> toggleActif(
    String id, {
    required bool isActif,
  }) async {
    try {
      await _datasource.toggleActif(id, isActif: isActif);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
