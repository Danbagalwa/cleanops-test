import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/message_semaine.dart';

abstract class MessageSemaineRepository {
  Future<Either<Failure, MessageSemaine?>> getMessageActif();

  Future<Either<Failure, List<MessageSemaine>>> getHistorique();

  Future<Either<Failure, MessageSemaine>> creerMessage(
    String contenu,
    MessageType type,
    String creeParId,
  );

  Future<Either<Failure, void>> desactiverMessage(String id);
}
