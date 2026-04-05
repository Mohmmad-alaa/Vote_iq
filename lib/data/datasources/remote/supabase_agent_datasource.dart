import 'dart:developer' as developer;
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../../domain/entities/agent_permission.dart';
import '../../models/agent_model.dart';

class SupabaseAgentDatasource {
  final SupabaseClient _client;
  RealtimeChannel? _currentUserPermissionsChannel;
  final _currentUserPermissionChangesController = StreamController<void>.broadcast();

  SupabaseAgentDatasource(this._client);

  Stream<void> get currentUserPermissionChanges {
    _ensureCurrentUserPermissionSubscription();
    return _currentUserPermissionChangesController.stream;
  }

  Future<List<AgentModel>> getAgents() async {
    try {
      final data = await _client
          .from('agents')
          .select()
          .order('created_at', ascending: false);

      return (data as List)
          .map((json) => AgentModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(message: 'خطأ في جلب بيانات الوكلاء: $e');
    }
  }

  Future<AgentModel> createAgent({
    required String fullName,
    required String username,
    required String password,
    required bool isAdmin,
  }) async {
    try {
      final refreshedSession = (await _client.auth.refreshSession()).session;
      final accessToken =
          refreshedSession?.accessToken ?? _client.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw const ServerException(
          message: 'جلسة المدير غير صالحة، أعد تسجيل الدخول',
        );
      }

      final response = await _client.functions.invoke(
        'create-agent',
        body: {
          'full_name': fullName.trim(),
          'username': AppConstants.normalizeUsername(username),
          'password': password,
          'is_admin': isAdmin,
          'access_token': accessToken,
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const ServerException(
          message: 'استجابة غير صالحة من خدمة إنشاء الوكيل',
        );
      }

      return AgentModel.fromJson(Map<String, dynamic>.from(data));
    } catch (e, stack) {
      developer.log('Exception in createAgent', error: e, stackTrace: stack);
      final message = e.toString();

      if (message.contains('اسم المستخدم موجود')) {
        throw const ServerException(message: 'اسم المستخدم موجود مسبقًا');
      }
      if (message.toLowerCase().contains('forbidden')) {
        throw const ServerException(message: 'فقط المدير يمكنه إنشاء الوكلاء');
      }
      if (message.toLowerCase().contains('invalid jwt') ||
          message.toLowerCase().contains('401') ||
          message.toLowerCase().contains('unauthorized')) {
        throw const ServerException(
          message: 'جلسة المدير منتهية أو غير صالحة. سجل الخروج ثم ادخل مرة أخرى.',
        );
      }
      if (message.contains('404') || message.contains('create-agent')) {
        throw const ServerException(
          message: 'خدمة إنشاء الوكلاء غير منشورة بعد على Supabase.',
        );
      }
      if (message.toLowerCase().contains('rate limit')) {
        throw const ServerException(
          message: 'تم تجاوز الحد المؤقت لإنشاء الحسابات. انتظر قليلًا ثم أعد المحاولة.',
        );
      }
      if (e is ServerException) rethrow;
      throw ServerException(message: 'خطأ غير متوقع: $e');
    }
  }

  Future<AgentModel> updateAgentStatus({
    required String agentId,
    required bool isActive,
  }) async {
    try {
      final agentData = await _client
          .from('agents')
          .update({'is_active': isActive})
          .eq('id', agentId)
          .select()
          .single();

      return AgentModel.fromJson(agentData);
    } catch (e) {
      throw ServerException(message: 'خطأ في تحديث حالة الوكيل: $e');
    }
  }

  Future<List<AgentPermission>> getAgentPermissions(String agentId) async {
    try {
      debugPrint(
        '[SupabaseAgentDatasource] getAgentPermissions start: agentId=$agentId',
      );
      final data = await _client
          .from('agent_permissions')
          .select('id, agent_id, family_id, sub_clan_id')
          .eq('agent_id', agentId);

      final rows = (data as List).cast<Map<String, dynamic>>();
      debugPrint(
        '[SupabaseAgentDatasource] getAgentPermissions raw count: '
        'agentId=$agentId, count=${rows.length}',
      );

      return _hydratePermissions(rows);
    } catch (e) {
      debugPrint(
        '[SupabaseAgentDatasource] getAgentPermissions error: '
        'agentId=$agentId, error=$e',
      );
      throw ServerException(message: 'خطأ في جلب صلاحيات الوكيل: $e');
    }
  }

  Future<AgentPermission> addAgentPermission({
    required String agentId,
    int? familyId,
    int? subClanId,
  }) async {
    try {
      debugPrint(
        '[SupabaseAgentDatasource] addAgentPermission start: '
        'agentId=$agentId, familyId=$familyId, subClanId=$subClanId',
      );
      final refreshedSession = (await _client.auth.refreshSession()).session;
      final accessToken =
          refreshedSession?.accessToken ?? _client.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw const ServerException(
          message: 'جلسة المدير غير صالحة، أعد تسجيل الدخول',
        );
      }

      final response = await _client.functions.invoke(
        'add-agent-permission',
        body: {
          'agent_id': agentId,
          if (familyId != null) 'family_id': familyId,
          if (subClanId != null) 'sub_clan_id': subClanId,
          'access_token': accessToken,
        },
      );

      debugPrint(
        '[SupabaseAgentDatasource] addAgentPermission response: '
        'status=${response.status}, data=${response.data}',
      );

      final data = response.data;
      if (data is! Map) {
        throw const ServerException(
          message: 'استجابة غير صالحة من خدمة إضافة الصلاحية',
        );
      }

      final hydrated = await _hydratePermissions([Map<String, dynamic>.from(data)]);
      return hydrated.first;
    } catch (e) {
      debugPrint(
        '[SupabaseAgentDatasource] addAgentPermission error: '
        'agentId=$agentId, familyId=$familyId, subClanId=$subClanId, error=$e',
      );
      throw ServerException(message: 'خطأ في إضافة الصلاحية: $e');
    }
  }

