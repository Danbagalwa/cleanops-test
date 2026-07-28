import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

class Logout {
  final AuthRepository repository;
  const Logout(this.repository);

  Future<Either<Failure, void>> call() {
    return repository.logout();
  }
}
