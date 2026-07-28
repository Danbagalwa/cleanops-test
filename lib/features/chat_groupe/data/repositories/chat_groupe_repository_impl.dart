import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_groupe_repository.dart';
import '../datasources/chat_groupe_datasource.dart';

class ChatGroupeRepositoryImpl implements ChatGroupeRepository {
  final ChatGroupeDatasource _ds;
  const ChatGroupeRepositoryImpl(this._ds);

  @override
  Future<Either<Failure, List<ChatMessage>>> getMessages({
    int offset = 0,
    int limit = 50,
  }) async {
    try {
      return Right(await _ds.getMessages(offset: offset, limit: limit));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ChatMessage>> envoyerMessage({
    required String auteurId,
    required String message,
  }) async {
    try {
      return Right(
          await _ds.envoyerMessage(auteurId: auteurId, message: message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ChatMessage>> epinglerMessage({
    required String messageId,
    required String epingleParId,
  }) async {
    try {
      return Right(await _ds.epinglerMessage(
          messageId: messageId, epingleParId: epingleParId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ChatMessage>> desepinglerMessage({
    required String messageId,
  }) async {
    try {
      return Right(await _ds.desepinglerMessage(messageId: messageId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ChatMessage>> supprimerMessage({
    required String messageId,
    required String supprimeParId,
  }) async {
    try {
      return Right(await _ds.supprimerMessage(
          messageId: messageId, supprimeParId: supprimeParId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> getMessagesEpingles() async {
    try {
      return Right(await _ds.getMessagesEpingles());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
