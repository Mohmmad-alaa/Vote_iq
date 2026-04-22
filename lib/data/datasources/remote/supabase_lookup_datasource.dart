import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/exceptions.dart';
import '../../models/candidate_model.dart';
import '../../models/electoral_list_model.dart';
import '../../models/family_model.dart';
import '../../models/sub_clan_model.dart';
import '../../models/voting_center_model.dart';

/// Remote datasource for lookup data (families, sub-clans, voting centers).
class SupabaseLookupDatasource {
  final SupabaseClient _client;
  List<int>? _cachedFamilyScopeIds;
  List<int>? _cachedVisibleFamilyIds;
  List<int>? _cachedSubClanIds;
  bool _isAdmin = false;
  bool _hasGlobalAccess = false;
  String? _permissionsLoadedForUserId;
  DateTime? _permissionsCacheTime;
  static const Duration _permissionsTTL = Duration(minutes: 10);

  SupabaseLookupDatasource(this._client);

  void invalidatePermissionsCache() {
    debugPrint('[SupabaseLookupDatasource] permissions cache invalidated');
    _cachedFamilyScopeIds = null;
    _cachedVisibleFamilyIds = null;
    _cachedSubClanIds = null;
    _isAdmin = false;
    _hasGlobalAccess = false;
    _permissionsCacheTime = null;
    _permissionsLoadedForUserId = null;
  }

