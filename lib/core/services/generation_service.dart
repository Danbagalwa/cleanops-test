import 'supabase_service.dart';

/// Filet de sécurité : demande au serveur de créer ce qui manque.
///
/// La génération normale est faite par pg_cron (migration
/// 202609190001_generate_tasks_server_side.sql). Ces appels ne servent que si
/// le cron a échoué ou si une semaine est consultée avant d'être générée.
/// Les fonctions SQL sont idempotentes : elles ne créent que les lignes
/// absentes et n'écrasent jamais l'existant.
class GenerationService {
  GenerationService._();

  /// Génère les tâches manquantes de la semaine contenant [date]
  /// (lundi → vendredi, toute l'équipe active).
  static Future<void> assurerTachesSemaine(DateTime date) async {
    await SupabaseService.client.rpc(
      'generer_taches_semaine',
      params: {'p_lundi': _jour(date)},
    );
  }

  /// Génère les zones d'aires communes de la semaine contenant [date]
  /// si cette semaine n'en a encore aucune.
  static Future<void> assurerZonesAiresCommunes(DateTime date) async {
    await SupabaseService.client.rpc(
      'generer_zones_aires_communes',
      params: {'p_lundi': _jour(date)},
    );
  }

  static String _jour(DateTime date) => date.toIso8601String().split('T')[0];
}
