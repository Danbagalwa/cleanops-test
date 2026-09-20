import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/reception_models.dart';
import '../domain/reception_residents_repository.dart';

/// Implémentation Supabase : uniquement des appels de FONCTIONS serveur
/// (`reception_*`), jamais de lecture directe de `taches_jour`.
class ReceptionResidentsRepositoryImpl implements ReceptionResidentsRepository {
  const ReceptionResidentsRepositoryImpl();

  @override
  Future<List<ResidentLigne>> residents() async {
    try {
      final data =
          await SupabaseService.client.rpc('reception_lister_residents');
      return [
        for (final item in (data as List? ?? const []))
          ResidentLigne.fromJson(item as Map<String, dynamic>),
      ];
    } on PostgrestException catch (e) {
      throw ReceptionErreur(
          _message(e, 'Impossible de charger la liste des résidents.'));
    } catch (_) {
      throw const ReceptionErreur(
          'Impossible de charger la liste des résidents.');
    }
  }

  @override
  Future<FicheAppartement?> fiche(String appartementId) async {
    try {
      final data = await SupabaseService.client.rpc(
        'reception_fiche_appartement',
        params: {'p_appartement_id': appartementId},
      );
      if (data == null) return null;
      return FicheAppartement.fromJson(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw ReceptionErreur(_message(e, 'Impossible de charger la fiche.'));
    } catch (_) {
      throw const ReceptionErreur('Impossible de charger la fiche.');
    }
  }

  @override
  Future<void> envoyerMessage({
    required String appartementId,
    required String auteurId,
    required String message,
    required bool transmettreEmploye,
  }) async {
    try {
      await SupabaseService.client.rpc(
        'reception_envoyer_message',
        params: {
          'p_appartement_id': appartementId,
          'p_auteur_id': auteurId,
          'p_message': message,
          'p_transmettre_employe': transmettreEmploye,
        },
      );
    } on PostgrestException catch (e) {
      throw ReceptionErreur(_message(e, 'Le message n\'a pas pu être envoyé.'));
    } catch (_) {
      throw const ReceptionErreur('Le message n\'a pas pu être envoyé.');
    }
  }

  /// Les refus métier du serveur (code P0001) sont déjà rédigés pour
  /// l'utilisateur ; toute autre erreur reçoit un message générique.
  String _message(PostgrestException e, String parDefaut) =>
      e.code == 'P0001' && e.message.isNotEmpty ? e.message : parDefaut;
}
