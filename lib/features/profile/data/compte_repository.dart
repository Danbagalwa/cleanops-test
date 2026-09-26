import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';

/// Issue d'un changement d'identifiant ou de mot de passe, telle que la
/// renvoient les fonctions serveur (migration 202609260039).
enum ResultatCompte {
  ok,

  /// Code actuel incorrect (mot de passe, ou numéro de pointeuse).
  code,

  /// Nouvelle valeur au mauvais format.
  format,

  /// Identifiant déjà utilisé par un autre employé.
  pris,

  /// Mot de passe demandé pour une préposée.
  interdit;

  static ResultatCompte depuis(Object? valeur) => ResultatCompte.values
      .firstWhere((r) => r.name == valeur, orElse: () => ResultatCompte.code);
}

/// Identifiants de connexion de l'employé connecté. Chaque changement exige
/// son code actuel, vérifié côté serveur.
abstract class CompteRepository {
  Future<ResultatCompte> changerIdentifiant({
    required String employeeId,
    required String codeActuel,
    required String nouveauSlug,
  });

  Future<ResultatCompte> changerMotDePasse({
    required String employeeId,
    required String ancien,
    required String nouveau,
  });
}

class CompteRepositoryImpl implements CompteRepository {
  const CompteRepositoryImpl();

  @override
  Future<ResultatCompte> changerIdentifiant({
    required String employeeId,
    required String codeActuel,
    required String nouveauSlug,
  }) async =>
      ResultatCompte.depuis(
        await SupabaseService.client.rpc('changer_identifiant', params: {
          'p_employee_id': employeeId,
          'p_code': codeActuel,
          'p_nouveau_slug': nouveauSlug,
        }),
      );

  @override
  Future<ResultatCompte> changerMotDePasse({
    required String employeeId,
    required String ancien,
    required String nouveau,
  }) async =>
      ResultatCompte.depuis(
        await SupabaseService.client.rpc('changer_mot_de_passe', params: {
          'p_employee_id': employeeId,
          'p_ancien': ancien,
          'p_nouveau': nouveau,
        }),
      );
}

final compteRepositoryProvider =
    Provider<CompteRepository>((_) => const CompteRepositoryImpl());
