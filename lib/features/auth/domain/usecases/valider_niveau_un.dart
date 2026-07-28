import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

class ValiderNiveauUn {
  final AuthRepository repository;
  const ValiderNiveauUn(this.repository);

  Future<Either<Failure, bool>> call(ValiderNiveauUnParams params) {
    return repository.validerNiveauUn(
      idResidence: params.idResidence,
      pinResidence: params.pinResidence,
    );
  }
}

class ValiderNiveauUnParams extends Equatable {
  final String idResidence;
  final String pinResidence;

  const ValiderNiveauUnParams({
    required this.idResidence,
    required this.pinResidence,
  });

  @override
  List<Object> get props => [idResidence, pinResidence];
}
