import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/memo.dart';
import '../../domain/repositories/memo_repository.dart';
import '../datasources/memo_datasource.dart';

class MemoRepositoryImpl implements MemoRepository {
  final MemoDatasource _ds;
  const MemoRepositoryImpl(this._ds);

  @override
  Future<Either<Failure, List<Memo>>> getConversation(
      String preposeeId) async {
    try {
      final result = await _ds.getConversation(preposeeId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PreposeeResume>>>
      getPreposeeesAvecDernierMemo() async {
    try {
      final result = await _ds.getPreposeeesAvecDernierMemo();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Memo>> envoyerMemo({
    required String preposeeId,
    required String auteurId,
    required AuteurType auteur,
    required String message,
  }) async {
    try {
      final result = await _ds.envoyerMemo(
        preposeeId: preposeeId,
        auteurId: auteurId,
        auteur: auteur,
        message: message,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<void> marquerCommeLu(
      String preposeeId, AuteurType auteurCourant) async {
    await _ds.marquerCommeLu(preposeeId, auteurCourant);
  }
}
