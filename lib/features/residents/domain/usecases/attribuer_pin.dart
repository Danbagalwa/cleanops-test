import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/resident.dart';
import '../repositories/resident_repository.dart';

class AttribuerPin {
  final ResidentRepository _repo;
  const AttribuerPin(this._repo);

  Future<Either<Failure, Resident>> call(
          String residentId, String pin) =>
      _repo.attribuerPin(residentId, pin);
}
