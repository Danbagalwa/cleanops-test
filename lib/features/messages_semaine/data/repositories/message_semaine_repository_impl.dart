import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/message_semaine.dart';
import '../../domain/repositories/message_semaine_repository.dart';
import '../datasources/message_semaine_datasource.dart';

class MessageSemaineRepositoryImpl implements MessageSemaineRepository {
  final MessageSemaineDatasource _ds;
  const MessageSemaineRepositoryImpl(this._ds);

  @override
  Future<Either<Failure, MessageSemaine?>> getMessageActif() async {
    try {
      final result = await _ds.getMessageActif();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<MessageSemaine>>> getHistorique() async {
    try {
      final result = await _ds.getHistorique();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, MessageSemaine>> creerMessage(
    String contenu,
    MessageType type,
    String creeParId,
  ) async {
    try {
      final result = await _ds.creerMessage(contenu, type, creeParId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> desactiverMessage(String id) async {
    try {
      await _ds.desactiverMessage(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
