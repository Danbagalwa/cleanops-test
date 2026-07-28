import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/resident_model.dart';

abstract class ResidentRemoteDatasource {
  Future<List<ResidentModel>> getResidents();
  Future<ResidentModel?> getResidentByAppartement(String appartementId);
  Future<ResidentModel> creerResident(
    String appartementId,
    String nom,
    String prenom,
    bool aApplication,
  );
  Future<ResidentModel> attribuerPin(String residentId, String pin);
  Future<ResidentModel> desactiverResident(
      String residentId, String desactiveParId);
  Future<ResidentModel> activerResident(String residentId);
  Future<ResidentModel> toggleApplication(
      String residentId, bool aApplication);
}

class ResidentRemoteDatasourceImpl implements ResidentRemoteDatasource {
  static const _table = 'residents';

  static const _kSelect =
      'id, appartement_id, nom, prenom, has_pin, a_application, '
      'is_actif, desactive_par, date_desactivation, '
      'date_creation, date_mise_a_jour, '
      'appartements(numero, taille)';

  @override
  Future<List<ResidentModel>> getResidents() async {
    try {
      final data = await SupabaseService.client
          .from(_table)
          .select(_kSelect)
          .order('prenom');
      return (data as List)
          .map((j) => ResidentModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Erreur chargement résidents : $e');
    }
  }

  @override
  Future<ResidentModel?> getResidentByAppartement(
      String appartementId) async {
    try {
      final data = await SupabaseService.client
          .from(_table)
          .select(_kSelect)
          .eq('appartement_id', appartementId)
          .eq('is_actif', true)
          .maybeSingle();
      if (data == null) return null;
      return ResidentModel.fromJson(data);
    } catch (e) {
      throw ServerException('Erreur recherche résident : $e');
    }
  }

  @override
  Future<ResidentModel> creerResident(
    String appartementId,
    String nom,
    String prenom,
    bool aApplication,
  ) async {
    try {
      final data = await SupabaseService.client
          .from(_table)
          .insert({
            'appartement_id': appartementId,
            'nom': nom.trim(),
            'prenom': prenom.trim(),
            'a_application': aApplication,
          })
          .select(_kSelect)
          .single();
      return ResidentModel.fromJson(data);
    } catch (e) {
      throw ServerException('Erreur création résident : $e');
    }
  }

  @override
  Future<ResidentModel> attribuerPin(
      String residentId, String pin) async {
    try {
      final data = await SupabaseService.client
          .from(_table)
          .update({'pin_hash': pin})
          .eq('id', residentId)
          .select(_kSelect)
          .single();
      return ResidentModel.fromJson(data);
    } catch (e) {
      throw ServerException('Erreur attribution PIN : $e');
    }
  }

  @override
  Future<ResidentModel> desactiverResident(
      String residentId, String desactiveParId) async {
    try {
      final data = await SupabaseService.client
          .from(_table)
          .update({
            'is_actif': false,
            'desactive_par': desactiveParId,
            'date_desactivation': DateTime.now().toUtc().toIso8601String(),
            'pin_hash': null,
          })
          .eq('id', residentId)
          .select(_kSelect)
          .single();
      return ResidentModel.fromJson(data);
    } catch (e) {
      throw ServerException('Erreur désactivation résident : $e');
    }
  }

  @override
  Future<ResidentModel> activerResident(String residentId) async {
    try {
      final data = await SupabaseService.client
          .from(_table)
          .update({
            'is_actif': true,
            'desactive_par': null,
            'date_desactivation': null,
          })
          .eq('id', residentId)
          .select(_kSelect)
          .single();
      return ResidentModel.fromJson(data);
    } catch (e) {
      throw ServerException('Erreur activation résident : $e');
    }
  }

  @override
  Future<ResidentModel> toggleApplication(
      String residentId, bool aApplication) async {
    try {
      final data = await SupabaseService.client
          .from(_table)
          .update({'a_application': aApplication})
          .eq('id', residentId)
          .select(_kSelect)
          .single();
      return ResidentModel.fromJson(data);
    } catch (e) {
      throw ServerException('Erreur mise à jour accès app : $e');
    }
  }
}
