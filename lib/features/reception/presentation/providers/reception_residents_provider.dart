import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/reception_residents_repository_impl.dart';
import '../../domain/reception_models.dart';
import '../../domain/reception_residents_repository.dart';

final receptionResidentsRepositoryProvider =
    Provider<ReceptionResidentsRepository>(
  (_) => const ReceptionResidentsRepositoryImpl(),
);

/// Tableau des résidents (un résident actif par ligne, avec son appartement).
final receptionResidentsListeProvider =
    FutureProvider.autoDispose<List<ResidentLigne>>((ref) {
  return ref.watch(receptionResidentsRepositoryProvider).residents();
});

/// Appartements sans occupant actif (formulaire d'inscription).
final receptionAppartementsLibresProvider =
    FutureProvider.autoDispose<List<AppartementLibre>>((ref) {
  return ref.watch(receptionResidentsRepositoryProvider).appartementsLibres();
});

/// Responsables qu'on peut désigner comme demandeur d'une inscription.
final receptionResponsablesProvider =
    FutureProvider.autoDispose<List<ResponsableDemandeur>>((ref) {
  return ref.watch(receptionResidentsRepositoryProvider).responsables();
});

/// Fiche d'un appartement.
final receptionFicheProvider =
    FutureProvider.autoDispose.family<FicheAppartement?, String>((ref, id) {
  return ref.watch(receptionResidentsRepositoryProvider).fiche(id);
});
