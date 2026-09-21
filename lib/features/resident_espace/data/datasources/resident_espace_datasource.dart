import '../../../../core/errors/exceptions.dart';
import '../../../../core/helpers/semaine_helper.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../domain/entities/demande_resident.dart';
import '../../domain/menages_depuis_arrivee.dart';
import '../models/demande_resident_model.dart';
import '../models/notification_resident_model.dart';
import '../models/tache_resident_model.dart';

// ── Helpers date fr ───────────────────────────────────────
const _kJours = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const _joursPlanning = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];
const _kMois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String _fmtDateFr(DateTime d) =>
    '${_kJours[d.weekday - 1]} ${d.day} ${_kMois[d.month - 1]}';

String _periodeFr(String? p) => p == 'AM' ? 'Matin' : 'Après-midi';

String _typeDemandeLabel(TypeDemande t) => switch (t) {
      TypeDemande.reprogrammer => 'reprogrammer un ménage',
      TypeDemande.annuler => 'annuler un ménage',
      TypeDemande.commentaire => 'a laissé un commentaire',
      TypeDemande.infoAppartement => 'informations sur l\'appartement',
    };

// ─────────────────────────────────────────────────────────

abstract class ResidentEspaceDatasource {
  Future<List<TacheResidentModel>> getTaches(String residentId);
  Future<List<DemandeResidentModel>> getDemandes(String residentId);
  Future<DemandeResidentModel> creerDemande({
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

  /// Valide la proposition d'infos appartement : applique notes/animal sur
  /// l'appartement du résident et résout la demande.
  Future<DemandeResidentModel> validerInfoAppartement({
    required String demandeId,
  });

  /// Refuse la proposition d'infos appartement sans l'appliquer.
  Future<DemandeResidentModel> refuserInfoAppartement({
    required String demandeId,
    required String reponse,
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
      'date_creation, proposition_notes, proposition_has_animal, '
      'proposition_type_animal';

  static const _kSelectNotif =
      'id, resident_id, tache_jour_id, type, message, is_lue, date_envoi';

  // ── Tâches ────────────────────────────────────────────────

  @override
  Future<List<TacheResidentModel>> getTaches(String residentId) async {
    try {
      final residentRow = await SupabaseService.client
          .from(SupabaseService.residents)
          .select('appartement_id, date_arrivee')
          .eq('id', residentId)
          .single();
      final appartementId = residentRow['appartement_id'] as String;
      // Un nouveau résident ne voit jamais les ménages d'avant son arrivée.
      final dateArrivee = residentRow['date_arrivee'] as String?;

      final maintenant = DateTime.now();
      final aujourdhui =
          DateTime(maintenant.year, maintenant.month, maintenant.day)
              .toIso8601String()
              .substring(0, 10);

      // Deux lectures ciblées garantissent un véritable dernier ménage,
      // même s'il date de plus de huit semaines, et une liste future légère.
      final dernierEffectue = await SupabaseService.client
          .from(SupabaseService.tachesJour)
          .select(_kSelectTache)
          .eq('appartement_id', appartementId)
          .eq('statut', 'Fait')
          .order('semaine_reelle', ascending: false)
          .limit(1);

      final tachesFutures = await SupabaseService.client
          .from(SupabaseService.tachesJour)
          .select(_kSelectTache)
          .eq('appartement_id', appartementId)
          .gte('semaine_reelle', aujourdhui)
          .order('semaine_reelle', ascending: true);

      final lignesFutures = List<Map<String, dynamic>>.from(tachesFutures);
      final datesDejaGenerees =
          lignesFutures.map((row) => row['semaine_reelle'] as String).toSet();
      final menagesReels = lignesFutures
          .where((row) => row['statut'] == 'NonCommencé')
          .map(TacheResidentModel.fromJson)
          .toList();

      // Les tâches journalières ne sont générées qu'à l'ouverture de la
      // semaine par la préposée. On projette donc le planning récurrent pour
      // que le résident voie ses rendez-vous futurs immédiatement.
      final templates = await SupabaseService.client
          .from(SupabaseService.planningTemplates)
          .select(
            'id, numero_semaine, jour, periode, '
            'employees!planning_templates_employee_id_fkey(prenom)',
          )
          .eq('appartement_id', appartementId);

      final projections = <TacheResidentModel>[];
      final debutProjection =
          DateTime(maintenant.year, maintenant.month, maintenant.day);
      final finProjection = debutProjection.add(const Duration(days: 365));
      final templatesList = List<Map<String, dynamic>>.from(templates);

      for (var date = debutProjection;
          !date.isAfter(finProjection);
          date = date.add(const Duration(days: 1))) {
        final dateStr = date.toIso8601String().substring(0, 10);
        if (datesDejaGenerees.contains(dateStr)) continue;

        final nomJour = _joursPlanning[date.weekday - 1];
        for (final template in templatesList) {
          if (template['numero_semaine'] ==
                  SemaineHelper.semainePourDate(date) &&
              template['jour'] == nomJour) {
            projections.add(
              TacheResidentModel.fromPlanningTemplate(
                json: template,
                appartementId: appartementId,
                date: date,
              ),
            );
          }
        }
      }

      final menagesAVenir = [...menagesReels, ...projections]
        ..sort((a, b) => a.dateReelle.compareTo(b.dateReelle));
      final data = menagesDepuisArrivee(
        List<Map<String, dynamic>>.from(dernierEffectue as List),
        dateArrivee,
      )
          .map(TacheResidentModel.fromJson)
          .toList()
        ..addAll(menagesAVenir);

      return data;
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
      final data = await SupabaseService.client
          .from(SupabaseService.demandesResidents)
          .insert({
            'resident_id': residentId,
            'type': type.label,
            'tache_jour_id': tacheJourId,
            'motif': motif.trim(),
            'statut': 'EnAttente',
            'est_urgente': estUrgente,
            'proposition_notes': propositionNotes,
            'proposition_has_animal': propositionHasAnimal,
            'proposition_type_animal': propositionTypeAnimal,
          })
          .select(_kSelectDemande)
          .single();
      final demande = DemandeResidentModel.fromJson(data);

      final message = estUrgente
          ? 'Urgent — $residentPrenom $residentNom : ${_typeDemandeLabel(type)}'
          : '$residentPrenom $residentNom : ${_typeDemandeLabel(type)}';

      await _notifierResponsables(demande.id, message);

      return demande;
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
        message = 'Mme $residentPrenom a accepté le '
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
        message = 'Mme $residentPrenom a refusé le '
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
          .update({'is_lue': true}).eq('id', notifId);
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
        message = 'Nouveau ménage proposé : '
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

  @override
  Future<DemandeResidentModel> validerInfoAppartement({
    required String demandeId,
  }) async {
    try {
      final demandeRow = await SupabaseService.client
          .from(SupabaseService.demandesResidents)
          .select(_kSelectDemande)
          .eq('id', demandeId)
          .single();
      final demande = DemandeResidentModel.fromJson(demandeRow);

      final residentRow = await SupabaseService.client
          .from(SupabaseService.residents)
          .select('appartement_id')
          .eq('id', demande.residentId)
          .single();
      final appartementId = residentRow['appartement_id'] as String;

      await SupabaseService.client
          .from(SupabaseService.appartements)
          .update({
            'notes': demande.propositionNotes,
            'has_animal': demande.propositionHasAnimal ?? false,
            'type_animal': demande.propositionHasAnimal == true
                ? demande.propositionTypeAnimal
                : null,
          })
          .eq('id', appartementId);

      final data = await SupabaseService.client
          .from(SupabaseService.demandesResidents)
          .update({
            'statut': 'Resolue',
            'reponse':
                'Informations validées et appliquées à votre appartement.',
            'date_resolution': DateTime.now().toIso8601String(),
            'date_reponse': DateTime.now().toIso8601String(),
          })
          .eq('id', demandeId)
          .select(_kSelectDemande)
          .single();

      final updated = DemandeResidentModel.fromJson(data);

      await SupabaseService.client
          .from(SupabaseService.notificationsResidents)
          .insert({
        'resident_id': demande.residentId,
        'type': 'ChangementDate',
        'message': 'Les informations de votre appartement ont été validées.',
        'is_lue': false,
      });

      return updated;
    } catch (e) {
      throw ServerException('Erreur validation infos appartement : $e');
    }
  }

  @override
  Future<DemandeResidentModel> refuserInfoAppartement({
    required String demandeId,
    required String reponse,
  }) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.demandesResidents)
          .update({
            'statut': 'Resolue',
            'reponse': reponse,
            'date_resolution': DateTime.now().toIso8601String(),
            'date_reponse': DateTime.now().toIso8601String(),
          })
          .eq('id', demandeId)
          .select(_kSelectDemande)
          .single();

      final demande = DemandeResidentModel.fromJson(data);

      await SupabaseService.client
          .from(SupabaseService.notificationsResidents)
          .insert({
        'resident_id': demande.residentId,
        'type': 'ChangementDate',
        'message':
            'Votre proposition d\'informations sur l\'appartement a été refusée : $reponse',
        'is_lue': false,
      });

      return demande;
    } catch (e) {
      throw ServerException('Erreur refus infos appartement : $e');
    }
  }

  // ── Helpers privés ────────────────────────────────────────

  Future<void> _notifierResponsables(
    String demandeId,
    String message, {
    String type = 'DemandeRepondue',
  }) async {
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
              'type': type,
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
}
