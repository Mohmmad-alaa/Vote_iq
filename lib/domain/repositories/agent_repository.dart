import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../entities/agent.dart';
import '../entities/agent_permission.dart';

abstract class AgentRepository {
  Future<Either<Failure, List<Agent>>> getAgents();
  
  Future<Either<Failure, Agent>> createAgent({
    required String fullName,
    required String username,
    required String password,
    bool isAdmin = false,
  });
  
  Future<Either<Failure, Agent>> updateAgentStatus({
    required String agentId,
    required bool isActive,
  });

  Future<Either<Failure, List<AgentPermission>>> getAgentPermissions(String agentId);

  Future<Either<Failure, AgentPermission>> addAgentPermission({
    required String agentId,
    int? familyId,
    int? subClanId,
  });

  Future<Either<Failure, void>> removeAgentPermission(int permissionId);
}
