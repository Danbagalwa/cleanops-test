import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/tache_disponible_model.dart';
import '../../domain/entities/tache_disponible.dart';

abstract class TacheDisponibleDatasource {
  Future<List<TacheDisponibleModel>> getTachesDisponibles({
    required String employeeId,
    required DateTime date,
  });

  Future<TacheDisponibleModel> libererTache({
    required String tacheJourId,
    required String libereParId,
    required MotifDisponible motif,
    String? employeeVisibleId,
  });

  Future<TacheDisponibleModel> prendreEnCharge({
    required String tacheDisponibleId,
    required String employeeId,
  });
}

class TacheDisponibleDatasourceImpl implements TacheDisponibleDatasource {
  static const _joinTache =
      '*, taches_jour(*, appartements(*)), employees:prise_par(id, nom, prenom, slug, role, is_actif)';

  @override
  Future<List<TacheDisponibleModel>> getTachesDisponibles({
    required String employeeId,
    required DateTime date,
  }) async {
    try {
      // Récupérer les tâches disponibles pour ce jour
      // visibilité TouteEquipe OU EmployeSpecifique ciblant cet employé
      final data = await SupabaseService
          .table(SupabaseService.tachesDisponibles)
          .select(_joinTache)
          .eq('statut', StatutDisponible.disponible.label)
          .or('visibilite.eq.TouteEquipe,employee_visible_id.eq.$employeeId');

      // Filtrer sur la semaine contenant `date`
      // semaineReelle = lundi de la semaine → dimanche = lundi + 6 jours
      final monday = DateTime(date.year, date.month, date.day)
          .subtract(Duration(days: date.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final dateOnly = DateTime(date.year, date.month, date.day);

      return (data as List)
          .map((e) => TacheDisponibleModel.fromJson(e as Map<String, dynamic>))
          .where((td) {
        if (td.tacheJour == null) return false;
        // Ne pas afficher à l'employée ses propres tâches libérées
        if (td.tacheJour!.employeeId == employeeId) return false;
        final sr = td.tacheJour!.semaineReelle;
        final srDate = DateTime(sr.year, sr.month, sr.day);
        return !dateOnly.isBefore(srDate) && !dateOnly.isAfter(sunday);
      }).toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TacheDisponibleModel> libererTache({
    required String tacheJourId,
    required String libereParId,
    required MotifDisponible motif,
    String? employeeVisibleId,
  }) async {
    try {
      final row = {
        'tache_jour_id': tacheJourId,
        'motif': motif.label,
        'libere_par': libereParId,
        'date_liberation': DateTime.now().toIso8601String(),
        'statut': StatutDisponible.disponible.label,
        if (employeeVisibleId != null) ...{
          'visibilite': VisibiliteType.employeSpecifique.label,
          'employee_visible_id': employeeVisibleId,
        } else ...{
          'visibilite': VisibiliteType.touteEquipe.label,
        },
      };

      final data = await SupabaseService
          .table(SupabaseService.tachesDisponibles)
          .insert(row)
          .select(_joinTache)
          .single();

      return TacheDisponibleModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TacheDisponibleModel> prendreEnCharge({
    required String tacheDisponibleId,
    required String employeeId,
  }) async {
    try {
      await SupabaseService.client.rpc(
        'take_available_task',
        params: {
          'p_tache_disponible_id': tacheDisponibleId,
          'p_employee_id': employeeId,
        },
      );

      final updated = await SupabaseService
          .table(SupabaseService.tachesDisponibles)
          .select(_joinTache)
          .eq('id', tacheDisponibleId)
          .single();

      return TacheDisponibleModel.fromJson(updated);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
