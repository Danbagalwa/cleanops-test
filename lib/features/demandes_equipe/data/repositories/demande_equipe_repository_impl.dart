import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/demande_equipe.dart';
import '../../domain/repositories/demande_equipe_repository.dart';
import '../datasources/demande_equipe_datasource.dart';

class DemandeEquipeRepositoryImpl implements DemandeEquipeRepository {
  final DemandeEquipeDatasource _ds;
  const DemandeEquipeRepositoryImpl(this._ds);

  @override
  Future<Either<Failure, List<DemandeEquipe>>> getMesDemandes(
      String employeeId) async {
    try {
      return Right(await _ds.getMesDemandes(employeeId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, DemandeEquipe>> creerDemande({
    required String employeeId,
    required String employeePrenom,
    required String employeeNom,
    required TypeDemandeEquipe type,
    required DateTime dateDebut,
    DateTime? dateFin,
    required String motif,
  }) async {
    try {
      return Right(await _ds.creerDemande(
        employeeId: employeeId,
        employeePrenom: employeePrenom,
        employeeNom: employeeNom,
        type: type,
        dateDebut: dateDebut,
        dateFin: dateFin,
        motif: motif,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<DemandeEquipe>>> getAllDemandes() async {
    try {
      return Right(await _ds.getAllDemandes());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, DemandeEquipe>> traiterDemande({
    required String demandeId,
    required String traiteParId,
    required bool approuve,
    String? note,
  }) async {
    try {
      return Right(await _ds.traiterDemande(
        demandeId: demandeId,
        traiteParId: traiteParId,
        approuve: approuve,
        note: note,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
