import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../reception/domain/reception_messages_models.dart';
import '../../reception/domain/reception_residents_repository.dart'
    show ReceptionErreur;
import '../domain/messages_reception_responsable_repository.dart';

/// Implémentation Supabase : uniquement des appels de FONCTIONS serveur.
class MessagesReceptionResponsableRepositoryImpl
    implements MessagesReceptionResponsableRepository {
  const MessagesReceptionResponsableRepositoryImpl();

  @override
  Future<List<MessageTransmis>> messages() async {
    const erreur = 'Impossible de charger les messages de la réception.';
    try {
      final data =
          await SupabaseService.client.rpc('responsable_messages_reception');
      return [
        for (final item in (data as List? ?? const []))
          MessageTransmis.fromJson(item as Map<String, dynamic>),
      ];
    } on PostgrestException catch (e) {
      throw ReceptionErreur(_message(e, erreur));
    } catch (_) {
      throw const ReceptionErreur(erreur);
    }
  }

  @override
  Future<void> repondre({
    required String messageId,
    required String auteurId,
    required String reponse,
  }) async {
    const erreur = "La réponse n'a pas pu être enregistrée.";
    try {
      await SupabaseService.client.rpc(
        'responsable_repondre_message_reception',
        params: {
          'p_message_id': messageId,
          'p_auteur_id': auteurId,
          'p_reponse': reponse,
        },
      );
    } on PostgrestException catch (e) {
      throw ReceptionErreur(_message(e, erreur));
    } catch (_) {
      throw const ReceptionErreur(erreur);
    }
  }

  @override
  Future<void> resoudre({
    required String messageId,
    required String auteurId,
  }) async {
    const erreur = "Le message n'a pas pu être marqué comme résolu.";
    try {
      await SupabaseService.client.rpc(
        'responsable_resoudre_message_reception',
        params: {'p_message_id': messageId, 'p_auteur_id': auteurId},
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
