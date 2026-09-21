import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/reception_equipe_models.dart';
import '../domain/reception_equipe_repository.dart';
import '../domain/reception_residents_repository.dart' show ReceptionErreur;

/// Implémentation Supabase : un seul appel de FONCTION serveur, jamais de
/// lecture directe de `taches_jour`.
class ReceptionEquipeRepositoryImpl implements ReceptionEquipeRepository {
  const ReceptionEquipeRepositoryImpl();

  static const _erreur = "Impossible de charger l'équipe du jour.";

  @override
  Future<EquipeDuJour> equipeDuJour() async {
    try {
      final data =
          await SupabaseService.client.rpc('reception_equipe_du_jour');
      return EquipeDuJour.fromJson(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw ReceptionErreur(
          e.code == 'P0001' && e.message.isNotEmpty ? e.message : _erreur);
    } catch (_) {
      throw const ReceptionErreur(_erreur);
    }
  }
}
