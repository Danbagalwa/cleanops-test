import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/employee.dart';
import '../../domain/usecases/login_with_pin.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/usecases/valider_niveau_un.dart';

// ── SharedPreferences provider ────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialiser dans main.dart');
});

// ── Datasource provider ───────────────────────────────────
final authDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthRemoteDatasourceImpl(prefs);
});

// ── Repository provider ───────────────────────────────────
final authRepositoryProvider = Provider((ref) {
  final datasource = ref.watch(authDatasourceProvider);
  return AuthRepositoryImpl(datasource);
});

// ── Usecases providers ────────────────────────────────────
final loginWithPinProvider = Provider((ref) {
  return LoginWithPin(ref.watch(authRepositoryProvider));
});

final logoutProvider = Provider((ref) {
  return Logout(ref.watch(authRepositoryProvider));
});

final validerNiveauUnProvider = Provider((ref) {
  return ValiderNiveauUn(ref.watch(authRepositoryProvider));
});

// ── État de l'auth ────────────────────────────────────────
class AuthState {
  final Employee? employee;
  final bool isLoading;
  final String? error;

  // Niveau 1 — résidence validée mais niveau 2 pas encore fait
  final bool niveauUnValide;

  const AuthState({
    this.employee,
    this.isLoading = false,
    this.error,
    this.niveauUnValide = false,
  });

  bool get isAuthenticated => employee != null;

  bool get isPreposee => employee?.role == RoleType.employe;

  bool get isResponsable => employee?.isResponsable ?? false;

  bool get isAdmin => employee?.role == RoleType.admin;

  AuthState copyWith({
    Employee? employee,
    bool? isLoading,
    String? error,
    bool? niveauUnValide,
  }) {
    return AuthState(
      employee: employee ?? this.employee,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      niveauUnValide: niveauUnValide ?? this.niveauUnValide,
    );
  }
}

// ── AuthNotifier ──────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final LoginWithPin _loginWithPin;
  final Logout _logout;
  final ValiderNiveauUn _validerNiveauUn;

  AuthNotifier({
    required LoginWithPin loginWithPin,
    required Logout logout,
    required ValiderNiveauUn validerNiveauUn,
  })  : _loginWithPin = loginWithPin,
        _logout = logout,
        _validerNiveauUn = validerNiveauUn,
        super(const AuthState());

  // ── Niveau 1 — Valider ID résidence + PIN résidence ──
  Future<bool> validerNiveauUn({
    required String idResidence,
    required String pinResidence,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _validerNiveauUn(
      ValiderNiveauUnParams(
        idResidence: idResidence,
        pinResidence: pinResidence,
      ),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, niveauUnValide: true);
        return true;
      },
    );
  }

  // ── Niveau 2 — Connexion selon rôle ──────────────────
  Future<bool> login({
    required String slug,
    required String pin,
    String? role, // 'preposee', 'resident', 'responsable'
  }) async {
    if (!state.niveauUnValide) {
      state = state.copyWith(
        error: 'Veuillez d\'abord valider l\'accès résidence',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    final result = await _loginWithPin(
      LoginParams(slug: slug, pin: pin, role: role),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (employee) {
        state = AuthState(employee: employee, niveauUnValide: true);
        return true;
      },
    );
  }

  // ── Déconnexion ───────────────────────────────────────
  Future<void> logout() async {
    await _logout();
    state = const AuthState();
  }

  // ── Retour au niveau 1 ────────────────────────────────
  void retourNiveauUn() {
    state = state.copyWith(niveauUnValide: false, error: null);
  }

  // ── Utilitaires ───────────────────────────────────────
  void setEmployee(Employee employee) {
    state = AuthState(employee: employee, niveauUnValide: true);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ── AuthNotifier provider ─────────────────────────────────
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(
    loginWithPin: ref.watch(loginWithPinProvider),
    logout: ref.watch(logoutProvider),
    validerNiveauUn: ref.watch(validerNiveauUnProvider),
  );
});

// ── Raccourcis providers ──────────────────────────────────
final employeeCourantProvider = Provider<Employee?>((ref) {
  return ref.watch(authNotifierProvider).employee;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isAuthenticated;
});

final isPreposeeProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isPreposee;
});

final isResponsableProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isResponsable;
});

final roleActuelProvider = Provider<RoleType?>((ref) {
  return ref.watch(authNotifierProvider).employee?.role;
});
