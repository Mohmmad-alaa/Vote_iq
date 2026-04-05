import 'package:equatable/equatable.dart';
import '../../../domain/entities/agent.dart';
import '../../../domain/entities/agent_permission.dart';

abstract class AgentsState extends Equatable {
  const AgentsState();
  @override
  List<Object?> get props => [];
}

class AgentsInitial extends AgentsState {}

class AgentsLoading extends AgentsState {}

class AgentsLoaded extends AgentsState {
  final List<Agent> agents;
  final Map<String, List<AgentPermission>> agentPermissions; // agentId -> permissions
  final bool isSavingPermission;
  final String? actionMessage;
  final String? actionError;
  
  const AgentsLoaded({
    required this.agents,
    this.agentPermissions = const {},
    this.isSavingPermission = false,
    this.actionMessage,
    this.actionError,
  });

  AgentsLoaded copyWith({
    List<Agent>? agents,
    Map<String, List<AgentPermission>>? agentPermissions,
    bool? isSavingPermission,
    String? actionMessage,
    String? actionError,
    bool clearActionMessage = false,
    bool clearActionError = false,
  }) {
    return AgentsLoaded(
      agents: agents ?? this.agents,
      agentPermissions: agentPermissions ?? this.agentPermissions,
      isSavingPermission: isSavingPermission ?? this.isSavingPermission,
      actionMessage: clearActionMessage ? null : (actionMessage ?? this.actionMessage),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }

  @override
  List<Object?> get props => [
        agents,
        agentPermissions,
        isSavingPermission,
        actionMessage,
        actionError,
      ];
}

class AgentsError extends AgentsState {
  final String message;
  const AgentsError(this.message);
  @override
  List<Object?> get props => [message];
}
