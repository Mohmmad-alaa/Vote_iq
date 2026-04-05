import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/agent.dart';
import '../../repositories/agent_repository.dart';

class GetAgentsUseCase {
  final AgentRepository repository;
  GetAgentsUseCase(this.repository);

  Future<Either<Failure, List<Agent>>> call() async {
    return await repository.getAgents();
  }
}

class CreateAgentUseCase {
  final AgentRepository repository;
  CreateAgentUseCase(this.repository);

  Future<Either<Failure, Agent>> call({
    required String fullName,
    required String username,
    required String password,
    bool isAdmin = false,
  }) async {
    return await repository.createAgent(
      fullName: fullName,
      username: username,
      password: password,
      isAdmin: isAdmin,
    );
  }
}

class UpdateAgentStatusUseCase {
  final AgentRepository repository;
  UpdateAgentStatusUseCase(this.repository);

  Future<Either<Failure, Agent>> call({
    required String agentId,
    required bool isActive,
  }) async {
    return await repository.updateAgentStatus(
      agentId: agentId,
      isActive: isActive,
    );
  }
}
