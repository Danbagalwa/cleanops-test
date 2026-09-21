import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/reception_equipe_repository_impl.dart';
import '../../domain/reception_equipe_models.dart';
import '../../domain/reception_equipe_repository.dart';

final receptionEquipeRepositoryProvider = Provider<ReceptionEquipeRepository>(
  (_) => const ReceptionEquipeRepositoryImpl(),
);

/// L'équipe du jour : présence et horaire de chaque employé.
final receptionEquipeProvider =
    FutureProvider.autoDispose<EquipeDuJour>((ref) {
  return ref.watch(receptionEquipeRepositoryProvider).equipeDuJour();
});
