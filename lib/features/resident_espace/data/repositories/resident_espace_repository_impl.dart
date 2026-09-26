import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/demande_resident.dart';
import '../../domain/entities/jour_menage.dart';
import '../../domain/entities/notification_resident.dart';
import '../../domain/entities/tache_resident.dart';
import '../../domain/repositories/resident_espace_repository.dart';
import '../datasources/resident_espace_datasource.dart';

class ResidentEspaceRepositoryImpl implements ResidentEspaceRepository {
  final ResidentEspaceDatasource _ds;
  const ResidentEspaceRepositoryImpl(this._ds);

  @override
  Future<Either<Failure, List<TacheResident>>> getTaches(
      String residentId) async {
    try {
      return Right(await _ds.getTaches(residentId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, CalendrierMenages>> getCalendrier({
    required String residentId,
    required DateTime debut,
    required DateTime fin,
  }) async {
    try {
      return Right(await _ds.getCalendrier(
          residentId: residentId, debut: debut, fin: fin));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<DemandeResident>>> getDemandes(
      String residentId) async {
    try {
      return Right(await _ds.getDemandes(residentId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, DemandeResident>> creerDemande({
    required String residentId,
    required String residentPrenom,
    required String residentNom,
    required TypeDemande type,
    String? tacheJourId,
    required String motif,
    bool estUrgente = false,
    String? propositionNotes,
    bool? propositionHasAnimal,
    String? propositionTypeAnimal,
  }) async {
    try {
      return Right(await _ds.creerDemande(
        residentId: residentId,
        residentPrenom: residentPrenom,
        residentNom: residentNom,
        type: type,
        tacheJourId: tacheJourId,
        motif: motif,
        estUrgente: estUrgente,
        propositionNotes: propositionNotes,
        propositionHasAnimal: propositionHasAnimal,
        propositionTypeAnimal: propositionTypeAnimal,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, DemandeResident>> accepterProposition({
    required String demandeId,
    required String residentPrenom,
    required String residentNom,
  }) async {
    try {
      return Right(await _ds.accepterProposition(
        demandeId: demandeId,
        residentPrenom: residentPrenom,
        residentNom: residentNom,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, DemandeResident>> refuserProposition({
    required String demandeId,
    required String residentPrenom,
    required String residentNom,
  }) async {
    try {
      return Right(await _ds.refuserProposition(
        demandeId: demandeId,
        residentPrenom: residentPrenom,
        residentNom: residentNom,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<NotificationResident>>> getNotificationsResident(
      String residentId) async {
    try {
      return Right(await _ds.getNotificationsResident(residentId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> marquerNotificationLue(String notifId) async {
    try {
      await _ds.marquerNotificationLue(notifId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<DemandeResident>>> getAllDemandes() async {
    try {
      return Right(await _ds.getAllDemandes());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, DemandeResident>> repondreDemandeResident({
    required String demandeId,
    required String reponse,
    DateTime? propositionDate,
    String? propositionPeriode,
  }) async {
    try {
      return Right(await _ds.repondreDemandeResident(
        demandeId: demandeId,
        reponse: reponse,
        propositionDate: propositionDate,
        propositionPeriode: propositionPeriode,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, DemandeResident>> validerInfoAppartement({
    required String demandeId,
  }) async {
    try {
      return Right(await _ds.validerInfoAppartement(demandeId: demandeId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, DemandeResident>> refuserInfoAppartement({
    required String demandeId,
    required String reponse,
  }) async {
    try {
      return Right(await _ds.refuserInfoAppartement(
        demandeId: demandeId,
        reponse: reponse,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
