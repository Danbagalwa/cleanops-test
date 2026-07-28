enum UserErrorKind {
  connection,
  session,
  permission,
  duplicate,
  validation,
  notFound,
  unavailable,
  unexpected,
}

class UserFriendlyError {
  final String title;
  final String message;
  final UserErrorKind kind;

  const UserFriendlyError({
    required this.title,
    required this.message,
    required this.kind,
  });

  static UserFriendlyError from(Object? error) {
    final raw = _clean(error?.toString() ?? '');
    final text = raw.toLowerCase();

    if (_containsAny(text, [
      'socketexception',
      'failed host lookup',
      'network',
      'connexion',
      'connection refused',
      'clientexception',
    ])) {
      return const UserFriendlyError(
        title: 'Connexion interrompue',
        message:
            'Nous n’arrivons pas à joindre le service pour le moment. '
            'Vérifiez votre connexion, puis réessayez. Vos données sont en sécurité.',
        kind: UserErrorKind.connection,
      );
    }

    if (_containsAny(text, ['timeout', 'timed out', 'délai dépassé'])) {
      return const UserFriendlyError(
        title: 'Le service prend un peu de temps',
        message:
            'La demande n’a pas pu être terminée assez rapidement. '
            'Patientez quelques instants, puis réessayez.',
        kind: UserErrorKind.unavailable,
      );
    }

    if (_containsAny(text, [
      'jwt',
      'pgrst301',
      'session expired',
      'token invalide',
      'token expired',
      '401',
    ])) {
      return const UserFriendlyError(
        title: 'Votre session a expiré',
        message:
            'Pour protéger votre compte, veuillez vous reconnecter avant de continuer.',
        kind: UserErrorKind.session,
      );
    }

    if (_containsAny(text, [
      '42501',
      'permission denied',
      'row-level security',
      'not authorized',
      'unauthorized',
      '403',
    ])) {
      return const UserFriendlyError(
        title: 'Action non autorisée',
        message:
            'Cette action n’est pas disponible pour votre profil. '
            'Rien n’a été modifié.',
        kind: UserErrorKind.permission,
      );
    }

    if (_containsAny(text, [
      '23505',
      'duplicate key',
      'unique constraint',
      'doublon',
      'existe déjà',
      'déjà attribué',
    ])) {
      return const UserFriendlyError(
        title: 'Cet élément existe déjà',
        message:
            'Une information identique est déjà enregistrée. '
            'Vous pouvez vérifier les données saisies puis réessayer.',
        kind: UserErrorKind.duplicate,
      );
    }

    if (_containsAny(text, [
      '23503',
      'foreign key',
      'still referenced',
    ])) {
      return const UserFriendlyError(
        title: 'Cet élément est encore utilisé',
        message:
            'Il ne peut pas être supprimé pour le moment, car il est lié à '
            'd’autres informations. Rien n’a été modifié.',
        kind: UserErrorKind.validation,
      );
    }

    if (_containsAny(text, [
      '23514',
      'check constraint',
      'invalid input value',
      '22p02',
    ])) {
      return const UserFriendlyError(
        title: 'Une information est à vérifier',
        message:
            'Certaines données ne respectent pas les règles attendues. '
            'Vérifiez les champs indiqués puis réessayez.',
        kind: UserErrorKind.validation,
      );
    }

    if (_containsAny(text, [
      'pgrst116',
      'not found',
      'aucune ligne',
      'introuvable',
    ])) {
      return const UserFriendlyError(
        title: 'Information introuvable',
        message:
            'Cet élément n’est plus disponible ou a déjà été modifié. '
            'Actualisez la page pour continuer.',
        kind: UserErrorKind.notFound,
      );
    }

    if (_containsAny(text, ['429', 'rate limit', 'too many requests'])) {
      return const UserFriendlyError(
        title: 'Un peu trop de demandes',
        message:
            'Le service se protège temporairement. Attendez quelques instants '
            'avant de réessayer.',
        kind: UserErrorKind.unavailable,
      );
    }

    if (_isSafeBusinessMessage(raw)) {
      return UserFriendlyError(
        title: 'Nous n’avons pas pu terminer',
        message: raw,
        kind: UserErrorKind.validation,
      );
    }

    return const UserFriendlyError(
      title: 'Un imprévu est survenu',
      message:
          'Nous n’avons pas pu terminer cette action. Rien n’a été perdu : '
          'réessayez dans un instant.',
      kind: UserErrorKind.unexpected,
    );
  }

  static String messageFor(Object? error) => from(error).message;

  static String _clean(String value) {
    return value
        .replaceFirst(RegExp(r'^(Exception|ServerException):\s*'), '')
        .trim();
  }

  static bool _containsAny(String value, List<String> patterns) =>
      patterns.any(value.contains);

  static bool _isSafeBusinessMessage(String value) {
    if (value.isEmpty || value.length > 240) return false;

    final lower = value.toLowerCase();
    final technical = _containsAny(lower, [
      'exception',
      'postgrest',
      'supabase',
      'sql',
      'select ',
      'insert ',
      'update ',
      'delete ',
      'constraint',
      'stack trace',
      'dart:',
      'http',
      'pgrst',
    ]);
    if (technical) return false;

    return _containsAny(lower, [
      'veuillez',
      'incorrect',
      'invalide',
      'obligatoire',
      'déjà',
      'aucun',
      'introuvable',
      'indisponible',
      'ne peut pas',
      'n’est plus',
      'n\'est plus',
      'impossible',
      'erreur lors',
    ]);
  }
}
