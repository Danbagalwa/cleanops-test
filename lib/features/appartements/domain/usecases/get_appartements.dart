import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/appartement.dart';
import '../repositories/appartements_repository.dart';

class GetAppartements {
  final AppartementsRepository repository;
  const GetAppartements(this.repository);

  Future<Either<Failure, List<Appartement>>> call() {
    return repository.getAppartements();
  }
}
