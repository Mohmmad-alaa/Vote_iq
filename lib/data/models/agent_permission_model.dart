import '../../domain/entities/agent_permission.dart';

/// Agent permission data model.
class AgentPermissionModel {
  final int id;
  final String agentId;
  final int? familyId;
  final int? subClanId;
  final bool isManager;
  final String? familyName;
  final String? subClanName;

  const AgentPermissionModel({
    required this.id,
    required this.agentId,
    this.familyId,
    this.subClanId,
    this.isManager = false,
    this.familyName,
    this.subClanName,
  });

  factory AgentPermissionModel.fromJson(Map<String, dynamic> json) {
    return AgentPermissionModel(
      id: json['id'] as int,
      agentId: json['agent_id'] as String,
      familyId: json['family_id'] as int?,
      subClanId: json['sub_clan_id'] as int?,
      isManager: (json['is_manager'] as bool?) ?? false,
      familyName: json['families'] != null
          ? (json['families'] as Map<String, dynamic>)['family_name'] as String?
          : null,
      subClanName: json['sub_clans'] != null
          ? (json['sub_clans'] as Map<String, dynamic>)['sub_name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agent_id': agentId,
      'family_id': familyId,
      'sub_clan_id': subClanId,
      'is_manager': isManager,
    };
  }

  AgentPermission toEntity() {
    return AgentPermission(
      id: id,
      agentId: agentId,
      familyId: familyId,
      subClanId: subClanId,
      isManager: isManager,
      familyName: familyName,
      subClanName: subClanName,
    );
  }

  factory AgentPermissionModel.fromEntity(AgentPermission entity) {
    return AgentPermissionModel(
      id: entity.id,
      agentId: entity.agentId,
      familyId: entity.familyId,
      subClanId: entity.subClanId,
      isManager: entity.isManager,
      familyName: entity.familyName,
      subClanName: entity.subClanName,
    );
  }
}
