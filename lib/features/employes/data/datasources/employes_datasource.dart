import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../auth/data/models/employee_model.dart';
import '../../../auth/domain/entities/employee.dart';

abstract class EmployesDatasource {
  Future<List<Employee>> getEmployes();
  Future<Employee> addEmploye({
    required String nom,
    required String prenom,
    required RoleType role,
    String? numeroPointeuse,
    String? motDePasse,
  });
  Future<Employee> updateEmploye({
    required String id,
    required String nom,
    required String prenom,
    required RoleType role,
    required bool isActif,
    String? numeroPointeuse,
    String? motDePasse,
  });
  Future<void> toggleActif(String id, {required bool isActif});
}

class EmployesDatasourceImpl implements EmployesDatasource {
  final _supabase = Supabase.instance.client;

  static const _kSelectEmployee =
      'id, nom, prenom, slug, role, is_actif, nom_residence, '
      'date_creation, date_mise_a_jour';

  static String _slugify(String text) {
    const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüý';
    const to   = 'aaaaaaceeeeiiiinooooouuuuy';
    var s = text.toLowerCase().trim();
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  Future<List<Employee>> getEmployes() async {
    try {
      final data = await _supabase
          .from('employees')
          .select(_kSelectEmployee)
          .order('nom')
          .order('prenom');
      return (data as List)
          .map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Employee> addEmploye({
    required String nom,
    required String prenom,
    required RoleType role,
    String? numeroPointeuse,
    String? motDePasse,
  }) async {
    try {
      final data = await _supabase.from('employees').insert({
        'nom': nom,
        'prenom': prenom,
        'slug': _slugify(prenom),
        'role': role.label,
        'is_actif': true,
        if (numeroPointeuse != null && numeroPointeuse.isNotEmpty)
          'numero_pointeuse': numeroPointeuse,
        if (motDePasse != null && motDePasse.isNotEmpty)
          'mot_de_passe': motDePasse,
      }).select(_kSelectEmployee).single();
      return EmployeeModel.fromJson(data);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const DoublonException(
          'Un employé avec ce prénom existe déjà. Modifiez le prénom.',
        );
      }
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Employee> updateEmploye({
    required String id,
    required String nom,
    required String prenom,
    required RoleType role,
    required bool isActif,
    String? numeroPointeuse,
    String? motDePasse,
  }) async {
    try {
      final data = await _supabase
          .from('employees')
          .update({
            'nom': nom,
            'prenom': prenom,
            'slug': _slugify(prenom),
            'role': role.label,
            'is_actif': isActif,
            if (role == RoleType.employe &&
                numeroPointeuse != null &&
                numeroPointeuse.isNotEmpty)
              'numero_pointeuse': numeroPointeuse,
            if (role != RoleType.employe) 'numero_pointeuse': null,
            if (motDePasse != null && motDePasse.isNotEmpty)
              'mot_de_passe': motDePasse,
            if (role == RoleType.employe) 'mot_de_passe': null,
          })
          .eq('id', id)
          .select(_kSelectEmployee)
          .single();
      return EmployeeModel.fromJson(data);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const DoublonException(
          'Un employé avec ce prénom existe déjà. Modifiez le prénom.',
        );
      }
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> toggleActif(String id, {required bool isActif}) async {
    try {
      await _supabase
          .from('employees')
          .update({'is_actif': isActif})
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
