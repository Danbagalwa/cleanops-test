import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../entities/appartement.dart';
import '../repositories/appartements_repository.dart';

class AddAppartement {
  final AppartementsRepository repository;
  const AddAppartement(this.repository);

  Future<Either<Failure, Appartement>> call(AddAppartementParams params) {
    return repository.addAppartement(
      numero: params.numero,
      taille: params.taille,
      minutesBase: params.minutesBase,
    );
  }
}

class AddAppartementParams extends Equatable {
  final String numero;
  final String taille;
  final int minutesBase;

  const AddAppartementParams({
    required this.numero,
    required this.taille,
    required this.minutesBase,
  });

  @override
  List<Object> get props => [numero, taille, minutesBase];
}
