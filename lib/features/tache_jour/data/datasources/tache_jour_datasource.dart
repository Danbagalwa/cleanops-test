import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/generation_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/tache_jour_model.dart';
import '../../domain/entities/tache_jour.dart';

abstract class TacheJourDatasource {
  Future<List<TacheJourModel>> getTachesDuJour({
    required String employeeId,
    required String dateStr,
  });

  Future<TacheJourModel> updateStatut({
    required String id,
    required StatutTache statut,
    String? motifAbsent,
  });
}

class TacheJourDatasourceImpl implements TacheJourDatasource {
  static const _join =
      '*, appartements(id, numero, taille, minutes_base, notes, has_animal, type_animal)';
  @override
  Future<List<TacheJourModel>> getTachesDuJour({
    required String employeeId,
    required String dateStr,
  }) async {
    try {
      final existing = await _query(employeeId, dateStr);
      if (existing.isNotEmpty) return existing;

      // Aucune tâche pour ce jour — demander au serveur ce qui manque
      await _genererDepuisTemplates(dateStr);

      return await _query(employeeId, dateStr);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  Future<List<TacheJourModel>> _query(
      String employeeId, String dateStr) async {
    final data = await SupabaseService
        .table(SupabaseService.tachesJour)
        .select(_join)
        .eq('employee_id', employeeId)
        .eq('semaine_reelle', dateStr)
        .order('periode')
        .order('numero_tache');
    return (data as List)
        .map((e) => TacheJourModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Filet de sécurité : la génération est normalement faite par pg_cron.
  // Le serveur crée les tâches manquantes de la semaine contenant [dateStr].
  Future<void> _genererDepuisTemplates(String dateStr) async {
    await GenerationService.assurerTachesSemaine(DateTime.parse(dateStr));
  }

  @override
  Future<TacheJourModel> updateStatut({
    required String id,
    required StatutTache statut,
    String? motifAbsent,
  }) async {
    try {
      final data = await SupabaseService
          .table(SupabaseService.tachesJour)
          .update({
            'statut': statut.label,
            'motif_absent':
                statut == StatutTache.absent ? motifAbsent : null,
          })
          .eq('id', id)
          .select(_join)
          .single();

      return TacheJourModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
