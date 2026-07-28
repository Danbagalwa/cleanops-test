import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../entities/employee.dart';
import '../repositories/auth_repository.dart';

class LoginWithPin {
  final AuthRepository repository;
  const LoginWithPin(this.repository);

  Future<Either<Failure, Employee>> call(LoginParams params) {
    return repository.loginWithPin(
      slug: params.slug,
      pin: params.pin,
      role: params.role,
    );
  }
}

class LoginParams extends Equatable {
  final String slug;
  final String pin;
  final String? role; // 'preposee', 'resident', 'responsable'

  const LoginParams({required this.slug, required this.pin, this.role});

  @override
  List<Object?> get props => [slug, pin, role];
}
