import 'package:flutter/foundation.dart' show visibleForTesting;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/helpers/semaine_helper.dart';
import '../../../../core/services/generation_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/semaine_model.dart';

abstract class EmployeeDashboardDatasource {
  Future<SemaineModel> getSemaineCourante({required String employeeId});
  Future<String?> getMessageSemaine();
}

class EmployeeDashboardDatasourceImpl implements EmployeeDashboardDatasource {
  const EmployeeDashboardDatasourceImpl();

  /// Retire les tâches dont l'identifiant figure dans [liberees] (tâches
  /// libérées à l'équipe, pas encore prises).
  @visibleForTesting
  static List<Map<String, dynamic>> sansTachesLiberees(
    List<Map<String, dynamic>> taches,
    Set<String> liberees,
  ) =>
      taches.where((t) => !liberees.contains(t['id'])).toList();

  @override
  Future<SemaineModel> getSemaineCourante({
    required String employeeId,
  }) async {
    try {
      final lundi = SemaineHelper.lundiCourant;
      final vendredi = lundi.add(const Duration(days: 4));
      final numeroSemaine = SemaineHelper.semaineCourante;
      final lundiStr = lundi.toIso8601String().split('T')[0];
      final vendrediStr = vendredi.toIso8601String().split('T')[0];

      // Première lecture : taches déjà générées ?
      var taches = List<Map<String, dynamic>>.from(
        await SupabaseService.table(SupabaseService.tachesJour)
            .select('*, appartements(numero, taille, minutes_base)')
            .eq('employee_id', employeeId)
            .gte('semaine_reelle', lundiStr)
            .lte('semaine_reelle', vendrediStr)
            .order('numero_tache'),
      );

      // Filet de sécurité : la génération est normalement faite par pg_cron.
      // Si aucune tâche n'existe pour la semaine, le serveur crée ce qui manque.
      if (taches.isEmpty) {
        await GenerationService.assurerTachesSemaine(lundi);
        taches = List<Map<String, dynamic>>.from(
          await SupabaseService.table(SupabaseService.tachesJour)
              .select('*, appartements(numero, taille, minutes_base)')
              .eq('employee_id', employeeId)
              .gte('semaine_reelle', lundiStr)
              .lte('semaine_reelle', vendrediStr)
              .order('numero_tache'),
        );
      }

      // Une tâche libérée à l'équipe (pool, statut Disponible) n'est plus celle
      // de la préposée : elle n'est pas comptée, comme dans « Ma Journée » et
      // dans les rappels. Filtré APRÈS le filet de sécurité ci-dessus : une
      // semaine dont toutes les tâches sont libérées n'est pas une semaine vide.
      if (taches.isNotEmpty) {
        final pool = await SupabaseService.table(
                SupabaseService.tachesDisponibles)
            .select('tache_jour_id')
            .eq('statut', 'Disponible')
            .inFilter(
              'tache_jour_id',
              taches.map((t) => t['id'] as String).toList(),
            );
        taches = sansTachesLiberees(
          taches,
          (pool as List).map((r) => r['tache_jour_id'] as String).toSet(),
        );
      }

      // Construire les 5 jours
      final jours = <JourSemaineModel>[];
      final nomsJours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];

      for (int i = 0; i < 5; i++) {
        final date = lundi.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];
        final tachesJour =
            taches.where((t) => t['semaine_reelle'] == dateStr).toList();

        jours.add(JourSemaineModel.fromTaches(
          date: date,
          nom: nomsJours[i],
          taches: tachesJour,
        ));
      }

      return SemaineModel(
        numeroSemaine: numeroSemaine,
        lundiDate: lundi,
        jours: jours,
      );
    } catch (e) {
      throw ServerException('Erreur chargement semaine : $e');
    }
  }

  @override
  Future<String?> getMessageSemaine() async {
    try {
      final response =
          await SupabaseService.table(SupabaseService.messagesSemaine)
              .select('contenu')
              .eq('is_actif', true)
              .maybeSingle();

      return response?['contenu'] as String?;
    } catch (e) {
      return null;
    }
  }
}
