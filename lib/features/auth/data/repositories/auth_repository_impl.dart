import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource datasource;

  const AuthRepositoryImpl(this.datasource);

  // ── Niveau 1 — Valider résidence ─────────────────────
  @override
  Future<Either<Failure, bool>> validerNiveauUn({
    required String idResidence,
    required String pinResidence,
  }) async {
    try {
      final valide = await datasource.validerNiveauUn(
        idResidence: idResidence,
        pinResidence: pinResidence,
      );
      return Right(valide);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inconnue : $e'));
    }
  }

  // ── Niveau 2 — Connexion selon rôle ──────────────────
  @override
  Future<Either<Failure, Employee>> loginWithPin({
    required String slug,
    required String pin,
    String? role,
  }) async {
    try {
      final employee = await datasource.loginWithPin(
        slug: slug,
        pin: pin,
        role: role,
      );
      return Right(employee);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inconnue : $e'));
    }
  }

  // ── Session ───────────────────────────────────────────
  @override
  Future<Either<Failure, Employee?>> getEmployeEnSession() async {
    try {
      final employee = await datasource.getEmployeEnSession();
      return Right(employee);
    } catch (e) {
      return Left(ServerFailure('Erreur session : $e'));
    }
  }

  // ── Déconnexion ───────────────────────────────────────
  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await datasource.logout();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Erreur déconnexion : $e'));
    }
  }
}
