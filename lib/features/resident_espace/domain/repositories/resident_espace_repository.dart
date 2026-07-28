import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/demande_resident.dart';
import '../entities/notification_resident.dart';
import '../entities/tache_resident.dart';

abstract class ResidentEspaceRepository {
  // ── Tâches ────────────────────────────────────────────────
  Future<Either<Failure, List<TacheResident>>> getTaches(String residentId);

  // ── Demandes résident ─────────────────────────────────────
  Future<Either<Failure, List<DemandeResident>>> getDemandes(String residentId);

  Future<Either<Failure, DemandeResident>> creerDemande({
    required String residentId,
    required TypeDemande type,
    String? tacheJourId,
    required String motif,
    bool estUrgente = false,
  });

  /// Résident accepte la proposition du responsable.
  Future<Either<Failure, DemandeResident>> accepterProposition({
    required String demandeId,
    required String residentPrenom,
    required String residentNom,
  });

  /// Résident refuse la proposition du responsable.
  Future<Either<Failure, DemandeResident>> refuserProposition({
    required String demandeId,
    required String residentPrenom,
    required String residentNom,
  });

  // ── Notifications résident ────────────────────────────────
  Future<Either<Failure, List<NotificationResident>>> getNotificationsResident(
      String residentId);

  Future<Either<Failure, void>> marquerNotificationLue(String notifId);

  // ── Côté RESPONSABLE ──────────────────────────────────────
  Future<Either<Failure, List<DemandeResident>>> getAllDemandes();

  Future<Either<Failure, DemandeResident>> repondreDemandeResident({
    required String demandeId,
    required String reponse,
    DateTime? propositionDate,
    String? propositionPeriode,
  });
}
