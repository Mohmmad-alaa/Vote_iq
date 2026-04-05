import 'package:dartz/dartz.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/agent.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../datasources/remote/supabase_auth_datasource.dart';

/// Auth repository implementation.
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthDatasource _remoteDatasource;

  AuthRepositoryImpl(this._remoteDatasource);

  @override
  Future<Either<Failure, Agent>> signIn({
    required String username,
    required String password,
  }) async {
    try {
      final agent = await _remoteDatasource.signIn(
        username: username,
        password: password,
      );
      return Right(agent.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _remoteDatasource.signOut();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'فشل تسجيل الخروج: $e'));
    }
  }

  @override
  Future<Either<Failure, Agent?>> getCurrentAgent() async {
    try {
      final agent = await _remoteDatasource.getCurrentAgent();
      return Right(agent?.toEntity());
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في جلب بيانات المستخدم: $e'));
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    return _remoteDatasource.isAuthenticated;
  }
}
