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
    );
  }
}

class UpdateAppartementParams extends Equatable {
  final String id;
  final String numero;
  final String taille;
  final int minutesBase;

  const UpdateAppartementParams({
    required this.id,
    required this.numero,
    required this.taille,
    required this.minutesBase,
  });

  @override
  List<Object> get props => [id, numero, taille, minutesBase];
}
