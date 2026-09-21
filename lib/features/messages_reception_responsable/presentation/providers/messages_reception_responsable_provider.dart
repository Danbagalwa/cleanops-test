import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../reception/domain/reception_messages_models.dart';
import '../../data/messages_reception_responsable_repository_impl.dart';
import '../../domain/messages_reception_responsable_repository.dart';

final messagesReceptionResponsableRepositoryProvider =
    Provider<MessagesReceptionResponsableRepository>(
  (_) => const MessagesReceptionResponsableRepositoryImpl(),
);

/// Les messages transmis par la Réception, du plus récent au plus ancien.
final messagesReceptionResponsableProvider =
    FutureProvider.autoDispose<List<MessageTransmis>>((ref) {
  return ref.watch(messagesReceptionResponsableRepositoryProvider).messages();
});

/// Nombre de messages « En attente » (pour le compteur de l'onglet). 0 tant que
/// la liste n'est pas chargée.
final messagesReceptionEnAttenteProvider = Provider.autoDispose<int>((ref) {
  final liste = ref.watch(messagesReceptionResponsableProvider).valueOrNull;
  return liste?.where((m) => m.statut == StatutMessage.enAttente).length ?? 0;
});
