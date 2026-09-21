import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/reception_avis_models.dart';
import '../domain/reception_avis_repository.dart';
import '../domain/reception_residents_repository.dart' show ReceptionErreur;

/// Implémentation Supabase : uniquement des appels de FONCTIONS serveur.
class ReceptionAvisRepositoryImpl implements ReceptionAvisRepository {
  const ReceptionAvisRepositoryImpl();

  @override
  Future<List<AvisResident>> avis() async {
    const erreur = 'Impossible de charger les résidents à aviser.';
    try {
      final data = await SupabaseService.client.rpc('reception_a_aviser');
      final liste = (data as Map<String, dynamic>)['avis'] as List? ?? const [];
      return [
        for (final a in liste) AvisResident.fromJson(a as Map<String, dynamic>),
      ];
    } on PostgrestException catch (e) {
      throw ReceptionErreur(_message(e, erreur));
    } catch (_) {
      throw const ReceptionErreur(erreur);
    }
  }

  @override
  Future<void> traiter({
    required String avisId,
    required String auteurId,
    required ActionAvis action,
    String? commentaire,
  }) async {
    const erreur = "Le traitement n'a pas pu être enregistré.";
    try {
      await SupabaseService.client.rpc(
        'reception_traiter_avis',
        params: {
          'p_avis_id': avisId,
          'p_auteur_id': auteurId,
          'p_action': action.code,
          'p_commentaire': commentaire,
        },
      );
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
