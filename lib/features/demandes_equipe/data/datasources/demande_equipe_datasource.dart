import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../auth/domain/entities/employee.dart';
import '../../domain/entities/demande_equipe.dart';
import '../../domain/entities/document_demande.dart';
import '../models/demande_equipe_model.dart';

abstract class DemandeEquipeDatasource {
  Future<List<DemandeEquipeModel>> getMesDemandes(String employeeId);

  Future<DemandeEquipeModel> creerDemande({
    required String employeeId,
    required String employeePrenom,
    required String employeeNom,
    required TypeDemandeEquipe type,
    required DateTime dateDebut,
    DateTime? dateFin,
    required String motif,
  });

  Future<List<DemandeEquipeModel>> getAllDemandes();

  Future<DemandeEquipeModel> traiterDemande({
    required String demandeId,
    required String traiteParId,
    required bool approuve,
    String? note,
  });

  /// Joint (ou remplace, avant traitement) le document d'une demande.
  Future<void> joindreDocument({
    required String demandeId,
    required String employeeId,
    required String nom,
    required String typeMime,
    required Uint8List octets,
  });

  /// Lit le contenu du document d'une demande.
  Future<DocumentDemande> lireDocument(String demandeId);
}

class DemandeEquipeDatasourceImpl implements DemandeEquipeDatasource {
  static const _join = '*, '
      'employees!demandes_equipe_employee_id_fkey(id, nom, prenom, slug, role, is_actif), '
      'traite_par_employee:employees!demandes_equipe_traite_par_fkey(id, nom, prenom, slug, role, is_actif), '
      'demandes_equipe_documents(nom, type_mime, taille)';

  /// Les refus métier du serveur (code P0001) sont déjà rédigés pour
  /// l'utilisateur ; toute autre erreur reçoit un message générique.
  String _message(PostgrestException e, String parDefaut) =>
      e.code == 'P0001' && e.message.isNotEmpty ? e.message : parDefaut;

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _typeLabel(TypeDemandeEquipe t) => switch (t) {
        TypeDemandeEquipe.conge => 'un congé',
        TypeDemandeEquipe.absencePlanifiee => 'une absence planifiée',
      };

