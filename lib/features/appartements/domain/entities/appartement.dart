import 'package:equatable/equatable.dart';

class Appartement extends Equatable {
  final String id;
  final String numero;
  final String taille; // "2 1/2", "3 1/2", "4 1/2", "5 1/2"
  final int minutesBase; // toujours lu via JOIN — jamais stocké dans taches
  final String? notes;
  final bool hasAnimal;
  final String? typeAnimal;

  const Appartement({
    required this.id,
    required this.numero,
    required this.taille,
    required this.minutesBase,
    this.notes,
    this.hasAnimal = false,
    this.typeAnimal,
  });

  @override
  List<Object?> get props =>
      [id, numero, taille, minutesBase, notes, hasAnimal, typeAnimal];
}
