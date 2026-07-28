import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/planning_template_model.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';

abstract class PlanningDatasource {
  Future<List<PlanningTemplateModel>> getTemplates({String? employeeId});

  Future<PlanningTemplateModel> ajouterSlot({
    required String employeeId,
    required String appartementId,
    required int numeroSemaine,
    required String jour,
    required PeriodeType periode,
    required int numeroTache,
  });

  Future<PlanningTemplateModel> deplacerSlot({
    required String id,
    required String employeeId,
    required String jour,
    required PeriodeType periode,
    required int numeroTache,
  });

  Future<void> supprimerSlot(String id);
}

class PlanningDatasourceImpl implements PlanningDatasource {
  static const _joinAppt =
      '*, appartements(id, numero, taille, minutes_base)';

  @override
  Future<List<PlanningTemplateModel>> getTemplates({
    String? employeeId,
  }) async {
    try {
      var query = SupabaseService
          .table(SupabaseService.planningTemplates)
          .select(_joinAppt);

      if (employeeId != null) {
        query = query.eq('employee_id', employeeId);
      }

      final data = await query
          .order('numero_semaine')
          .order('numero_tache');

      return (data as List)
          .map((e) => PlanningTemplateModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<PlanningTemplateModel> ajouterSlot({
    required String employeeId,
    required String appartementId,
    required int numeroSemaine,
    required String jour,
    required PeriodeType periode,
    required int numeroTache,
  }) async {
    try {
      // Règle : un appartement ne peut être visité qu'une seule fois par jour
      // (toutes périodes confondues, tous préposés confondus)
      final conflits = await SupabaseService
          .table(SupabaseService.planningTemplates)
          .select('id')
          .eq('appartement_id', appartementId)
          .eq('numero_semaine', numeroSemaine)
          .eq('jour', jour);

      if ((conflits as List).isNotEmpty) {
        throw ServerException(
          'Cet appartement est déjà attribué le $jour (Sem. $numeroSemaine). '
          'Chaque appartement ne peut être visité qu\'une seule fois par jour.',
        );
      }

      final data = await SupabaseService
          .table(SupabaseService.planningTemplates)
          .insert({
            'employee_id': employeeId,
            'appartement_id': appartementId,
            'numero_semaine': numeroSemaine,
            'jour': jour,
            'periode': periode.label,
            'numero_tache': numeroTache,
            'minutes_ajustement': 0,
          })
          .select(_joinAppt)
          .single();

      return PlanningTemplateModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<PlanningTemplateModel> deplacerSlot({
    required String id,
    required String employeeId,
    required String jour,
    required PeriodeType periode,
    required int numeroTache,
  }) async {
    try {
      final data = await SupabaseService
          .table(SupabaseService.planningTemplates)
          .update({
            'employee_id': employeeId,
            'jour': jour,
            'periode': periode.label,
            'numero_tache': numeroTache,
          })
          .eq('id', id)
          .select(_joinAppt)
          .single();

      return PlanningTemplateModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> supprimerSlot(String id) async {
    try {
      await SupabaseService
          .table(SupabaseService.planningTemplates)
          .delete()
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