  /// Only reload permissions if cache has expired or is empty.
  Future<void> _ensurePermissionsLoaded() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      invalidatePermissionsCache();
      return;
    }

    if (_permissionsLoadedForUserId != null &&
        _permissionsLoadedForUserId != currentUserId) {
      invalidatePermissionsCache();
    }

    if (_permissionsCacheTime != null &&
        DateTime.now().difference(_permissionsCacheTime!) < _permissionsTTL) {
      return;
    }
    await _loadPermissionsCache();
    _permissionsCacheTime = DateTime.now();
  }

  Future<void> _loadPermissionsCache() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      invalidatePermissionsCache();
      return;
    }

    if (_permissionsLoadedForUserId != null &&
        _permissionsLoadedForUserId != user.id) {
      debugPrint(
        '[SupabaseLookupDatasource] auth user changed from '
        '$_permissionsLoadedForUserId to ${user.id}, resetting permissions cache',
      );
      invalidatePermissionsCache();
    }
    _permissionsLoadedForUserId = user.id;

    final agentData = await _client
        .from('agents')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    if (agentData == null) return;

    _isAdmin = agentData['role'] == 'admin';
    if (_isAdmin) {
      return;
    }

    var hasGlobalAccess = false;
    final familyScopeIds = <int>[];
    final visibleFamilyIds = <int>[];
    final subClanIds = <int>[];

    final perms = await _client
        .from('agent_permissions')
        .select('family_id, sub_clan_id')
        .eq('agent_id', user.id);

    for (final perm in (perms as List)) {
      final familyId = perm['family_id'] as int?;
      final subClanId = perm['sub_clan_id'] as int?;

      if (familyId == null && subClanId == null) {
        hasGlobalAccess = true;
        continue;
      }

      if (familyId != null) {
        visibleFamilyIds.add(familyId);
      }

      if (familyId != null && subClanId == null) {
        familyScopeIds.add(familyId);
      }

      if (subClanId != null) {
        subClanIds.add(subClanId);
      }
    }

    _hasGlobalAccess = hasGlobalAccess;
    _cachedFamilyScopeIds = familyScopeIds.toSet().toList(growable: false);
    _cachedVisibleFamilyIds = visibleFamilyIds.toSet().toList(growable: false);
    _cachedSubClanIds = subClanIds.toSet().toList(growable: false);
    debugPrint(
      '[SupabaseLookupDatasource] permissions loaded: '
      'isAdmin=$_isAdmin, hasGlobalAccess=$_hasGlobalAccess, '
      'familyScopeIds=$_cachedFamilyScopeIds, '
      'visibleFamilyIds=$_cachedVisibleFamilyIds, '
      'subClanIds=$_cachedSubClanIds',
    );
  }

  Future<List<FamilyModel>> getFamilies() async {
    try {
      await _ensurePermissionsLoaded();

      var query = _client.from('families').select();
      if (!_isAdmin && !_hasGlobalAccess) {
        if (_cachedVisibleFamilyIds == null || _cachedVisibleFamilyIds!.isEmpty) {
          query = query.eq('id', -1);
        } else {
          query = query.inFilter('id', _cachedVisibleFamilyIds!);
        }
      }

      final data = await query.order('family_name', ascending: true);

      return (data as List)
          .map((json) => FamilyModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(message: 'خطأ في جلب العائلات: $e');
    }
  }

  Future<List<SubClanModel>> getSubClans({int? familyId}) async {
    try {
      await _ensurePermissionsLoaded();

      var query = _client.from('sub_clans').select('*, families(family_name)');

      if (!_isAdmin && !_hasGlobalAccess) {
        if (_cachedFamilyScopeIds == null || _cachedSubClanIds == null) {
          query = query.eq('id', -1);
        } else if (_cachedFamilyScopeIds!.isEmpty && _cachedSubClanIds!.isEmpty) {
          query = query.eq('id', -1);
        } else {
          final orConditions = <String>[];
          if (_cachedFamilyScopeIds!.isNotEmpty) {
            orConditions.add('family_id.in.(${_cachedFamilyScopeIds!.join(',')})');
          }
          if (_cachedSubClanIds!.isNotEmpty) {
            orConditions.add('id.in.(${_cachedSubClanIds!.join(',')})');
          }
          query = query.or(orConditions.join(','));
        }
      }

      if (familyId != null) {
        query = query.eq('family_id', familyId);
      }

      final data = await query.order('sub_name', ascending: true);

      return (data as List)
          .map((json) => SubClanModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(message: 'خطأ في جلب الفروع: $e');
    }
  }

  Future<List<VotingCenterModel>> getVotingCenters() async {
    try {
      final data = await _client
          .from('voting_centers')
          .select()
          .order('center_name', ascending: true);

      return (data as List)
          .map(
            (json) => VotingCenterModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw ServerException(message: 'خطأ في جلب مراكز الاقتراع: $e');
    }
  }

  Future<List<ElectoralListModel>> getLists() async {
    try {
      final data = await _client
          .from('electoral_lists')
          .select()
          .order('list_name', ascending: true);

      return (data as List)
          .map(
            (json) =>
                ElectoralListModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw ServerException(message: 'خطأ في جلب القوائم الانتخابية: $e');
    }
  }

  Future<List<CandidateModel>> getCandidates({int? listId}) async {
    try {
      var query = _client.from('candidates').select();

      if (listId != null) {
        query = query.eq('list_id', listId);
      }

      final data = await query.order('candidate_name', ascending: true);

      return (data as List)
          .map(
            (json) => CandidateModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw ServerException(message: 'خطأ في جلب المرشحين: $e');
    }
  }

  Future<FamilyModel> addFamily(String name) async {
    try {
      final data = await _client
          .from('families')
          .insert({'family_name': name})
          .select()
          .single();
      return FamilyModel.fromJson(data);
    } catch (e) {
      throw ServerException(message: 'خطأ في إضافة العائلة: $e');
    }
  }

  Future<void> deleteFamily(int id) async {
    try {
      // Cascade delete: first delete all voters associated with this family
      await _client.from('voters').delete().eq('family_id', id);
      // Then delete the family itself (sub_clans will be auto-deleted by DB constraint)
      await _client.from('families').delete().eq('id', id);
    } catch (e) {
      throw ServerException(message: 'خطأ في حذف العائلة: $e');
    }
  }

  Future<SubClanModel> addSubClan(int familyId, String name) async {
    try {
      final data = await _client
          .from('sub_clans')
          .insert({
            'family_id': familyId,
            'sub_name': name,
          })
          .select('*, families(family_name)')
          .single();
      return SubClanModel.fromJson(data);
    } catch (e) {
      throw ServerException(message: 'خطأ في إضافة الفرع: $e');
    }
  }

  Future<void> deleteSubClan(int id) async {
    try {
      // Instead of deleting voters, we set their sub_clan_id to null so they remain in the family
      await _client.from('voters').update({'sub_clan_id': null}).eq('sub_clan_id', id);
      // Then delete the sub_clan itself
      await _client.from('sub_clans').delete().eq('id', id);
    } catch (e) {
      throw ServerException(message: 'خطأ في حذف الفرع: $e');
    }
  }

  Future<VotingCenterModel> addVotingCenter(String name) async {
    try {
      final data = await _client
          .from('voting_centers')
          .insert({'center_name': name})
          .select()
          .single();
      return VotingCenterModel.fromJson(data);
    } catch (e) {
      throw ServerException(message: 'خطأ في إضافة المركز: $e');
    }
  }

  Future<void> deleteVotingCenter(int id) async {
    try {
      await _client.from('voting_centers').delete().eq('id', id);
    } catch (e) {
      throw ServerException(message: 'خطأ في حذف المركز: $e');
    }
  }

  Future<ElectoralListModel> addElectoralList(String name) async {
    try {
      final data = await _client
          .from('electoral_lists')
          .insert({'list_name': name})
          .select()
          .single();
      return ElectoralListModel.fromJson(data);
    } catch (e) {
      throw ServerException(message: 'خطأ في إضافة القائمة الانتخابية: $e');
    }
  }

  Future<void> deleteElectoralList(int id) async {
    try {
      await _client.from('electoral_lists').delete().eq('id', id);
    } catch (e) {
      throw ServerException(message: 'خطأ في حذف القائمة الانتخابية: $e');
    }
  }

  Future<CandidateModel> addCandidate(String name, {int? listId}) async {
    try {
      final data = await _client
          .from('candidates')
          .insert({
            'candidate_name': name,
            'list_id': listId,
          })
          .select()
          .single();
      return CandidateModel.fromJson(data);
    } catch (e) {
      throw ServerException(message: 'خطأ في إضافة المرشح: $e');
    }
  }

  Future<void> deleteCandidate(int id) async {
    try {
      await _client.from('candidates').delete().eq('id', id);
    } catch (e) {
      throw ServerException(message: 'خطأ في حذف المرشح: $e');
    }
  }
}
