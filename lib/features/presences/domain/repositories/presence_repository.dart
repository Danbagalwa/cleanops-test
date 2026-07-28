import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/presence.dart';

abstract class PresenceRepository {
  Future<Either<Failure, Presence>> confirmerPresence({
    required String employeeId,
    required DateTime date,
    required StatutPresence statut,
  });

  Future<Either<Failure, Presence?>> getMaPresence({
    required String employeeId,
    required DateTime date,
  });

  Future<Either<Failure, List<Presence>>> getAbsencesDuJour(DateTime date);

  Future<void> envoyerAlerteResponsable({
    required String presenceId,
    required List<String> responsableIds,
    required String message,
    required String entityId,
  });
}
