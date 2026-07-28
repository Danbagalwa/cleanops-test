import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/chat_message.dart';

abstract class ChatGroupeRepository {
  Future<Either<Failure, List<ChatMessage>>> getMessages({
    int offset = 0,
    int limit = 50,
  });
  Future<Either<Failure, ChatMessage>> envoyerMessage({
    required String auteurId,
    required String message,
  });
  Future<Either<Failure, ChatMessage>> epinglerMessage({
    required String messageId,
    required String epingleParId,
  });
  Future<Either<Failure, ChatMessage>> desepinglerMessage({
    required String messageId,
  });
  Future<Either<Failure, ChatMessage>> supprimerMessage({
    required String messageId,
    required String supprimeParId,
  });
  Future<Either<Failure, List<ChatMessage>>> getMessagesEpingles();
}
