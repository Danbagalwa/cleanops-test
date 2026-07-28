import 'package:equatable/equatable.dart';
import 'user_friendly_error.dart';

abstract class Failure extends Equatable {
  final String message;
  Failure(String technicalMessage)
      : message = UserFriendlyError.messageFor(technicalMessage);

  @override
  List<Object> get props => [message];
}

class ServerFailure extends Failure {
  ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  NetworkFailure(super.message);
}

class AuthFailure extends Failure {
  AuthFailure(super.message);
}

class DoublonFailure extends Failure {
  DoublonFailure(super.message);
}

class NotFoundFailure extends Failure {
  NotFoundFailure(super.message);
}

class CacheFailure extends Failure {
  CacheFailure(super.message);
}
