import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/appartement_model.dart';

abstract class AppartementsDatasource {
  Future<List<AppartementModel>> getAppartements();
  Future<AppartementModel> addAppartement({
    required String numero,
    required String taille,
    required int minutesBase,
  });
  Future<AppartementModel> updateAppartement({
    required String id,
    required String numero,
    required String taille,
    required int minutesBase,
  });
  Future<void> deleteAppartement(String id);
}

class AppartementsDatasourceImpl implements AppartementsDatasource {
  @override
  Future<List<AppartementModel>> getAppartements() async {
    try {
      final response = await SupabaseService.table(SupabaseService.appartements)
          .select()
          .order('numero');
      return (response as List)
          .map((e) => AppartementModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Erreur chargement appartements : $e');
    }
  }

  @override
  Future<AppartementModel> addAppartement({
    required String numero,
    required String taille,
    required int minutesBase,
  }) async {
    try {
      final response = await SupabaseService.table(SupabaseService.appartements)
          .insert({'numero': numero, 'taille': taille, 'minutes_base': minutesBase})
          .select()
          .single();
      return AppartementModel.fromJson(response);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('duplicate') || msg.contains('unique')) {
        throw DoublonException('Le numéro d\'appartement $numero existe déjà');
      }
      throw ServerException('Erreur ajout appartement : $e');
    }
  }

  @override
  Future<AppartementModel> updateAppartement({
    required String id,
    required String numero,
    required String taille,
    required int minutesBase,
  }) async {
    try {
      final response = await SupabaseService.table(SupabaseService.appartements)
          .update({'numero': numero, 'taille': taille, 'minutes_base': minutesBase})
          .eq('id', id)
          .select()
          .single();
      return AppartementModel.fromJson(response);
    } catch (e) {
      throw ServerException('Erreur modification appartement : $e');
    }
  }

  @override
  Future<void> deleteAppartement(String id) async {
    try {
      await SupabaseService.table(SupabaseService.appartements)
          .delete()
          .eq('id', id);
    } catch (e) {
      throw ServerException('Erreur suppression appartement : $e');
    }
  }
}
