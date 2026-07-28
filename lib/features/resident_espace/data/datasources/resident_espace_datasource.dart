import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../domain/entities/demande_resident.dart';
import '../models/demande_resident_model.dart';
import '../models/notification_resident_model.dart';
import '../models/tache_resident_model.dart';

// ── Helpers date fr ───────────────────────────────────────
const _kJours = [
  'lundi', 'mardi', 'mercredi', 'jeudi',
  'vendredi', 'samedi', 'dimanche',
];
const _kMois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String _fmtDateFr(DateTime d) =>
    '${_kJours[d.weekday - 1]} ${d.day} ${_kMois[d.month - 1]}';

String _periodeFr(String? p) => p == 'AM' ? 'Matin' : 'Après-midi';

// ─────────────────────────────────────────────────────────

abstract class ResidentEspaceDatasource {
  Future<List<TacheResidentModel>> getTaches(String residentId);
  Future<List<DemandeResidentModel>> getDemandes(String residentId);
  Future<DemandeResidentModel> creerDemande({
    required String residentId,
    required TypeDemande type,
    String? tacheJourId,
    required String motif,
    bool estUrgente = false,
  });
  Future<DemandeResidentModel> accepterProposition({
    required String demandeId,
    required String residentPrenom,
    required String residentNom,
  });
  Future<DemandeResidentModel> refuserProposition({
    required String demandeId,
    required String residentPrenom,
    required String residentNom,
  });
  Future<List<NotificationResidentModel>> getNotificationsResident(
      String residentId);
  Future<void> marquerNotificationLue(String notifId);
  Future<List<DemandeResidentModel>> getAllDemandes();
  Future<DemandeResidentModel> repondreDemandeResident({
    required String demandeId,
    required String reponse,
    DateTime? propositionDate,
    String? propositionPeriode,
  });
}

// ─────────────────────────────────────────────────────────

class ResidentEspaceDatasourceImpl implements ResidentEspaceDatasource {
  static const _kSelectTache =
      'id, appartement_id, semaine_reelle, jour, periode, statut, '
      'employees!taches_jour_employee_id_fkey(prenom)';

  static const _kSelectDemande =
      'id, resident_id, type, tache_jour_id, motif, statut, reponse, '
      'proposition_date, proposition_periode, resident_accepte, est_urgente, '
      'date_creation';

  static const _kSelectNotif =
      'id, resident_id, tache_jour_id, type, message, is_lue, date_envoi';

  // ── Tâches ────────────────────────────────────────────────

