import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/reception_messages_repository_impl.dart';
import '../../domain/reception_messages_models.dart';
import '../../domain/reception_messages_repository.dart';

final receptionMessagesRepositoryProvider =
    Provider<ReceptionMessagesRepository>(
  (_) => const ReceptionMessagesRepositoryImpl(),
);

/// Les messages transmis à l'administration, du plus récent au plus ancien.
final receptionMessagesProvider =
    FutureProvider.autoDispose<List<MessageTransmis>>((ref) {
  return ref.watch(receptionMessagesRepositoryProvider).messages();
});
