import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/helpers/semaine_helper.dart';
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
  static const _join = '*, appartements(id, numero, taille, minutes_base)';
  static const _joursNoms = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
  ];

  @override
  Future<List<TacheJourModel>> getTachesDuJour({
    required String employeeId,
    required String dateStr,
  }) async {
    try {
      final existing = await _query(employeeId, dateStr);
      if (existing.isNotEmpty) return existing;

      // Aucune tâche pour ce jour — générer depuis les planning_templates
      await _genererDepuisTemplates(employeeId, dateStr);

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

  Future<void> _genererDepuisTemplates(
      String employeeId, String dateStr) async {
    final date = DateTime.parse(dateStr);
    final nomJour = _joursNoms[date.weekday - 1];
    final numeroSemaine = SemaineHelper.semainePourDate(date);

    final templates = await SupabaseService
        .table(SupabaseService.planningTemplates)
        .select('*')
        .eq('employee_id', employeeId)
        .eq('numero_semaine', numeroSemaine)
        .eq('jour', nomJour)
        .order('numero_tache');

    final list = templates as List;
    if (list.isEmpty) return;

    final rows = list.map<Map<String, dynamic>>((t) => {
          'planning_template_id': t['id'],
          'employee_id': employeeId,
          'appartement_id': t['appartement_id'],
          'numero_semaine': t['numero_semaine'] as int,
          'semaine_reelle': dateStr,
          'jour': nomJour,
          'periode': t['periode'],
          'numero_tache': t['numero_tache'] as int,
          'statut': StatutTache.nonCommence.label,
          'is_transfert_temp': false,
          'is_ajoutee': false,
        }).toList();

    await SupabaseService
        .table(SupabaseService.tachesJour)
        .upsert(
          rows,
          onConflict: 'planning_template_id,semaine_reelle',
          ignoreDuplicates: true,
        );
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
