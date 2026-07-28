import 'package:flutter_test/flutter_test.dart';
import 'package:jazz_teasdale/core/errors/user_friendly_error.dart';

void main() {
  test('masque une erreur PostgreSQL technique', () {
    final result = UserFriendlyError.from(
      'PostgrestException: duplicate key violates unique constraint (23505)',
    );

    expect(result.kind, UserErrorKind.duplicate);
    expect(result.message, isNot(contains('23505')));
    expect(result.message, isNot(contains('constraint')));
  });

  test('rassure lors d’une erreur réseau', () {
    final result = UserFriendlyError.from(
      'SocketException: Failed host lookup',
    );

    expect(result.kind, UserErrorKind.connection);
    expect(result.message, contains('données sont en sécurité'));
  });

  test('conserve un message métier compréhensible', () {
    final result = UserFriendlyError.from(
      'Cette tâche n’est plus disponible.',
    );

    expect(result.message, 'Cette tâche n’est plus disponible.');
  });
}
