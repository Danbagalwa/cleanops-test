import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/statistiques_menages.dart';

abstract class StatistiquesRepository {
  /// Ménages planifiés entre [dateDebut] et [dateFin] (bornes comprises).
  Future<Either<Failure, StatistiquesMenages>> getStatistiques({
    required DateTime dateDebut,
    required DateTime dateFin,
  });
}
