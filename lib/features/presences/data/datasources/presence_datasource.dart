import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/presence_model.dart';
import '../../domain/entities/presence.dart';

abstract class PresenceDatasource {
  Future<PresenceModel> confirmerPresence({
    required String employeeId,
    required DateTime date,
    required StatutPresence statut,
  });

  Future<PresenceModel?> getMaPresence({
    required String employeeId,
    required DateTime date,
  });

  Future<List<PresenceModel>> getAbsencesDuJour(DateTime date);

  Future<void> envoyerAlerteResponsable({
    required String presenceId,
    required List<String> responsableIds,
    required String message,
    required String entityId,
  });
}

class PresenceDatasourceImpl implements PresenceDatasource {
  // Deux FK vers employees (employee_id + valide_par) → préciser laquelle
  static const _join = '*, employees!employee_id(id, nom, prenom, slug, role, is_actif)';
  static const _joinSimple = '*';

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<PresenceModel> confirmerPresence({
    required String employeeId,
    required DateTime date,
    required StatutPresence statut,
  }) async {
    try {
      final dateStr = _dateStr(date);

      // Upsert sur la contrainte unique (employee_id, date)
      final data = await SupabaseService
          .table(SupabaseService.presences)
          .upsert(
            {
              'employee_id': employeeId,
              'date': dateStr,
              'statut': statut.label,
              'confirme_le': DateTime.now().toIso8601String(),
              'alerte_responsable_envoyee': false,
            },
            onConflict: 'employee_id,date',
          )
          .select(_joinSimple)
          .single();

      return PresenceModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<PresenceModel?> getMaPresence({
    required String employeeId,
    required DateTime date,
  }) async {
    try {
      final data = await SupabaseService
          .table(SupabaseService.presences)
          .select(_joinSimple)
          .eq('employee_id', employeeId)
          .eq('date', _dateStr(date))
          .maybeSingle();

      return data != null ? PresenceModel.fromJson(data) : null;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<PresenceModel>> getAbsencesDuJour(DateTime date) async {
    try {
      final data = await SupabaseService
          .table(SupabaseService.presences)
          .select(_join)
          .eq('date', _dateStr(date))
          .neq('statut', StatutPresence.present.label)
          .order('confirme_le');

      return (data as List)
          .map((e) => PresenceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> envoyerAlerteResponsable({
    required String presenceId,
    required List<String> responsableIds,
    required String message,
    required String entityId,
  }) async {
    try {
      // Marquer alerte envoyée
      await SupabaseService
          .table(SupabaseService.presences)
          .update({'alerte_responsable_envoyee': true})
          .eq('id', presenceId);

      // Insérer notifications pour chaque responsable
      if (responsableIds.isNotEmpty) {
        final rows = responsableIds
            .map((id) => {
                  'destinataire_id': id,
                  'type': 'Absence',
                  'message': message,
                  'entity_id': entityId,
                  'entity_type': 'Presence',
                })
            .toList();
        await SupabaseService
            .table(SupabaseService.notifications)
            .insert(rows);
      }
    } catch (_) {
      // Silencieux — la notification n'est pas critique
    }
  }
}
