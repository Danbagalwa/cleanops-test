import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/demande_resident.dart';
import '../entities/jour_menage.dart';
import '../entities/notification_resident.dart';
import '../entities/tache_resident.dart';

abstract class ResidentEspaceRepository {
  // ── Tâches ────────────────────────────────────────────────
  Future<Either<Failure, List<TacheResident>>> getTaches(String residentId);

  /// Calendrier des ménages du [debut] au [fin] inclus.
  Future<Either<Failure, CalendrierMenages>> getCalendrier({
    required String residentId,
    required DateTime debut,
    required DateTime fin,
  });

  // ── Demandes résident ─────────────────────────────────────
  Future<Either<Failure, List<DemandeResident>>> getDemandes(String residentId);

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

  /// Valide la proposition d'infos appartement (applique notes/animal).
  Future<Either<Failure, DemandeResident>> validerInfoAppartement({
    required String demandeId,
  });

  /// Refuse la proposition d'infos appartement.
  Future<Either<Failure, DemandeResident>> refuserInfoAppartement({
    required String demandeId,
    required String reponse,
  });
}
