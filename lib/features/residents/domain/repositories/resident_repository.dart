import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/resident.dart';

abstract class ResidentRepository {
  Future<Either<Failure, List<Resident>>> getResidents();

  Future<Either<Failure, Resident?>> getResidentByAppartement(
      String appartementId);

  Future<Either<Failure, Resident>> creerResident(
    String appartementId,
    String nom,
    String prenom,
    bool aApplication,
  );

  Future<Either<Failure, Resident>> attribuerPin(
      String residentId, String pin);

  Future<Either<Failure, Resident>> desactiverResident(
      String residentId, String desactiveParId);

  Future<Either<Failure, Resident>> activerResident(String residentId);

  Future<Either<Failure, Resident>> toggleApplication(
      String residentId, bool aApplication);
}
