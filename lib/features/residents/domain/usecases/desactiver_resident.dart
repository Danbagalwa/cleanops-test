import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/resident.dart';
import '../repositories/resident_repository.dart';

class DesactiverResident {
  final ResidentRepository _repo;
  const DesactiverResident(this._repo);

  Future<Either<Failure, Resident>> call(
          String residentId, String desactiveParId) =>
      _repo.desactiverResident(residentId, desactiveParId);
}
