import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/employee.dart';

abstract class AuthRepository {
  // Niveau 1 — Valider ID résidence + PIN résidence
  Future<Either<Failure, bool>> validerNiveauUn({
    required String idResidence,
    required String pinResidence,
  });

  // Niveau 2 — Connexion par slug + PIN selon rôle
  Future<Either<Failure, Employee>> loginWithPin({
    required String slug,
    required String pin,
    String? role, // 'preposee', 'resident', 'responsable'
  });

  // Récupérer l'employé en session
  Future<Either<Failure, Employee?>> getEmployeEnSession();

  // Déconnexion
  Future<Either<Failure, void>> logout();
}
