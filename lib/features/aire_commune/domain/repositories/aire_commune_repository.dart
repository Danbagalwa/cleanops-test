import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/reset_aire_commune.dart';
import '../entities/tache_aire_commune.dart';

abstract class AireCommuneRepository {
  Future<Either<Failure, List<TacheAireCommune>>> getTachesAireCommune();
  Future<Either<Failure, TacheAireCommune>> confirmerZone(String id, String employeeId);
  Future<Either<Failure, List<TacheAireCommune>>> getTachesByCategorie(String categorie);
  Future<Either<Failure, Unit>> resetSemaineComplete(String responsableId);
  Future<Either<Failure, Unit>> annulerConfirmationZone(String zoneId);
  Future<Either<Failure, List<ResetAireCommune>>> getHistoriqueResets();
  Future<Either<Failure, String>> getJourResetConfig();
  Future<Either<Failure, Unit>> updateJourReset(String jour);
  Future<Either<Failure, bool>> getResetAutoConfig();
  Future<Either<Failure, Unit>> updateResetAuto(bool actif);
}
