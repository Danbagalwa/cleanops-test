import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/reception_pin_repository_impl.dart';
import '../../domain/reception_pin_models.dart';
import '../../domain/reception_pin_repository.dart';

final receptionPinRepositoryProvider = Provider<ReceptionPinRepository>(
  (_) => const ReceptionPinRepositoryImpl(),
);

/// Le tableau des PIN. Ne contient jamais un PIN : seulement « en a un ».
final receptionPinListeProvider =
    FutureProvider.autoDispose<List<ResidentPin>>((ref) {
  return ref.watch(receptionPinRepositoryProvider).residents();
});
