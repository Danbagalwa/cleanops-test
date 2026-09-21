import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/reception_pin_models.dart';
import '../domain/reception_pin_repository.dart';
import '../domain/reception_residents_repository.dart' show ReceptionErreur;

/// Implémentation Supabase : uniquement des appels de FONCTIONS serveur. Le
/// hachage d'un PIN n'est jamais lu.
class ReceptionPinRepositoryImpl implements ReceptionPinRepository {
  const ReceptionPinRepositoryImpl();

  @override
  Future<List<ResidentPin>> residents() async {
    const erreur = 'Impossible de charger la liste des résidents.';
    try {
      final data = await SupabaseService.client.rpc('reception_residents_pin');
      return [
        for (final item in (data as List? ?? const []))
          ResidentPin.fromJson(item as Map<String, dynamic>),
      ];
    } on PostgrestException catch (e) {
      throw ReceptionErreur(_message(e, erreur));
    } catch (_) {
      throw const ReceptionErreur(erreur);
    }
  }

  @override
  Future<PinGenere> genererPin({
    required String residentId,
    required String auteurId,
  }) async {
    const erreur = "Le PIN n'a pas pu être généré.";
    try {
      final data = await SupabaseService.client.rpc(
        'reception_generer_pin',
        params: {'p_resident_id': residentId, 'p_auteur_id': auteurId},
      );
      return PinGenere.fromJson(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw ReceptionErreur(_message(e, erreur));
    } catch (_) {
      throw const ReceptionErreur(erreur);
    }
  }

  /// Les refus métier du serveur (code P0001) sont déjà rédigés pour
  /// l'utilisateur ; toute autre erreur reçoit un message générique.
  String _message(PostgrestException e, String parDefaut) =>
      e.code == 'P0001' && e.message.isNotEmpty ? e.message : parDefaut;
}
