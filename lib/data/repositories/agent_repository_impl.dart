import 'package:dartz/dartz.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/connectivity_helper.dart';
import '../../../domain/entities/agent.dart';
import '../../../domain/entities/agent_permission.dart';
import '../../../domain/repositories/agent_repository.dart';
import '../datasources/remote/supabase_agent_datasource.dart';

class AgentRepositoryImpl implements AgentRepository {
  final SupabaseAgentDatasource _remoteDatasource;
  final ConnectivityHelper _connectivity;

  AgentRepositoryImpl({
    required SupabaseAgentDatasource remoteDatasource,
    required ConnectivityHelper connectivity,
  })  : _remoteDatasource = remoteDatasource,
        _connectivity = connectivity;

  @override
  Future<Either<Failure, List<Agent>>> getAgents() async {
    if (!await _connectivity.hasInternet) {
      return const Left(ServerFailure(message: 'تتطلب هذه العملية اتصالاً بالانترنت'));
    }
    try {
      final models = await _remoteDatasource.getAgents();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, Agent>> createAgent({
    required String fullName,
    required String username,
    required String password,
    bool isAdmin = false,
    bool canCreateAgents = false,
  }) async {
    if (!await _connectivity.hasInternet) {
      return const Left(ServerFailure(message: 'تتطلب هذه العملية اتصالاً بالانترنت'));
    }
    try {
      final model = await _remoteDatasource.createAgent(
        fullName: fullName,
        username: username,
        password: password,
        isAdmin: isAdmin,
        canCreateAgents: canCreateAgents,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, Agent>> updateAgentStatus({
    required String agentId,
    required bool isActive,
  }) async {
    if (!await _connectivity.hasInternet) {
      return const Left(ServerFailure(message: 'تتطلب هذه العملية اتصالاً بالانترنت'));
    }
    try {
      final model = await _remoteDatasource.updateAgentStatus(
        agentId: agentId,
        isActive: isActive,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AgentPermission>>> getAgentPermissions(String agentId) async {
    if (!await _connectivity.hasInternet) {
      return const Left(ServerFailure(message: 'تتطلب هذه العملية اتصالاً بالانترنت'));
    }
    try {
      final perms = await _remoteDatasource.getAgentPermissions(agentId);
      return Right(perms);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, AgentPermission>> addAgentPermission({
    required String agentId,
    int? familyId,
    int? subClanId,
    bool isManager = false,
  }) async {
    if (!await _connectivity.hasInternet) {
      return const Left(ServerFailure(message: 'تتطلب هذه العملية اتصالاً بالانترنت'));
    }
    try {
      final perm = await _remoteDatasource.addAgentPermission(
        agentId: agentId,
        familyId: familyId,
        subClanId: subClanId,
        isManager: isManager,
      );
      return Right(perm);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeAgentPermission(int permissionId) async {
    if (!await _connectivity.hasInternet) {
      return const Left(ServerFailure(message: 'تتطلب هذه العملية اتصالاً بالانترنت'));
    }
    try {
      await _remoteDatasource.removeAgentPermission(permissionId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAgent(String agentId) async {
    if (!await _connectivity.hasInternet) {
      return const Left(ServerFailure(message: 'تتطلب هذه العملية اتصالاً بالانترنت'));
    }
    try {
      await _remoteDatasource.deleteAgent(agentId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }
}
