import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/reception_avis_repository_impl.dart';
import '../../domain/reception_avis_models.dart';
import '../../domain/reception_avis_repository.dart';

final receptionAvisRepositoryProvider = Provider<ReceptionAvisRepository>(
  (_) => const ReceptionAvisRepositoryImpl(),
);

/// Les résidents à aviser : avis ouverts, plus ceux traités aujourd'hui.
final receptionAvisProvider =
    FutureProvider.autoDispose<List<AvisResident>>((ref) {
  return ref.watch(receptionAvisRepositoryProvider).avis();
});
