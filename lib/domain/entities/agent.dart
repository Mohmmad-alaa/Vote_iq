import 'package:equatable/equatable.dart';

/// Agent (delegate / admin) entity.
class Agent extends Equatable {
  final String id; // UUID
  final String fullName;
  final String username;
  final String role; // 'admin' | 'agent'
  final bool isActive;
  final bool canCreateAgents;
  final DateTime? createdAt;

  const Agent({
    required this.id,
    required this.fullName,
    required this.username,
    this.role = 'agent',
    this.isActive = true,
    this.canCreateAgents = false,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  Agent copyWith({
    String? id,
    String? fullName,
    String? username,
    String? role,
    bool? isActive,
    bool? canCreateAgents,
    DateTime? createdAt,
  }) {
    return Agent(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      canCreateAgents: canCreateAgents ?? this.canCreateAgents,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, fullName, username, role, isActive, canCreateAgents, createdAt];
}
