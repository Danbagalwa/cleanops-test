import 'package:equatable/equatable.dart';

class StatAppartement extends Equatable {
  final String numero;
  final String taille;
  final int nbAbsences;
  final int nbRefus;

  const StatAppartement({
    required this.numero,
    required this.taille,
    required this.nbAbsences,
    required this.nbRefus,
  });

  int get totalProblemes => nbAbsences + nbRefus;

  @override
  List<Object?> get props => [numero, taille, nbAbsences, nbRefus];
}
