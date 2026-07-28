import 'package:jazz_teasdale/features/auth/domain/entities/employee.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/employee_model.dart';

abstract class AuthRemoteDatasource {
  // Niveau 1 — Valider ID résidence + PIN résidence
  Future<bool> validerNiveauUn({
    required String idResidence,
    required String pinResidence,
  });

  // Niveau 2 — Connexion selon rôle
  Future<EmployeeModel> loginWithPin({
    required String slug,
    required String pin,
    String? role,
  });

  Future<EmployeeModel?> getEmployeEnSession();
  Future<void> logout();
}

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  final SharedPreferences _prefs;

  // Clés SharedPreferences
  static const String _keyEmployeeId = 'employee_id';
  static const String _keyEmployeeSlug = 'employee_slug';
  static const String _keyNiveauUn = 'niveau_un_valide';
  static const String _keyToken = 'session_token';
  static const String _keyIsResident = 'is_resident';

  const AuthRemoteDatasourceImpl(this._prefs);

  // ── Niveau 1 — Valider résidence ─────────────────────
  @override
  Future<bool> validerNiveauUn({
    required String idResidence,
    required String pinResidence,
  }) async {
    try {
      final response = await SupabaseService.client.rpc(
        'verify_residence_access',
        params: {
          'p_id_residence': idResidence,
          'p_pin_residence': pinResidence,
        },
      );
      final isValid = response as bool? ?? false;

      if (!isValid) {
        throw const AuthException('Identifiant ou code PIN résidence invalide');
      }

      await _prefs.setBool(_keyNiveauUn, true);
      return true;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ServerException('Erreur validation résidence : $e');
    }
  }

  // Colonnes pour la restauration de session (sans secrets)
  static const _kSelectEmployee =
      'id, nom, prenom, slug, role, is_actif, '
      'nom_residence, date_creation, date_mise_a_jour';

  // ── Niveau 2 — Connexion selon rôle ──────────────────
  @override
  Future<EmployeeModel> loginWithPin({
    required String slug,
    required String pin,
    String? role,
  }) async {
    try {
      if (role == 'resident') {
        return await _loginResident(numeroApt: slug, pin: pin);
      } else {
        return await _loginEmployee(slug: slug, pin: pin, role: role);
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ServerException('Erreur de connexion : $e');
    }
  }

  // ── Login Préposée / Responsable ──────────────────────
  Future<EmployeeModel> _loginEmployee({
    required String slug,
    required String pin,
    String? role,
  }) async {
    final response = await SupabaseService.client.rpc(
      'authenticate_employee',
      params: {
        'p_slug': slug,
        'p_credential': pin,
        'p_is_responsable': role == 'responsable',
      },
    );

    if (response == null) {
      throw const AuthException('Identifiant ou code incorrect');
    }

    final employee =
        EmployeeModel.fromJson(response as Map<String, dynamic>);
    await _sauvegarderSession(id: employee.id, slug: employee.slug);

    return employee;
  }

  // ── Login Résident ────────────────────────────────────
  Future<EmployeeModel> _loginResident({
    required String numeroApt,
    required String pin,
  }) async {
    final response = await SupabaseService.client.rpc(
      'authenticate_resident',
      params: {
        'p_numero_appartement': numeroApt,
        'p_pin': pin,
      },
    );

    if (response == null) {
      throw const AuthException('Appartement ou code PIN incorrect');
    }

    final resident = response as Map<String, dynamic>;
    final residentAsEmployee = EmployeeModel(
      id: resident['id'] as String,
      nom: resident['nom'] as String,
      prenom: resident['prenom'] as String,
      slug: 'resident-$numeroApt',
      role: RoleType.resident,
      isActif: true,
      nomResidence: resident['numero_appartement'] as String? ?? numeroApt,
    );

    await _sauvegarderSession(
      id: residentAsEmployee.id,
      slug: residentAsEmployee.slug,
      isResident: true,
    );

    return residentAsEmployee;
  }

  // ── Restauration session résident ─────────────────────────
  Future<EmployeeModel?> _restaurerSessionResident() async {
    final residentId = _prefs.getString(_keyEmployeeId);
    if (residentId == null) return null;

    try {
      final response = await SupabaseService.client
          .from('residents')
          .select('id, nom, prenom, is_actif, appartements(numero)')
          .eq('id', residentId)
          .eq('is_actif', true)
          .maybeSingle();

      if (response == null) {
        await _clearPrefs();
        return null;
      }

      final aptData = response['appartements'] as Map<String, dynamic>?;
      final aptNumero = aptData?['numero'] as String? ?? '';

      return EmployeeModel(
        id: response['id'] as String,
        nom: response['nom'] as String,
        prenom: response['prenom'] as String,
        slug: 'resident-$aptNumero',
        role: RoleType.resident,
        isActif: true,
        nomResidence: aptNumero,
      );
    } catch (_) {
      await _clearPrefs();
      return null;
    }
  }

  // ── Session ───────────────────────────────────────────
  @override
  Future<EmployeeModel?> getEmployeEnSession() async {
    try {
      // Résident : restauration dédiée (table residents, pas employees)
      if (_prefs.getBool(_keyIsResident) == true) {
        return await _restaurerSessionResident();
      }

      final token = _prefs.getString(_keyToken);

      // ── Voie principale : token Supabase ──────────────
      if (token != null) {
        final session = await SupabaseService.table(SupabaseService.sessions)
            .select('employee_id')
            .eq('token', token)
            .eq('actif', true)
            .gt('date_expiration',
                DateTime.now().toUtc().toIso8601String())
            .maybeSingle();

        if (session == null) {
          // Token invalide ou expiré
          await _invaliderSessionSupabase(token);
          await _clearPrefs();
          return null;
        }

        final employeeId = session['employee_id'] as String;
        final response =
            await SupabaseService.table(SupabaseService.employees)
                .select(_kSelectEmployee)
                .eq('id', employeeId)
                .eq('is_actif', true)
                .maybeSingle();

        if (response == null) {
          await _invaliderSessionSupabase(token);
          await _clearPrefs();
          return null;
        }

        return EmployeeModel.fromJson(response);
      }

      // ── Voie de secours : employee_id local (sessions antérieures) ──
      final employeeId = _prefs.getString(_keyEmployeeId);
      if (employeeId == null) return null;

      final response = await SupabaseService.table(SupabaseService.employees)
          .select(_kSelectEmployee)
          .eq('id', employeeId)
          .eq('is_actif', true)
          .maybeSingle();

      if (response == null) {
        await _clearPrefs();
        return null;
      }

      return EmployeeModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // ── Déconnexion ───────────────────────────────────────
  @override
  Future<void> logout() async {
    final token = _prefs.getString(_keyToken);
    if (token != null) {
      await _invaliderSessionSupabase(token);
    }
    await _clearPrefs();
  }

  // ── Utilitaires session ───────────────────────────────
  Future<void> _sauvegarderSession({
    required String id,
    required String slug,
    bool isResident = false,
  }) async {
    await _prefs.setString(_keyEmployeeId, id);
    await _prefs.setString(_keyEmployeeSlug, slug);
    if (isResident) {
      await _prefs.setBool(_keyIsResident, true);
    } else {
      await _prefs.remove(_keyIsResident);
    }

    final token = const Uuid().v4();
    try {
      await SupabaseService.table(SupabaseService.sessions).insert({
        if (isResident) 'resident_id': id else 'employee_id': id,
        'token': token,
        'niveau_auth': 2,
        'date_expiration': DateTime.now()
            .toUtc()
            .add(const Duration(hours: 8))
            .toIso8601String(),
        'actif': true,
      });
      await _prefs.setString(_keyToken, token);
    } catch (_) {
      // Échec non-critique : l'identité locale reste utilisable.
    }
  }

  Future<void> _invaliderSessionSupabase(String token) async {
    try {
      await SupabaseService.table(SupabaseService.sessions)
          .update({'actif': false})
          .eq('token', token);
    } catch (_) {}
  }

  Future<void> _clearPrefs() async {
    await _prefs.remove(_keyEmployeeId);
    await _prefs.remove(_keyEmployeeSlug);
    await _prefs.remove(_keyNiveauUn);
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyIsResident);
  }
}
