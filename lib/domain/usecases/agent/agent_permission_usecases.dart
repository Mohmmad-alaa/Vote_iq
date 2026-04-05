import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/agent_permission.dart';
import '../../repositories/agent_repository.dart';

class GetAgentPermissionsUseCase {
  final AgentRepository repository;
  GetAgentPermissionsUseCase(this.repository);

  Future<Either<Failure, List<AgentPermission>>> call(String agentId) async {
    return await repository.getAgentPermissions(agentId);
  }
}

class AddAgentPermissionUseCase {
  final AgentRepository repository;
  AddAgentPermissionUseCase(this.repository);

  Future<Either<Failure, AgentPermission>> call({
    required String agentId,
    int? familyId,
    int? subClanId,
  }) async {
    return await repository.addAgentPermission(
      agentId: agentId,
      familyId: familyId,
      subClanId: subClanId,
    );
  }
}

class RemoveAgentPermissionUseCase {
  final AgentRepository repository;
  RemoveAgentPermissionUseCase(this.repository);

  Future<Either<Failure, void>> call(int permissionId) async {
    return await repository.removeAgentPermission(permissionId);
  }
}
