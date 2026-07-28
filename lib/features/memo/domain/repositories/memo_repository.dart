import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/memo.dart';

abstract class MemoRepository {
  Future<Either<Failure, List<Memo>>> getConversation(String preposeeId);

  Future<Either<Failure, List<PreposeeResume>>>
      getPreposeeesAvecDernierMemo();

  Future<Either<Failure, Memo>> envoyerMemo({
    required String preposeeId,
    required String auteurId,
    required AuteurType auteur,
    required String message,
  });

  // Non-critique : fire-and-forget, les erreurs sont silencieuses
  Future<void> marquerCommeLu(
    String preposeeId,
    AuteurType auteurCourant,
  );
}
