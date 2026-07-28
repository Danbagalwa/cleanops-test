import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/resident.dart';
import '../repositories/resident_repository.dart';

class CreerResidentParams {
  final String appartementId;
  final String nom;
  final String prenom;
  final bool aApplication;

  const CreerResidentParams({
    required this.appartementId,
    required this.nom,
    required this.prenom,
    required this.aApplication,
  });
}

class CreerResident {
  final ResidentRepository _repo;
  const CreerResident(this._repo);

  Future<Either<Failure, Resident>> call(CreerResidentParams p) =>
      _repo.creerResident(p.appartementId, p.nom, p.prenom, p.aApplication);
}
