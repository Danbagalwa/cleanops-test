import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/tache_jour.dart';
import '../repositories/tache_jour_repository.dart';

class UpdateStatutTache {
  final TacheJourRepository _repository;
  const UpdateStatutTache(this._repository);

  Future<Either<Failure, TacheJour>> call({
    required String id,
    required StatutTache statut,
    String? motifAbsent,
  }) =>
      _repository.updateStatut(
        id: id,
        statut: statut,
        motifAbsent: motifAbsent,
      );
}
