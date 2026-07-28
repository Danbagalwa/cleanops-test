import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/progression_jour_model.dart';

abstract class EmployerDashboardDatasource {
  Future<List<ProgressionJourModel>> getProgressionJour();
}

class EmployerDashboardDatasourceImpl implements EmployerDashboardDatasource {
  @override
  Future<List<ProgressionJourModel>> getProgressionJour() async {
    try {
      final data =
          await SupabaseService.client.from('vue_progression_jour').select();
      return (data as List)
          .map((e) => ProgressionJourModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
