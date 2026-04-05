import '../../domain/entities/agent.dart';

/// Agent data model — JSON serialization for Supabase.
class AgentModel {
  final String id;
  final String fullName;
  final String username;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  const AgentModel({
    required this.id,
    required this.fullName,
    required this.username,
    this.role = 'agent',
    this.isActive = true,
    this.createdAt,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      username: json['username'] as String,
      role: (json['role'] as String?) ?? 'agent',
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'username': username,
      'role': role,
      'is_active': isActive,
    };
  }

  Agent toEntity() {
    return Agent(
      id: id,
      fullName: fullName,
      username: username,
      role: role,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  factory AgentModel.fromEntity(Agent entity) {
    return AgentModel(
      id: entity.id,
      fullName: entity.fullName,
      username: entity.username,
      role: entity.role,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}
