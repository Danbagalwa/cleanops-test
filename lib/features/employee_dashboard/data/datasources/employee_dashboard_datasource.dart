import '../../../../core/errors/exceptions.dart';
import '../../../../core/helpers/semaine_helper.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/semaine_model.dart';

abstract class EmployeeDashboardDatasource {
  Future<SemaineModel> getSemaineCourante({required String employeeId});
  Future<String?> getMessageSemaine();
}

class EmployeeDashboardDatasourceImpl implements EmployeeDashboardDatasource {
  const EmployeeDashboardDatasourceImpl();

  static const _joursNoms = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
  ];

  @override
  Future<SemaineModel> getSemaineCourante({
    required String employeeId,
  }) async {
    try {
      final lundi          = SemaineHelper.lundiCourant;
      final vendredi       = lundi.add(const Duration(days: 4));
      final numeroSemaine  = SemaineHelper.semaineCourante;
      final lundiStr       = lundi.toIso8601String().split('T')[0];
      final vendrediStr    = vendredi.toIso8601String().split('T')[0];

      // Première lecture : taches déjà générées ?
      var taches = List<Map<String, dynamic>>.from(
        await SupabaseService
            .table(SupabaseService.tachesJour)
            .select('*, appartements(numero, taille)')
            .eq('employee_id', employeeId)
            .gte('semaine_reelle', lundiStr)
            .lte('semaine_reelle', vendrediStr)
            .order('numero_tache'),
      );

      // Si aucune tâche pour toute la semaine → générer depuis les templates
      if (taches.isEmpty) {
        await _genererSemaine(employeeId, lundi, numeroSemaine);
        taches = List<Map<String, dynamic>>.from(
          await SupabaseService
              .table(SupabaseService.tachesJour)
              .select('*, appartements(numero, taille)')
              .eq('employee_id', employeeId)
              .gte('semaine_reelle', lundiStr)
              .lte('semaine_reelle', vendrediStr)
              .order('numero_tache'),
        );
      }

      // Construire les 5 jours
      final jours = <JourSemaineModel>[];
      final nomsJours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];

      for (int i = 0; i < 5; i++) {
        final date = lundi.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];
        final tachesJour = taches
            .where((t) => t['semaine_reelle'] == dateStr)
            .toList();

        jours.add(JourSemaineModel.fromTaches(
          date:   date,
          nom:    nomsJours[i],
          taches: tachesJour,
        ));
      }

      return SemaineModel(
        numeroSemaine: numeroSemaine,
        lundiDate:     lundi,
        jours:         jours,
      );
    } catch (e) {
      throw ServerException('Erreur chargement semaine : $e');
    }
  }

  // Génère toutes les tâches de la semaine depuis les planning_templates en un seul batch
  Future<void> _genererSemaine(
      String employeeId, DateTime lundi, int numeroSemaine) async {
    final templates = await SupabaseService
        .table(SupabaseService.planningTemplates)
        .select('*')
        .eq('employee_id', employeeId)
        .eq('numero_semaine', numeroSemaine)
        .inFilter('jour', ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'])
        .order('numero_tache');

    final list = templates as List;
    if (list.isEmpty) return;

    final rows = list.map<Map<String, dynamic>>((t) {
      final jourIndex = _joursNoms.indexOf(t['jour'] as String);
      final date = lundi.add(Duration(days: jourIndex < 0 ? 0 : jourIndex));
      final dateStr = date.toIso8601String().split('T')[0];
      return {
        'planning_template_id': t['id'],
        'employee_id': employeeId,
        'appartement_id': t['appartement_id'],
        'numero_semaine': t['numero_semaine'] as int,
        'semaine_reelle': dateStr,
        'jour': t['jour'],
        'periode': t['periode'],
        'numero_tache': t['numero_tache'] as int,
        'statut': 'NonCommencé',
        'is_transfert_temp': false,
        'is_ajoutee': false,
      };
    }).toList();

    await SupabaseService.table(SupabaseService.tachesJour).insert(rows);
  }

  @override
  Future<String?> getMessageSemaine() async {
    try {
      final response = await SupabaseService
          .table(SupabaseService.messagesSemaine)
          .select('contenu')
          .eq('is_actif', true)
          .maybeSingle();

      return response?['contenu'] as String?;
    } catch (e) {
      return null;
    }
  }
}