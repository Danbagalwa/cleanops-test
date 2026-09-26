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
      final data = await SupabaseService.table(
              SupabaseService.tachesDisponibles)
          .select(_joinTache)
          .eq('statut', StatutDisponible.disponible.label)
          .or('visibilite.eq.TouteEquipe,employee_visible_id.eq.$employeeId');

      // À partir de `date` : un ménage d'un jour déjà passé ne peut plus être
      // pris (avant, toute la semaine en cours restait affichée, lundi
      // compris un jeudi). Les jours à venir, même la semaine suivante,
      // restent proposés.
      final dateOnly = DateTime(date.year, date.month, date.day);

      final taches = (data as List)
          .map((e) => TacheDisponibleModel.fromJson(e as Map<String, dynamic>))
          .where((td) {
        final tj = td.tacheJour;
        if (tj == null) return false;
        // Ne pas afficher à l'employée ses propres tâches libérées
        if (tj.employeeId == employeeId) return false;
        return !tj.dateDuJour!.isBefore(dateOnly);
      }).toList()
        // Du plus proche au plus lointain : matin avant après-midi.
        ..sort((a, b) {
          final da = a.tacheJour!.dateDuJour ?? a.tacheJour!.semaineReelle;
          final db = b.tacheJour!.dateDuJour ?? b.tacheJour!.semaineReelle;
          final c = da.compareTo(db);
          if (c != 0) return c;
          return a.tacheJour!.periode.index
              .compareTo(b.tacheJour!.periode.index);
        });
      return taches;
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

      final data =
          await SupabaseService.table(SupabaseService.tachesDisponibles)
              .insert(row)
              .select(_joinTache)
              .single();

      final result = TacheDisponibleModel.fromJson(data);

      final numero = result.tacheJour?.appartement?.numero;
      final message = numero != null
          ? 'Tâche disponible — Apt $numero'
          : 'Une tâche est disponible pour l\'équipe.';

      if (employeeVisibleId != null) {
        await _notifierEmployes(
          employeeIds: [employeeVisibleId],
          message: message,
          entityId: result.id,
        );
      } else {
        final actifs = await SupabaseService.client
            .from(SupabaseService.employees)
            .select('id')
            .eq('is_actif', true)
            .neq('id', libereParId);
        final ids = (actifs as List).map((e) => e['id'] as String).toList();
        await _notifierEmployes(
          employeeIds: ids,
          message: message,
          entityId: result.id,
        );
      }

      return result;
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

      final updated =
          await SupabaseService.table(SupabaseService.tachesDisponibles)
              .select(_joinTache)
              .eq('id', tacheDisponibleId)
              .single();

      final result = TacheDisponibleModel.fromJson(updated);

      if (result.libereParId != null && result.libereParId != employeeId) {
        final numero = result.tacheJour?.appartement?.numero;
        final message = numero != null
            ? 'Votre tâche Apt $numero a été prise en charge par un collègue.'
            : 'Une de vos tâches libérées a été prise en charge.';
        await _notifierEmployes(
          employeeIds: [result.libereParId!],
          message: message,
          entityId: result.id,
          type: 'Transfert',
        );
      }

      return result;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  Future<void> _notifierEmployes({
    required List<String> employeeIds,
    required String message,
    required String entityId,
    String type = 'TacheDisponible',
  }) async {
    if (employeeIds.isEmpty) return;
    try {
      final rows = employeeIds
          .map((id) => {
                'destinataire_id': id,
                'type': type,
                'message': message,
                'entity_id': entityId,
                'entity_type': 'TacheDisponible',
              })
          .toList();
      await SupabaseService.table(SupabaseService.notifications).insert(rows);
    } catch (_) {
      // Silencieux — la notification n'est pas critique
    }
  }
}
