import 'package:dartz/dartz.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../data/datasources/remote/supabase_agent_datasource.dart';
import '../../../data/datasources/remote/supabase_lookup_datasource.dart';
import '../../../data/datasources/remote/supabase_voter_datasource.dart';
import '../../../data/sync/sync_queue.dart';
import '../../../domain/entities/agent.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/lookup_repository.dart';
import '../datasources/remote/supabase_auth_datasource.dart';

/// Auth repository implementation.
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthDatasource _remoteDatasource;
  final LookupRepository _lookupRepository;
  final SyncQueue _syncQueue;
  final SupabaseVoterDatasource _voterDatasource;
  final SupabaseLookupDatasource _lookupDatasource;
  final SupabaseAgentDatasource _agentDatasource;

  AuthRepositoryImpl({
    required SupabaseAuthDatasource remoteDatasource,
    required LookupRepository lookupRepository,
    required SyncQueue syncQueue,
    required SupabaseVoterDatasource voterDatasource,
    required SupabaseLookupDatasource lookupDatasource,
    required SupabaseAgentDatasource agentDatasource,
  }) : _remoteDatasource = remoteDatasource,
       _lookupRepository = lookupRepository,
       _syncQueue = syncQueue,
       _voterDatasource = voterDatasource,
       _lookupDatasource = lookupDatasource,
       _agentDatasource = agentDatasource;

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
      await _lookupRepository.clearCache();
      await _syncQueue.clear();
      _voterDatasource.invalidatePermissionsCache();
      _lookupDatasource.invalidatePermissionsCache();
      _voterDatasource.disposeRealtime();
      _agentDatasource.disposeCurrentUserPermissionRealtime();
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
