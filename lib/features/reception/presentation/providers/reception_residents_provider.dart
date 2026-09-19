import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/reception_residents_repository_impl.dart';
import '../../domain/reception_models.dart';
import '../../domain/reception_residents_repository.dart';

final receptionResidentsRepositoryProvider =
    Provider<ReceptionResidentsRepository>(
  (_) => const ReceptionResidentsRepositoryImpl(),
);

/// Résultats de la recherche pour un texte donné.
final receptionRechercheProvider = FutureProvider.autoDispose
    .family<List<AppartementResultat>, String>((ref, recherche) {
  return ref.watch(receptionResidentsRepositoryProvider).rechercher(recherche);
});

/// Fiche d'un appartement.
final receptionFicheProvider =
    FutureProvider.autoDispose.family<FicheAppartement?, String>((ref, id) {
  return ref.watch(receptionResidentsRepositoryProvider).fiche(id);
});