  Future<void> removeAgentPermission(int permissionId) async {
    try {
      await _client.from('agent_permissions').delete().eq('id', permissionId);
    } catch (e) {
      throw ServerException(message: 'خطأ في حذف الصلاحية: $e');
    }
  }

  Future<List<AgentPermission>> _hydratePermissions(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const [];

    final familyIds = rows
        .map((row) => row['family_id'] as int?)
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    final subClanIds = rows
        .map((row) => row['sub_clan_id'] as int?)
        .whereType<int>()
        .toSet()
        .toList(growable: false);

    final familyNamesById = <int, String>{};
    if (familyIds.isNotEmpty) {
      try {
        final familyRows = await _client
            .from('families')
            .select('id, family_name')
            .inFilter('id', familyIds);
        for (final row in familyRows as List) {
          final item = row as Map<String, dynamic>;
          familyNamesById[item['id'] as int] = item['family_name'] as String;
        }
      } catch (_) {
        // Fall back to raw IDs when family lookup names fail remotely.
      }
    }

    final subClanNamesById = <int, String>{};
    if (subClanIds.isNotEmpty) {
      try {
        final subClanRows = await _client
            .from('sub_clans')
            .select('id, sub_name')
            .inFilter('id', subClanIds);
        for (final row in subClanRows as List) {
          final item = row as Map<String, dynamic>;
          subClanNamesById[item['id'] as int] = item['sub_name'] as String;
        }
      } catch (_) {
        // Fall back to raw IDs when sub-clan lookup names fail remotely.
      }
    }

    return rows.map((json) {
      final familyId = json['family_id'] as int?;
      final subClanId = json['sub_clan_id'] as int?;
      return AgentPermission(
        id: json['id'] as int,
        agentId: json['agent_id'] as String,
        familyId: familyId,
        subClanId: subClanId,
        familyName: familyId == null ? null : familyNamesById[familyId],
        subClanName: subClanId == null ? null : subClanNamesById[subClanId],
      );
    }).toList(growable: false);
  }

  void _ensureCurrentUserPermissionSubscription() {
    final user = _client.auth.currentUser;
    if (user == null || _currentUserPermissionsChannel != null) {
      return;
    }

    debugPrint(
      '[SupabaseAgentDatasource] subscribing to current user permission changes: '
      'userId=${user.id}',
    );

    _currentUserPermissionsChannel = _client
        .channel('agent_permissions_current_user_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'agent_permissions',
          callback: _handleCurrentUserPermissionPayload,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'agent_permissions',
          callback: _handleCurrentUserPermissionPayload,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'agent_permissions',
          callback: _handleCurrentUserPermissionPayload,
        )
        .subscribe();
  }

  void _handleCurrentUserPermissionPayload(dynamic payload) {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final newRecord = payload.newRecord as Map<String, dynamic>? ?? const {};
    final oldRecord = payload.oldRecord as Map<String, dynamic>? ?? const {};
    final changedAgentId =
        (newRecord['agent_id'] ?? oldRecord['agent_id'])?.toString();
    if (changedAgentId != currentUserId) {
      return;
    }

    debugPrint(
      '[SupabaseAgentDatasource] current user permission change received: '
      'agentId=$changedAgentId',
    );
    _currentUserPermissionChangesController.add(null);
  }

  void disposeCurrentUserPermissionRealtime() {
    _currentUserPermissionsChannel?.unsubscribe();
    _currentUserPermissionsChannel = null;
    debugPrint(
      '[SupabaseAgentDatasource] current user permission realtime disposed',
    );
  }
}
