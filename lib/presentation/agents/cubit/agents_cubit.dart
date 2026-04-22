import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/agent_permission.dart';
import '../../../domain/usecases/agent/agent_core_usecases.dart';
import '../../../domain/usecases/agent/agent_permission_usecases.dart';
import 'agents_state.dart';

class AgentsCubit extends Cubit<AgentsState> {
  final GetAgentsUseCase _getAgents;
  final CreateAgentUseCase _createAgent;
  final UpdateAgentStatusUseCase _updateAgentStatus;
  final DeleteAgentUseCase _deleteAgent;
  final GetAgentPermissionsUseCase _getPermissions;
  final AddAgentPermissionUseCase _addPermission;
  final RemoveAgentPermissionUseCase _removePermission;

  AgentsCubit({
    required GetAgentsUseCase getAgents,
    required CreateAgentUseCase createAgent,
    required UpdateAgentStatusUseCase updateAgentStatus,
    required DeleteAgentUseCase deleteAgent,
    required GetAgentPermissionsUseCase getPermissions,
    required AddAgentPermissionUseCase addPermission,
    required RemoveAgentPermissionUseCase removePermission,
  })  : _getAgents = getAgents,
        _createAgent = createAgent,
        _updateAgentStatus = updateAgentStatus,
        _deleteAgent = deleteAgent,
        _getPermissions = getPermissions,
        _addPermission = addPermission,
        _removePermission = removePermission,
        super(AgentsInitial());

  Future<void> loadAgents() async {
    emit(AgentsLoading());
    final result = await _getAgents();
    result.fold(
      (failure) => emit(AgentsError(failure.message)),
      (agents) => emit(AgentsLoaded(agents: agents)),
    );
  }

  Future<void> createAgent({
    required String fullName,
    required String username,
    required String password,
    required bool isAdmin,
    bool canCreateAgents = false,
  }) async {
    final currentState = state;
    if (currentState is! AgentsLoaded) return;

    final result = await _createAgent(
      fullName: fullName,
      username: username,
      password: password,
      isAdmin: isAdmin,
      canCreateAgents: canCreateAgents,
    );

    result.fold(
      (failure) => emit(AgentsError(failure.message)),
      (newAgent) {
        emit(currentState.copyWith(
          agents: [newAgent, ...currentState.agents],
        ));
      },
    );
  }

  Future<void> updateAgentStatus(String agentId, bool isActive) async {
    final currentState = state;
    if (currentState is! AgentsLoaded) return;

    final result = await _updateAgentStatus(agentId: agentId, isActive: isActive);

    result.fold(
      (failure) => emit(AgentsError(failure.message)),
      (updatedAgent) {
        final newAgents = currentState.agents.map((a) {
          return a.id == agentId ? updatedAgent : a;
        }).toList();
        emit(currentState.copyWith(agents: newAgents));
      },
    );
  }

  Future<void> deleteAgent(String agentId) async {
    final currentState = state;
    if (currentState is! AgentsLoaded) return;

    final result = await _deleteAgent(agentId);

    result.fold(
      (failure) => emit(currentState.copyWith(
        actionError: failure.message,
        clearActionMessage: true,
      )),
      (_) {
        final newAgents = currentState.agents.where((a) => a.id != agentId).toList();
        final newPerms = Map<String, List<AgentPermission>>.from(currentState.agentPermissions);
        newPerms.remove(agentId);

        emit(currentState.copyWith(
          agents: newAgents,
          agentPermissions: newPerms,
          actionMessage: 'تم حذف الوكيل بنجاح',
          clearActionError: true,
        ));
      },
    );
  }

