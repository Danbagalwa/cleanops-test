import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/appartement.dart';

abstract class AppartementsRepository {
  Future<Either<Failure, List<Appartement>>> getAppartements();

  Future<Either<Failure, Appartement>> addAppartement({
    required String numero,
    required String taille,
    required int minutesBase,
  });

  Future<Either<Failure, Appartement>> updateAppartement({
    required String id,
    required String numero,
    required String taille,
    required int minutesBase,
  });

  Future<Either<Failure, void>> deleteAppartement(String id);
}