  @override
  Future<List<DemandeEquipeModel>> getMesDemandes(String employeeId) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.demandesEquipe)
          .select(_join)
          .eq('employee_id', employeeId)
          .order('date_creation', ascending: false);
      return (data as List)
          .map((j) => DemandeEquipeModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Erreur chargement demandes : $e');
    }
  }

  @override
  Future<DemandeEquipeModel> creerDemande({
    required String employeeId,
    required String employeePrenom,
    required String employeeNom,
    required TypeDemandeEquipe type,
    required DateTime dateDebut,
    DateTime? dateFin,
    required String motif,
  }) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.demandesEquipe)
          .insert({
            'employee_id': employeeId,
            'type': type.label,
            'date_debut': _dateStr(dateDebut),
            'date_fin': dateFin != null ? _dateStr(dateFin) : null,
            'motif': motif.trim(),
            'statut': 'EnAttente',
          })
          .select(_join)
          .single();
      final demande = DemandeEquipeModel.fromJson(data);

      final periode = dateFin != null
          ? 'du ${_dateStr(dateDebut)} au ${_dateStr(dateFin)}'
          : 'le ${_dateStr(dateDebut)}';
      await _notifierResponsables(
        '$employeePrenom $employeeNom demande ${_typeLabel(type)} — $periode.',
      );

      return demande;
    } catch (e) {
      throw ServerException('Erreur envoi demande : $e');
    }
  }

  @override
  Future<List<DemandeEquipeModel>> getAllDemandes() async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.demandesEquipe)
          .select(_join)
          .order('date_creation', ascending: false);
      return (data as List)
          .map((j) => DemandeEquipeModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Erreur chargement toutes demandes : $e');
    }
  }

  @override
  Future<DemandeEquipeModel> traiterDemande({
    required String demandeId,
    required String traiteParId,
    required bool approuve,
    String? note,
  }) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.demandesEquipe)
          .update({
            'statut': 'Resolue',
            'approuve': approuve,
            'note_responsable': note,
            'traite_par': traiteParId,
            'date_traitement': DateTime.now().toIso8601String(),
          })
          .eq('id', demandeId)
          .select(_join)
          .single();
      final demande = DemandeEquipeModel.fromJson(data);

      final message = approuve
          ? 'Votre demande de ${_typeLabel(demande.type)} a été approuvée.'
          : 'Votre demande de ${_typeLabel(demande.type)} a été refusée.';

      await _notifierEmploye(
        demande.employeeId,
        note != null && note.isNotEmpty ? '$message — $note' : message,
      );

      return demande;
    } catch (e) {
      throw ServerException('Erreur traitement demande : $e');
    }
  }

  /// Bucket Storage des documents joints (voir migration 202609230033) : les
  /// octets y sont envoyés directement, seules les métadonnées passent par la
  /// table `demandes_equipe_documents`.
  static const _bucketDocuments = 'documents-demandes-equipe';

  @override
  Future<void> joindreDocument({
    required String demandeId,
    required String employeeId,
    required String nom,
    required String typeMime,
    required Uint8List octets,
  }) async {
    try {
      await SupabaseService.client.storage.from(_bucketDocuments).uploadBinary(
            demandeId,
            octets,
            fileOptions: FileOptions(contentType: typeMime, upsert: true),
          );
    } on StorageException catch (e) {
      throw ServerException(
        e.message.isNotEmpty ? e.message : "Le document n'a pas pu être envoyé.",
      );
    } catch (_) {
      throw const ServerException("Le document n'a pas pu être envoyé.");
    }

    const erreur = "Le document n'a pas pu être joint.";
    try {
      await SupabaseService.client.rpc(
        'enregistrer_document_demande',
        params: {
          'p_demande_id': demandeId,
          'p_employee_id': employeeId,
          'p_chemin': demandeId,
          'p_nom': nom,
        },
      );
    } on PostgrestException catch (e) {
      await _retirerDuBucket(demandeId);
      throw ServerException(_message(e, erreur));
    } catch (_) {
      await _retirerDuBucket(demandeId);
      throw const ServerException(erreur);
    }
  }

  /// Nettoyage best-effort d'un envoi Storage dont l'enregistrement des
  /// métadonnées a échoué (sinon le fichier reste orphelin, sans conséquence
  /// mais inutile).
  Future<void> _retirerDuBucket(String chemin) async {
    try {
      await SupabaseService.client.storage
          .from(_bucketDocuments)
          .remove([chemin]);
    } catch (_) {
      // Sans conséquence : voir la migration 202609230033.
    }
  }

  @override
  Future<DocumentDemande> lireDocument(String demandeId) async {
    const erreur = 'Impossible de charger le document.';
    Map<String, dynamic>? meta;
    try {
      meta = await SupabaseService.client
          .from('demandes_equipe_documents')
          .select('nom, type_mime')
          .eq('demande_id', demandeId)
          .maybeSingle();
    } catch (_) {
      throw const ServerException(erreur);
    }
    if (meta == null) {
      throw const ServerException('Ce document est introuvable.');
    }

    try {
      final octets = await SupabaseService.client.storage
          .from(_bucketDocuments)
          .download(demandeId);
      return DocumentDemande(
        nom: meta['nom'] as String,
        typeMime: meta['type_mime'] as String,
        octets: octets,
      );
    } catch (_) {
      throw const ServerException(erreur);
    }
  }

  // ── Helpers privés ────────────────────────────────────────

  Future<void> _notifierResponsables(String message) async {
    try {
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
                'entity_type': 'DemandeEquipe',
              })
          .toList();

      if (batch.isNotEmpty) {
        await SupabaseService.client
            .from(SupabaseService.notifications)
            .insert(batch);
      }
    } catch (_) {
      // Silencieux — la notification n'est pas critique
    }
  }

  Future<void> _notifierEmploye(String employeeId, String message) async {
    try {
      await SupabaseService.client.from(SupabaseService.notifications).insert({
        'destinataire_id': employeeId,
        'type': 'DemandeRepondue',
        'message': message,
        'entity_type': 'DemandeEquipe',
      });
    } catch (_) {
      // Silencieux — la notification n'est pas critique
    }
  }
}
