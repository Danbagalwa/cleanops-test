import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/tache_disponible.dart';

abstract class TacheDisponibleRepository {
  Future<Either<Failure, List<TacheDisponible>>> getTachesDisponibles({
    required String employeeId,
    required DateTime date,
  });

  Future<Either<Failure, TacheDisponible>> libererTache({
    required String tacheJourId,
    required String libereParId,
    required MotifDisponible motif,
    String? employeeVisibleId,
  });

  Future<Either<Failure, TacheDisponible>> prendreEnCharge({
    required String tacheDisponibleId,
    required String employeeId,
  });
}
