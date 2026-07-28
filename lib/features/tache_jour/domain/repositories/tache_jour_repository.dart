import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/tache_jour.dart';

abstract class TacheJourRepository {
  Future<Either<Failure, List<TacheJour>>> getTachesDuJour({
    required String employeeId,
    required String dateStr, // 'YYYY-MM-DD'
  });

  Future<Either<Failure, TacheJour>> updateStatut({
    required String id,
    required StatutTache statut,
    String? motifAbsent,
  });
}
