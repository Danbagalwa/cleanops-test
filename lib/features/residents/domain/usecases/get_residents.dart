import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/resident.dart';
import '../repositories/resident_repository.dart';

class GetResidents {
  final ResidentRepository _repo;
  const GetResidents(this._repo);

  Future<Either<Failure, List<Resident>>> call() => _repo.getResidents();
}
