import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/stat_semaine.dart';
import '../entities/stat_preposee.dart';
import '../entities/stat_appartement.dart';

abstract class StatistiquesRepository {
  Future<Either<Failure, List<StatSemaine>>> getStatSemaine();
  Future<Either<Failure, List<StatPreposee>>> getStatParPreposee({
    required DateTime dateDebut,
    required DateTime dateFin,
  });
  Future<Either<Failure, List<StatAppartement>>> getTopAppartementsProblematiques();
}
