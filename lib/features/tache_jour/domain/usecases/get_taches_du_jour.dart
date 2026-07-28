import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/tache_jour.dart';
import '../repositories/tache_jour_repository.dart';

class GetTachesDuJour {
  final TacheJourRepository _repository;
  const GetTachesDuJour(this._repository);

  Future<Either<Failure, List<TacheJour>>> call({
    required String employeeId,
    required String dateStr,
  }) =>
      _repository.getTachesDuJour(employeeId: employeeId, dateStr: dateStr);
}
