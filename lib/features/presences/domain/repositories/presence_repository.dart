import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/presence.dart';

abstract class PresenceRepository {
  Future<Either<Failure, Presence>> confirmerPresence({
    required String employeeId,
    required DateTime date,
    required StatutPresence statut,
    String? heureDebut,
    String? heureFin,
  });

  Future<Either<Failure, Presence?>> getMaPresence({
    required String employeeId,
    required DateTime date,
  });

  /// Absences du [debut] au [fin] inclus (plus récentes d'abord).
  Future<Either<Failure, List<Presence>>> getAbsences(
      DateTime debut, DateTime fin);

  /// Présences confirmées avec un horaire précisé (registre informatif).
  Future<Either<Failure, List<Presence>>> getPresencesAvecHeures(
      DateTime debut, DateTime fin);

  Future<void> envoyerAlerteResponsable({
    required String presenceId,
    required List<String> responsableIds,
    required String message,
    required String entityId,
    String type = 'AbsenceValidee',
  });
}
