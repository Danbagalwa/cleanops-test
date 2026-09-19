import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../entities/appartement.dart';
import '../repositories/appartements_repository.dart';

class UpdateAppartement {
  final AppartementsRepository repository;
  const UpdateAppartement(this.repository);

  Future<Either<Failure, Appartement>> call(UpdateAppartementParams params) {
    return repository.updateAppartement(
      id: params.id,
      numero: params.numero,
      taille: params.taille,
      minutesBase: params.minutesBase,
      notes: params.notes,
      hasAnimal: params.hasAnimal,
      typeAnimal: params.typeAnimal,
    );
  }
}

class UpdateAppartementParams extends Equatable {
  final String id;
  final String numero;
  final String taille;
  final int minutesBase;
  final String? notes;
  final bool hasAnimal;
  final String? typeAnimal;

  const UpdateAppartementParams({
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