  Future<void> loadPermissions(String agentId) async {
    final currentState = state;
    if (currentState is! AgentsLoaded) return;

    developer.log(
      'Loading agent permissions',
      name: 'AgentsCubit',
      error: {'agentId': agentId},
    );
    debugPrint('[AgentsCubit] loadPermissions start: agentId=$agentId');

    final result = await _getPermissions(agentId);

    result.fold(
      (failure) {
        developer.log(
          'Failed to load agent permissions',
          name: 'AgentsCubit',
          error: {'agentId': agentId, 'message': failure.message},
        );
        debugPrint(
          '[AgentsCubit] loadPermissions failed: '
          'agentId=$agentId, message=${failure.message}',
        );
        // Keep the current loaded state so the details screen does not get stuck
        // on a loader when permissions lookup names fail.
        emit(currentState.copyWith(
          actionError: failure.message,
          clearActionMessage: true,
        ));
      },
      (permissions) {
        developer.log(
          'Loaded agent permissions successfully',
          name: 'AgentsCubit',
          error: {'agentId': agentId, 'count': permissions.length},
        );
        debugPrint(
          '[AgentsCubit] loadPermissions success: '
          'agentId=$agentId, count=${permissions.length}',
        );
        final newPerms = Map<String, List<AgentPermission>>.from(currentState.agentPermissions);
        newPerms[agentId] = permissions;
        emit(currentState.copyWith(
          agentPermissions: newPerms,
          clearActionMessage: true,
          clearActionError: true,
        ));
      },
    );
  }

  Future<void> addPermission({
    required String agentId,
    int? familyId,
    int? subClanId,
    bool isManager = false,
  }) async {
    final currentState = state;
    if (currentState is! AgentsLoaded) return;

    developer.log(
      'Adding agent permission',
      name: 'AgentsCubit',
      error: {
        'agentId': agentId,
        'familyId': familyId,
        'subClanId': subClanId,
        'isManager': isManager,
      },
    );
    debugPrint(
      '[AgentsCubit] addPermission start: '
      'agentId=$agentId, familyId=$familyId, subClanId=$subClanId, isManager=$isManager',
    );

    emit(currentState.copyWith(
      isSavingPermission: true,
      clearActionMessage: true,
      clearActionError: true,
    ));

    final result = await _addPermission(
      agentId: agentId,
      familyId: familyId,
      subClanId: subClanId,
      isManager: isManager,
    );

    result.fold(
      (failure) {
        developer.log(
          'Failed to add agent permission',
          name: 'AgentsCubit',
          error: {
            'agentId': agentId,
            'familyId': familyId,
            'subClanId': subClanId,
            'message': failure.message,
          },
        );
        debugPrint(
          '[AgentsCubit] addPermission failed: '
          'agentId=$agentId, familyId=$familyId, '
          'subClanId=$subClanId, message=${failure.message}',
        );
        emit(currentState.copyWith(
          isSavingPermission: false,
          actionError: failure.message,
          clearActionMessage: true,
        ));
      },
      (permission) {
        developer.log(
          'Added agent permission successfully',
          name: 'AgentsCubit',
          error: {
            'agentId': agentId,
            'permissionId': permission.id,
            'familyId': permission.familyId,
            'subClanId': permission.subClanId,
          },
        );
        debugPrint(
          '[AgentsCubit] addPermission success: '
          'agentId=$agentId, permissionId=${permission.id}, '
          'familyId=${permission.familyId}, subClanId=${permission.subClanId}',
        );
        final newPerms = Map<String, List<AgentPermission>>.from(currentState.agentPermissions);
        final agentPerms = List<AgentPermission>.from(newPerms[agentId] ?? []);
        agentPerms.add(permission);
        newPerms[agentId] = agentPerms;

        emit(currentState.copyWith(
          agentPermissions: newPerms,
          isSavingPermission: false,
          actionMessage: 'تمت إضافة الصلاحية بنجاح',
          clearActionError: true,
        ));
      },
    );
  }

  Future<void> removePermission(String agentId, int permissionId) async {
    final currentState = state;
    if (currentState is! AgentsLoaded) return;

    emit(currentState.copyWith(
      isSavingPermission: true,
      clearActionMessage: true,
      clearActionError: true,
    ));

    final result = await _removePermission(permissionId);

    result.fold(
      (failure) => emit(currentState.copyWith(
        isSavingPermission: false,
        actionError: failure.message,
        clearActionMessage: true,
      )),
      (_) {
        final newPerms = Map<String, List<AgentPermission>>.from(currentState.agentPermissions);
        final agentPerms = List<AgentPermission>.from(newPerms[agentId] ?? []);
        agentPerms.removeWhere((p) => p.id == permissionId);
        newPerms[agentId] = agentPerms;

        emit(currentState.copyWith(
          agentPermissions: newPerms,
          isSavingPermission: false,
          actionMessage: 'تم حذف الصلاحية',
          clearActionError: true,
        ));
      },
    );
  }
}
