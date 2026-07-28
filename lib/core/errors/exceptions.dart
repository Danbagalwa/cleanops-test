class ServerException implements Exception {
  final String message;
  const ServerException(this.message);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}

class DoublonException implements Exception {
  final String message;
  const DoublonException(this.message);
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException(this.message);
}