  @override
  Future<List<TacheResidentModel>> getTaches(String residentId) async {
    try {
      final residentRow = await SupabaseService.client
          .from(SupabaseService.residents)
          .select('appartement_id')
          .eq('id', residentId)
          .single();
      final appartementId = residentRow['appartement_id'] as String;

      final debut = _lundi(DateTime.now().subtract(const Duration(days: 56)));
      final data = await SupabaseService.client
          .from(SupabaseService.tachesJour)
          .select(_kSelectTache)
          .eq('appartement_id', appartementId)
          .gte('semaine_reelle', debut.toIso8601String().substring(0, 10))
          .inFilter('statut', ['Fait', 'NonCommencé'])
          .order('semaine_reelle', ascending: true);

      return (data as List)
          .map((j) => TacheResidentModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Erreur chargement ménages : $e');
    }
  }

  // ── Demandes résident ─────────────────────────────────────

  @override
  Future<List<DemandeResidentModel>> getDemandes(String residentId) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.demandesResidents)
          .select(_kSelectDemande)
          .eq('resident_id', residentId)
          .order('date_creation', ascending: false);
      return (data as List)
          .map((j) => DemandeResidentModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Erreur chargement demandes : $e');
    }
  }

  @override
  Future<DemandeResidentModel> creerDemande({
    required String residentId,
    required TypeDemande type,
    String? tacheJourId,
    required String motif,
    bool estUrgente = false,
  }) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.demandesResidents)
          .insert({
            'resident_id': residentId,
            'type': type.label,
            'tache_jour_id': tacheJourId,
            'motif': motif.trim(),
            'statut': 'EnAttente',
            'est_urgente': estUrgente,
          })
          .select(_kSelectDemande)
          .single();
      return DemandeResidentModel.fromJson(data);
    } catch (e) {
      throw ServerException('Erreur envoi demande : $e');
    }
  }

  @override
  Future<DemandeResidentModel> accepterProposition({
    required String demandeId,
    required String residentPrenom,
    required String residentNom,
  }) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.demandesResidents)
          .update({
            'resident_accepte': true,
            'statut': 'Resolue',
            'date_resolution': DateTime.now().toIso8601String(),
          })
          .eq('id', demandeId)
          .select(_kSelectDemande)
          .single();

      final demande = DemandeResidentModel.fromJson(data);

      String message =
          'Mme $residentPrenom $residentNom a accepté votre proposition.';
      if (demande.propositionDate != null) {
        message =
            'Mme $residentPrenom a accepté le '
            '${_fmtDateFr(demande.propositionDate!)} — '
            '${_periodeFr(demande.propositionPeriode)}';
      }

      await _notifierResponsables(demandeId, message);
      return demande;
    } catch (e) {
      throw ServerException('Erreur acceptation proposition : $e');
    }
  }

  @override
  Future<DemandeResidentModel> refuserProposition({
    required String demandeId,
    required String residentPrenom,
    required String residentNom,
  }) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.demandesResidents)
          .update({'resident_accepte': false})
          .eq('id', demandeId)
          .select(_kSelectDemande)
          .single();

      final demande = DemandeResidentModel.fromJson(data);

      String message =
          'Mme $residentPrenom $residentNom a refusé votre proposition.';
      if (demande.propositionDate != null) {
        message =
            'Mme $residentPrenom a refusé le '
            '${_fmtDateFr(demande.propositionDate!)} — '
            '${_periodeFr(demande.propositionPeriode)}';
      }

      await _notifierResponsables(demandeId, message);
      return demande;
    } catch (e) {
      throw ServerException('Erreur refus proposition : $e');
    }
  }

  // ── Notifications résident ────────────────────────────────

  @override
  Future<List<NotificationResidentModel>> getNotificationsResident(
      String residentId) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.notificationsResidents)
          .select(_kSelectNotif)
          .eq('resident_id', residentId)
          .order('date_envoi', ascending: false)
          .limit(30);
      return (data as List)
          .map((j) =>
              NotificationResidentModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Erreur chargement notifications : $e');
    }
  }

  @override
  Future<void> marquerNotificationLue(String notifId) async {
    try {
      await SupabaseService.client
          .from(SupabaseService.notificationsResidents)
          .update({'is_lue': true})
          .eq('id', notifId);
    } catch (e) {
      throw ServerException('Erreur marquage notification : $e');
    }
  }

  // ── Côté RESPONSABLE ──────────────────────────────────────

  @override
  Future<List<DemandeResidentModel>> getAllDemandes() async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.demandesResidents)
          .select(_kSelectDemande)
          .order('date_creation', ascending: false);
      return (data as List)
          .map((j) => DemandeResidentModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Erreur chargement toutes demandes : $e');
    }
  }

  @override
  Future<DemandeResidentModel> repondreDemandeResident({
    required String demandeId,
    required String reponse,
    DateTime? propositionDate,
    String? propositionPeriode,
  }) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.demandesResidents)
          .update({
            'statut': 'Repondue',
            'reponse': reponse,
            if (propositionDate != null)
              'proposition_date':
                  propositionDate.toIso8601String().substring(0, 10),
            if (propositionPeriode != null)
              'proposition_periode': propositionPeriode,
            'date_reponse': DateTime.now().toIso8601String(),
          })
          .eq('id', demandeId)
          .select(_kSelectDemande)
          .single();

      final demande = DemandeResidentModel.fromJson(data);

      String message = 'Votre demande a reçu une réponse.';
      if (propositionDate != null) {
        message =
            'Nouveau ménage proposé : '
            '${_fmtDateFr(propositionDate)} — '
            '${_periodeFr(propositionPeriode)}';
      }

      await SupabaseService.client
          .from(SupabaseService.notificationsResidents)
          .insert({
            'resident_id': demande.residentId,
            'type': 'ChangementDate',
            'message': message,
            'is_lue': false,
          });

      return demande;
    } catch (e) {
      throw ServerException('Erreur réponse demande : $e');
    }
  }

  // ── Helpers privés ────────────────────────────────────────

  Future<void> _notifierResponsables(
      String demandeId, String message) async {
    final rolesResponsables = RoleType.values
        .where((role) => role.isResponsable)
        .map((role) => role.label)
        .toList();

    final responsables = await SupabaseService.client
        .from(SupabaseService.employees)
        .select('id')
        .inFilter('role', rolesResponsables)
        .eq('is_actif', true);

    final batch = (responsables as List)
        .map((r) => {
              'destinataire_id': r['id'] as String,
              'type': 'DemandeRepondue',
              'message': message,
              'entity_id': demandeId,
              'entity_type': 'Demande',
              'is_lue': false,
            })
        .toList();

    if (batch.isNotEmpty) {
      await SupabaseService.client
          .from(SupabaseService.notifications)
          .insert(batch);
    }
  }

  static DateTime _lundi(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));
}
