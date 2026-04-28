import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/voter_household_sort.dart';
import '../../../domain/repositories/voter_repository.dart';
import '../../models/voter_model.dart';

/// Remote datasource for voter operations via Supabase.
class SupabaseVoterDatasource {
  final SupabaseClient _client;
  RealtimeChannel? _realtimeChannel;
  final _voterChangeController = StreamController<VoterModel>.broadcast();

  List<int>? _cachedFamilyScopeIds;
  List<int>? _cachedVisibleFamilyIds;
  List<int>? _cachedSubClanIds;
  List<int>? _managerFamilyIds;
  List<int>? _managerSubClanIds;
  bool _isAdmin = false;
  String? _agentUsername;
  bool _hasGlobalAccess = false;
  bool _hasGlobalManagerAccess = false;
  DateTime? _permissionsCacheTime;
  String? _permissionsLoadedForUserId;
  bool? _householdColumnsAvailable;
  static const Duration _permissionsTTL = Duration(minutes: 10);

  SupabaseVoterDatasource(this._client);

  void invalidatePermissionsCache() {
    debugPrint('[SupabaseVoterDatasource] permissions cache invalidated');
    _cachedFamilyScopeIds = null;
    _cachedVisibleFamilyIds = null;
    _cachedSubClanIds = null;
    _managerFamilyIds = null;
    _managerSubClanIds = null;
    _isAdmin = false;
    _agentUsername = null;
    _hasGlobalAccess = false;
    _hasGlobalManagerAccess = false;
    _permissionsCacheTime = null;
    _permissionsLoadedForUserId = null;
  }

  bool get isAnyManager => 
      _isAdmin || 
      _hasGlobalManagerAccess || 
      (_managerFamilyIds?.isNotEmpty ?? false) || 
      (_managerSubClanIds?.isNotEmpty ?? false);

  /// Asynchronously checks if the agent is a manager, ensuring permissions are loaded first.
  Future<bool> checkIsAnyManager() async {
    await _ensurePermissionsLoaded();
    return isAnyManager;
  }

  String _serializeScopeIds(List<int>? ids) {
    if (ids == null || ids.isEmpty) {
      return '';
    }

    final sorted = List<int>.from(ids)..sort();
    return sorted.join(',');
  }

  Future<String> getPermissionScopeCacheKey() async {
    await _ensurePermissionsLoaded();

    if (_isAdmin) {
      return 'admin';
    }

    if (_hasGlobalAccess) {
      return 'global:${_hasGlobalManagerAccess ? 1 : 0}';
    }

    return 'restricted:'
        'f=${_serializeScopeIds(_cachedFamilyScopeIds)};'
        'vf=${_serializeScopeIds(_cachedVisibleFamilyIds)};'
        's=${_serializeScopeIds(_cachedSubClanIds)};'
        'mf=${_serializeScopeIds(_managerFamilyIds)};'
        'ms=${_serializeScopeIds(_managerSubClanIds)};'
        'gm=${_hasGlobalManagerAccess ? 1 : 0}';
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
      debugPrint(
        '[SupabaseVoterDatasource] auth user changed from '
        '$_permissionsLoadedForUserId to $currentUserId, resetting permissions cache',
      );
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
    if (user == null) return;
    _permissionsLoadedForUserId = user.id;

    final agentData = await _client
        .from('agents')
        .select('role, username') // Included username to enforce super-admin restrictions
        .eq('id', user.id)
        .maybeSingle();
    if (agentData == null) return;
    _isAdmin = agentData['role'] == 'admin';
    _agentUsername = agentData['username'] as String?;
    var hasGlobalAccess = false;
    var hasGlobalManagerAccess = false;
    final familyScopeIds = <int>[];
    final visibleFamilyIds = <int>[];
    final subClanIds = <int>[];
    final managerFamilyIds = <int>[];
    final managerSubClanIds = <int>[];
    if (_isAdmin) return;

    final perms = await _client
        .from('agent_permissions')
        .select('family_id, sub_clan_id, is_manager')
        .eq('agent_id', user.id);
    for (final p in (perms as List)) {
      final familyId = p['family_id'] as int?;
      final subClanId = p['sub_clan_id'] as int?;
      final isManager = p['is_manager'] as bool? ?? false;

      if (familyId == null && subClanId == null) {
        hasGlobalAccess = true;
        if (isManager) hasGlobalManagerAccess = true;
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

      if (isManager) {
        if (familyId != null && subClanId == null) managerFamilyIds.add(familyId);
        if (subClanId != null) managerSubClanIds.add(subClanId);
      }
    }

    _hasGlobalAccess = hasGlobalAccess;
    _hasGlobalManagerAccess = hasGlobalManagerAccess;
    _cachedFamilyScopeIds = familyScopeIds.toSet().toList(growable: false);
    _cachedVisibleFamilyIds = visibleFamilyIds.toSet().toList(growable: false);
    _cachedSubClanIds = subClanIds.toSet().toList(growable: false);
    _managerFamilyIds = managerFamilyIds.toSet().toList(growable: false);
    _managerSubClanIds = managerSubClanIds.toSet().toList(growable: false);
    debugPrint(
      '[SupabaseVoterDatasource] permissions loaded: '
      'isAdmin=$_isAdmin, hasGlobalAccess=$_hasGlobalAccess, '
      'familyScopeIds=$_cachedFamilyScopeIds, '
      'visibleFamilyIds=$_cachedVisibleFamilyIds, '
      'subClanIds=$_cachedSubClanIds, '
      'isAnyManager=$isAnyManager',
    );
  }

  dynamic _applyAgentPermissionsFilter(
    dynamic query, {
    bool includeManageableUnassigned = false,
  }) {
    if (_isAdmin || _hasGlobalAccess) return query;
    if (_cachedFamilyScopeIds == null || _cachedSubClanIds == null) {
      return query.eq('voter_symbol', 'NO_PERMISSION_FALLBACK');
    }

    if (_cachedFamilyScopeIds!.isEmpty &&
        _cachedSubClanIds!.isEmpty &&
        (!includeManageableUnassigned || !isAnyManager)) {
      return query.eq('voter_symbol', 'NO_PERMISSION_FALLBACK');
    }

    final orConditions = <String>[];
    if (_cachedFamilyScopeIds!.isNotEmpty) {
      orConditions.add('family_id.in.(${_cachedFamilyScopeIds!.join(',')})');
    }
    if (_cachedSubClanIds!.isNotEmpty) {
      orConditions.add('sub_clan_id.in.(${_cachedSubClanIds!.join(',')})');
    }
    if (includeManageableUnassigned && isAnyManager) {
      orConditions.add('sub_clan_id.is.null');
    }

    return query.or(orConditions.join(','));
  }

  /// The select query with joined lookup names.
  static const String _selectWithJoins =
      '*, families(family_name), sub_clans(sub_name), voting_centers(center_name), electoral_lists(list_name), candidates:candidates!voters_candidate_id_fkey(candidate_name, electoral_lists(list_name))';

  /// Basic select without joins — for fast writes.
  static const String _selectBasic = '*';

  String _sanitizeSearchQuery(String value) {
    return value.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '').trim();
  }

  String _extractNestedText(dynamic source, String key) {
    if (source is Map && source[key] is String) {
      return source[key] as String;
    }
    return '';
  }

  String _buildSearchText(Map<String, dynamic> row) {
    final candidate = row['candidates'];
    final candidateList = candidate is Map ? candidate['electoral_lists'] : null;

    return [
      row['voter_symbol'],
      row['first_name'],
      row['father_name'],
      row['grandfather_name'],
      _extractNestedText(row['families'], 'family_name'),
      _extractNestedText(row['sub_clans'], 'sub_name'),
      _extractNestedText(row['voting_centers'], 'center_name'),
      _extractNestedText(row['electoral_lists'], 'list_name'),
      _extractNestedText(candidate, 'candidate_name'),
      _extractNestedText(candidateList, 'list_name'),
    ].whereType<String>()
        .join(' ')
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '')
        .trim()
        .toLowerCase();
  }

  bool _matchesSearchQuery(Map<String, dynamic> row, String queryText) {
    final normalizedQuery = _sanitizeSearchQuery(queryText).toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final terms = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    if (terms.isEmpty) {
      return true;
    }

    final searchText = _buildSearchText(row);
    return terms.every(searchText.contains);
  }

  String _escapeOrValue(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll(',', r'\,')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }

  dynamic _applyFilterConstraints(dynamic query, VoterFilter filter) {
    var filtered = query;
    if (filter.familyIds != null && filter.familyIds!.isNotEmpty) {
      filtered = filtered.inFilter('family_id', filter.familyIds!);
    }
    if (filter.subClanId != null) {
      filtered = filtered.eq('sub_clan_id', filter.subClanId!);
    }
    if (filter.centerId != null) {
      filtered = filtered.eq('center_id', filter.centerId!);
    }
    if (filter.status != null) {
      filtered = filtered.eq('status', filter.status!);
    }
    return filtered;
  }

  Map<int, int> _parseCountMap(dynamic raw) {
    if (raw is! Map) {
      return <int, int>{};
    }

    final parsed = <int, int>{};
    raw.forEach((key, value) {
      final parsedKey = int.tryParse(key.toString());
      final parsedValue = value is int
          ? value
          : int.tryParse(value.toString());
      if (parsedKey != null && parsedValue != null) {
        parsed[parsedKey] = parsedValue;
      }
    });
    return parsed;
  }

  bool _isMissingHouseholdColumnError(Object error) {
    if (error is PostgrestException) {
      final details = [
        error.message,
        error.details,
        error.hint,
      ].join(' ').toLowerCase();
      return error.code == '42703' &&
          (details.contains('household_group') ||
              details.contains('household_role') ||
              details.contains('household_role_rank'));
    }

    final text = error.toString().toLowerCase();
    return text.contains('42703') &&
        (text.contains('household_group') ||
            text.contains('household_role') ||
            text.contains('household_role_rank'));
  }

  void _markHouseholdColumnsUnavailable(String operation) {
    if (_householdColumnsAvailable == false) {
      return;
    }
    _householdColumnsAvailable = false;
    debugPrint(
      '[SupabaseVoterDatasource] household columns unavailable during '
      '$operation, falling back to legacy schema behavior',
    );
  }

  Map<String, dynamic> _stripHouseholdFields(
    Map<String, dynamic> payload,
  ) {
    final sanitized = Map<String, dynamic>.from(payload);
    sanitized.remove('household_group');
    sanitized.remove('household_role');
    sanitized.remove('household_role_rank');
    return sanitized;
  }

  List<Map<String, dynamic>> _stripHouseholdFieldsFromList(
    List<Map<String, dynamic>> rows,
  ) {
    return rows.map(_stripHouseholdFields).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchPagedRows(
    dynamic query, {
    int page = 0,
    int pageSize = 0,
  }) async {
    dynamic buildOrderedQuery(bool includeHouseholdSort) {
      var ordered = query.order('family_id', ascending: true);
      if (includeHouseholdSort) {
        ordered = ordered
            .order('household_group', ascending: true)
            .order('household_role_rank', ascending: true);
      }
      return ordered.order('voter_symbol', ascending: true);
    }

    Future<List<Map<String, dynamic>>> runFetch(bool includeHouseholdSort) async {
      final orderedQuery = buildOrderedQuery(includeHouseholdSort);

      if (pageSize > 0) {
        final offset = page * pageSize;
        final response = await orderedQuery.range(offset, offset + pageSize - 1);
        return (response as List).cast<Map<String, dynamic>>();
      }

      final allRows = <Map<String, dynamic>>[];
      const chunkSize = 1000;
      int offset = 0;

      while (true) {
        final response = await orderedQuery.range(offset, offset + chunkSize - 1);
        if (response.isEmpty) {
          break;
        }
        allRows.addAll((response as List).cast<Map<String, dynamic>>());
        if (response.length < chunkSize) {
          break;
        }
        offset += chunkSize;
      }

      return allRows;
    }

    if (_householdColumnsAvailable == false) {
      return runFetch(false);
    }

    try {
      final rows = await runFetch(true);
      _householdColumnsAvailable ??= true;
      return rows;
    } catch (e) {
      if (_isMissingHouseholdColumnError(e)) {
        _markHouseholdColumnsUnavailable('_fetchPagedRows');
        return runFetch(false);
      }
      rethrow;
    }
  }

  Future<int> getVotersCount(VoterFilter filter) async {
    try {
      final queryText = _sanitizeSearchQuery(filter.searchQuery ?? '');

      if (queryText.isEmpty) {
        await _ensurePermissionsLoaded();
        var query = _client.from('voters').select('voter_symbol');
        query = _applyAgentPermissionsFilter(
          query,
          includeManageableUnassigned: filter.includeManageableUnassigned,
        );
        query = _applyFilterConstraints(query, filter);
        final rows = await _fetchPagedRows(query);
        return rows.length;
      }

      await _ensurePermissionsLoaded();
      var query = _client.from('voters').select(_selectWithJoins);
      query = _applyAgentPermissionsFilter(
        query,
        includeManageableUnassigned: filter.includeManageableUnassigned,
      );
      query = _applyFilterConstraints(query, filter);
      final rows = await _fetchPagedRows(query);
      return rows.where((row) => _matchesSearchQuery(row, queryText)).length;
    } catch (e) {
      throw ServerException(message: 'خطأ في عد الناخبين: $e');
    }
  }

  /// Get paginated voters with optional filters.
  Future<List<VoterModel>> getVoters(VoterFilter filter) async {
    final stopwatch = Stopwatch()..start();
    try {
      final queryText = _sanitizeSearchQuery(filter.searchQuery ?? '');
      final resultsBySymbol = <String, Map<String, dynamic>>{};

      if (queryText.isEmpty) {
        await _ensurePermissionsLoaded();
        var query = _client.from('voters').select(_selectWithJoins);
        query = _applyAgentPermissionsFilter(
          query,
          includeManageableUnassigned: filter.includeManageableUnassigned,
        );
        query = _applyFilterConstraints(query, filter);
        final allVoters = await _fetchPagedRows(
          query,
          page: filter.page,
          pageSize: filter.pageSize,
        );

        print(
          'DEBUG: getVoters returned ${allVoters.length} records (with filters)',
        );
        debugPrint(
          '[SupabaseVoterDatasource] getVoters completed in '
          '${stopwatch.elapsedMilliseconds}ms count=${allVoters.length}',
        );

        return allVoters.map(VoterModel.fromJson).toList();
      }

      await _ensurePermissionsLoaded();
      var query = _client.from('voters').select(_selectWithJoins);
      query = _applyAgentPermissionsFilter(
        query,
        includeManageableUnassigned: filter.includeManageableUnassigned,
      );
      query = _applyFilterConstraints(query, filter);
      final rows = await _fetchPagedRows(query);
      for (final row in rows) {
        if (_matchesSearchQuery(row, queryText)) {
          final symbol = row['voter_symbol'] as String;
          resultsBySymbol[symbol] = row;
        }
      }

      final allVoters = resultsBySymbol.values.toList()
        ..sort(compareVoterMapsByHousehold);
      final pagedVoters = filter.pageSize > 0
          ? allVoters
              .skip(filter.page * filter.pageSize)
              .take(filter.pageSize)
              .toList(growable: false)
          : allVoters;

      print(
        'DEBUG: getVoters returned ${pagedVoters.length} records (with filters)',
      );
      debugPrint(
        '[SupabaseVoterDatasource] getVoters search completed in '
        '${stopwatch.elapsedMilliseconds}ms count=${pagedVoters.length}',
      );

      return pagedVoters.map(VoterModel.fromJson).toList();
    } catch (e) {
      throw ServerException(message: 'خطأ في جلب بيانات الناخبين: $e');
    }
  }

  /// Search voters by name, father, grandfather, family, or electoral number.
  Future<List<VoterModel>> searchVoters(String queryStr) async {
    try {
      if (queryStr.isEmpty) return [];

      final cleanQuery = _sanitizeSearchQuery(queryStr);
      if (cleanQuery.isEmpty) return [];

      final escapedQuery = _escapeOrValue(cleanQuery);
      final resultsBySymbol = <String, Map<String, dynamic>>{};

      await _ensurePermissionsLoaded();
      var byNameOrSymbolQuery = _client.from('voters').select(_selectWithJoins);
      byNameOrSymbolQuery = _applyAgentPermissionsFilter(byNameOrSymbolQuery);
      byNameOrSymbolQuery = byNameOrSymbolQuery.or(
        'voter_symbol.ilike.%$escapedQuery%,first_name.ilike.%$escapedQuery%,father_name.ilike.%$escapedQuery%,grandfather_name.ilike.%$escapedQuery%',
      );
      final byNameOrSymbol = await byNameOrSymbolQuery
          .order('voter_symbol', ascending: true)
          .limit(1000);
      for (final row in byNameOrSymbol as List) {
        final data = row as Map<String, dynamic>;
        resultsBySymbol[data['voter_symbol'] as String] = data;
      }

      final familyData = await _client
          .from('families')
          .select('id')
          .ilike('family_name', '%$cleanQuery%');
      final familyIds = (familyData as List)
          .map((f) => f['id'] as int)
          .toList();

      if (familyIds.isNotEmpty) {
        var byFamilyQuery = _client.from('voters').select(_selectWithJoins);
        byFamilyQuery = _applyAgentPermissionsFilter(byFamilyQuery);
        byFamilyQuery = byFamilyQuery.inFilter('family_id', familyIds);
        final byFamily = await byFamilyQuery
            .order('voter_symbol', ascending: true)
            .limit(1000);
        for (final row in byFamily as List) {
          final data = row as Map<String, dynamic>;
          resultsBySymbol[data['voter_symbol'] as String] = data;
        }
      }

      final subClanData = await _client
          .from('sub_clans')
          .select('id')
          .ilike('sub_name', '%$cleanQuery%');
      final subClanIds = (subClanData as List)
          .map((s) => s['id'] as int)
          .toList();

      if (subClanIds.isNotEmpty) {
        var bySubClanQuery = _client.from('voters').select(_selectWithJoins);
        bySubClanQuery = _applyAgentPermissionsFilter(bySubClanQuery);
        bySubClanQuery = bySubClanQuery.inFilter('sub_clan_id', subClanIds);
        final bySubClan = await bySubClanQuery
            .order('voter_symbol', ascending: true)
            .limit(1000);
        for (final row in bySubClan as List) {
          final data = row as Map<String, dynamic>;
          resultsBySymbol[data['voter_symbol'] as String] = data;
        }
      }

      final sorted = resultsBySymbol.values.toList()
        ..sort(compareVoterMapsByHousehold);

      return sorted.map(VoterModel.fromJson).toList();
    } catch (e) {
      throw ServerException(message: 'خطأ في البحث: $e');
    }
  }

  /// Get all unique family names from families table (for filter dropdown).
  Future<List<String>> getAllUniqueFamilies() async {
    try {
      await _ensurePermissionsLoaded();

      var query = _client.from('families').select('family_name');
      if (!_isAdmin && !_hasGlobalAccess) {
        if (_cachedVisibleFamilyIds == null ||
            _cachedVisibleFamilyIds!.isEmpty) {
          query = query.eq('id', -1);
        } else {
          query = query.inFilter('id', _cachedVisibleFamilyIds!);
        }
      }

      final data = await query.order('family_name', ascending: true);

      final names = (data as List)
          .map((row) => row['family_name'] as String)
          .toList();
      return names;
    } catch (e) {
      throw ServerException(message: 'خطأ في جلب أسماء العائلات: $e');
    }
  }

  /// Get all families with IDs (for filter dropdown with server-side filtering).
  Future<Map<String, int>> getFamiliesMap() async {
    try {
      await _ensurePermissionsLoaded();

      var query = _client.from('families').select('id, family_name');
      if (!_isAdmin && !_hasGlobalAccess) {
        if (_cachedVisibleFamilyIds == null ||
            _cachedVisibleFamilyIds!.isEmpty) {
          query = query.eq('id', -1);
        } else {
          query = query.inFilter('id', _cachedVisibleFamilyIds!);
        }
      }

      final data = await query.order('family_name', ascending: true);

      final map = <String, int>{};
      for (final row in data as List) {
        map[row['family_name'] as String] = row['id'] as int;
      }
      return map;
    } catch (e) {
      throw ServerException(message: 'خطأ في جلب العائلات: $e');
    }
  }

  /// Update a voter's status.
  Future<VoterModel> updateVoterStatus({
    required String voterSymbol,
    required String newStatus,
    String? refusalReason,
    int? listId,
    int? candidateId,
    required String agentId,
  }) async {
    try {
      debugPrint(
        '[SupabaseVoterDatasource] updateVoterStatus start: '
        'voterSymbol=$voterSymbol, newStatus=$newStatus, '
        'refusalReason=$refusalReason, listId=$listId, '
        'candidateId=$candidateId, agentId=$agentId',
      );
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_by': agentId,
      };

      // Set or clear refusal reason based on status
      if (newStatus == AppConstants.statusRefused) {
        updateData['refusal_reason'] = refusalReason;
        updateData['list_id'] = null;
        updateData['candidate_id'] = null;
      } else if (newStatus == AppConstants.statusVoted) {
        updateData['refusal_reason'] = null;
        updateData['list_id'] = listId;
        updateData['candidate_id'] = candidateId;
      } else {
        updateData['refusal_reason'] = null;
        updateData['list_id'] = null;
        updateData['candidate_id'] = null;
      }

      final responseList = await _client
          .from('voters')
          .update(updateData)
          .eq('voter_symbol', voterSymbol)
          .select(_selectBasic);

      if (responseList.isEmpty) {
        throw ServerException(message: 'لم يتم العثور على الناخب في السيرفر أو لا تملك صلاحية تعديله');
      }

      final data = responseList.first;
      
      debugPrint(
        '[SupabaseVoterDatasource] updateVoterStatus success: '
        'voterSymbol=$voterSymbol, returnedStatus=${data['status']}',
      );
      return VoterModel.fromJson(data);
    } catch (e) {
      throw ServerException(message: 'خطأ في تحديث حالة الناخب: $e');
    }
  }

  /// Get voting statistics.
  Future<VoterStats> getVoterStats({
    int? familyId,
    int? subClanId,
    int? centerId,
  }) async {
    try {
      await _ensurePermissionsLoaded();
      final stopwatch = Stopwatch()..start();
      var query = _client.from('voters').select('voter_symbol, status');
      query = _applyAgentPermissionsFilter(query);

      if (familyId != null) query = query.eq('family_id', familyId);
      if (subClanId != null) query = query.eq('sub_clan_id', subClanId);
      if (centerId != null) query = query.eq('center_id', centerId);

      final list = await _fetchPagedRows(query);

      final total = list.length;
      final voted = list
          .where((r) => r['status'] == AppConstants.statusVoted)
          .length;
      final refused = list
          .where((r) => r['status'] == AppConstants.statusRefused)
          .length;
      final notFound = list
          .where((r) => r['status'] == AppConstants.statusNotFound)
          .length;
      final notVoted = total - voted - refused - notFound;

      final stats = VoterStats(
        total: total,
        voted: voted,
        refused: refused,
        notVoted: notVoted,
        notFound: notFound,
        votedPercentage: total > 0 ? (voted / total) * 100 : 0,
      );
      debugPrint(
        '[SupabaseVoterDatasource] getVoterStats completed in '
        '${stopwatch.elapsedMilliseconds}ms total=$total',
      );
      return stats;
    } catch (e) {
      throw ServerException(message: 'خطأ في جلب الإحصائيات: $e');
    }
  }

  /// Create a new voter.
  Future<VoterModel> createVoter(VoterModel voter) async {
    try {
      final payload = voter.toJson();

      Future<dynamic> execute(Map<String, dynamic> requestBody) {
        return _client
            .from('voters')
            .insert(requestBody)
            .select(_selectWithJoins)
            .single();
      }

      dynamic data;
      if (_householdColumnsAvailable == false) {
        data = await execute(_stripHouseholdFields(payload));
      } else {
        try {
          data = await execute(payload);
          _householdColumnsAvailable ??= true;
        } catch (e) {
          if (_isMissingHouseholdColumnError(e)) {
            _markHouseholdColumnsUnavailable('createVoter');
            data = await execute(_stripHouseholdFields(payload));
          } else {
            rethrow;
          }
        }
      }
      return VoterModel.fromJson(data);
    } catch (e) {
      throw ServerException(message: 'خطأ في إضافة الناخب: $e');
    }
  }

  /// Update an existing voter.
  Future<VoterModel> updateVoter(VoterModel voter) async {
    try {
      final payload = voter.toJson()
        ..['family_id'] = voter.familyId
        ..['sub_clan_id'] = voter.subClanId
        ..['center_id'] = voter.centerId
        ..['list_id'] = voter.listId
        ..['candidate_id'] = voter.candidateId
        ..['refusal_reason'] = voter.refusalReason
        ..['household_group'] = voter.householdGroup
        ..['household_role'] = voter.householdRole;

      Future<dynamic> execute(Map<String, dynamic> requestBody) {
        return _client
            .from('voters')
            .update(requestBody)
            .eq('voter_symbol', voter.voterSymbol)
            .select(_selectWithJoins)
            .single();
      }

      dynamic data;
      if (_householdColumnsAvailable == false) {
        data = await execute(_stripHouseholdFields(payload));
      } else {
        try {
          data = await execute(payload);
          _householdColumnsAvailable ??= true;
        } catch (e) {
          if (_isMissingHouseholdColumnError(e)) {
            _markHouseholdColumnsUnavailable('updateVoter');
            data = await execute(_stripHouseholdFields(payload));
          } else {
            rethrow;
          }
        }
      }
      return VoterModel.fromJson(data);
    } catch (e) {
      throw ServerException(message: 'خطأ في تحديث بيانات الناخب: $e');
    }
  }

  /// Delete a voter.
  Future<void> deleteVoter(String voterSymbol) async {
    try {
      await _client.from('voters').delete().eq('voter_symbol', voterSymbol);
    } catch (e) {
      throw ServerException(message: 'خطأ في حذف الناخب: $e');
    }
  }

  /// Reset all voters to default state (not voted, no list/candidate).
  Future<void> resetAllVoters() async {
    try {
      await _ensurePermissionsLoaded();
      if (_agentUsername != 'admin') {
        throw ServerException(message: 'غير مصرح لك بإجراء هذا التحديث الشامل. هذه الصلاحية مخصصة للمسؤول الرئيسي فقط.');
      }

      await _client.from('voters').update({
        'status': AppConstants.statusNotVoted,
        'refusal_reason': null,
        'list_id': null,
        'candidate_id': null,
        'updated_by': _client.auth.currentUser?.id,
      }).neq('voter_symbol', '');

    } catch (e) {
      throw ServerException(message: 'خطأ في تصفير المصوتين: $e');
    }
  }

  /// Bulk insert voters (for Excel import).
  Future<void> bulkInsertVoters(List<VoterModel> voters) async {
    try {
      final jsonList = voters.map((v) => v.toJson()).toList(growable: false);

      Future<void> execute(List<Map<String, dynamic>> rows) async {
        const chunkSize = 1000;
        for (var i = 0; i < rows.length; i += chunkSize) {
          final end = (i + chunkSize < rows.length) ? i + chunkSize : rows.length;
          final chunk = rows.sublist(i, end);
          await _client.from('voters').upsert(chunk, onConflict: 'voter_symbol');
        }
      }

      if (_householdColumnsAvailable == false) {
        await execute(_stripHouseholdFieldsFromList(jsonList));
      } else {
        try {
          await execute(jsonList);
          _householdColumnsAvailable ??= true;
        } catch (e) {
          if (_isMissingHouseholdColumnError(e)) {
            _markHouseholdColumnsUnavailable('bulkInsertVoters');
            await execute(_stripHouseholdFieldsFromList(jsonList));
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      throw ServerException(message: 'خطأ في الاستيراد الجماعي: $e');
    }
  }

  /// Returns the subset of voter symbols that already exist remotely.
  Future<Set<String>> getExistingVoterSymbols(List<String> voterSymbols) async {
    try {
      final existing = <String>{};
      const chunkSize = 500;

      for (var i = 0; i < voterSymbols.length; i += chunkSize) {
        final end = (i + chunkSize < voterSymbols.length)
            ? i + chunkSize
            : voterSymbols.length;
        final chunk = voterSymbols.sublist(i, end);
        if (chunk.isEmpty) {
          continue;
        }

        final rows = await _client
            .from('voters')
            .select('voter_symbol')
            .inFilter('voter_symbol', chunk);

        for (final row in rows as List) {
          final symbol = (row as Map<String, dynamic>)['voter_symbol'] as String?;
          if (symbol != null && symbol.isNotEmpty) {
            existing.add(symbol);
          }
        }
      }

      return existing;
    } catch (e) {
      throw ServerException(
        message: 'خطأ في فحص الناخبين الموجودين قبل التحديث الآمن: $e',
      );
    }
  }

  /// Updates household columns only and never inserts new voters.
  Future<int> bulkUpdateVoterHouseholds(List<VoterModel> voters) async {
    try {
      if (_householdColumnsAvailable == false) {
        throw ServerException(
          message: 'أعمدة الأسرة غير متوفرة في قاعدة البيانات الحالية.',
        );
      }

      var updatedCount = 0;
      const chunkSize = 50;

      for (var i = 0; i < voters.length; i += chunkSize) {
        final end = (i + chunkSize < voters.length) ? i + chunkSize : voters.length;
        final chunk = voters.sublist(i, end);

        Future<void> updateChunk() async {
          await Future.wait(
            chunk.map<Future<dynamic>>((voter) {
              final payload = <String, dynamic>{
                'household_group': voter.householdGroup,
                'household_role': voter.householdRole,
              };
              return _client
                  .from('voters')
                  .update(payload)
                  .eq('voter_symbol', voter.voterSymbol);
            }),
          );
        }

        try {
          await updateChunk();
          updatedCount += chunk.length;
          _householdColumnsAvailable ??= true;
        } catch (e) {
          if (_isMissingHouseholdColumnError(e)) {
            _markHouseholdColumnsUnavailable('bulkUpdateVoterHouseholds');
            throw ServerException(
              message:
                  'تعذر تنفيذ التحديث الآمن لأن أعمدة الأسرة غير موجودة في قاعدة البيانات.',
            );
          }
          rethrow;
        }
      }

      return updatedCount;
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'خطأ في التحديث الآمن لبيانات الأسرة: $e');
    }
  }

  /// Updates family and sub_clan columns only and never inserts new voters.
  Future<int> bulkUpdateVoterSubClans(List<VoterModel> voters) async {
    try {
      var updatedCount = 0;
      const chunkSize = 50;

      for (var i = 0; i < voters.length; i += chunkSize) {
        final end = (i + chunkSize < voters.length) ? i + chunkSize : voters.length;
        final chunk = voters.sublist(i, end);

        await Future.wait(
          chunk.map<Future<dynamic>>((voter) {
            final payload = <String, dynamic>{
              'family_id': voter.familyId,
              'sub_clan_id': voter.subClanId,
            };
            return _client
                .from('voters')
                .update(payload)
                .eq('voter_symbol', voter.voterSymbol);
          }),
        );
        updatedCount += chunk.length;
      }

      return updatedCount;
    } catch (e) {
      throw ServerException(message: 'خطأ في التحديث الآمن للفروع: $e');
    }
  }

  /// Subscribe to real-time voter changes.
  Stream<VoterModel> get voterChanges {
    _loadPermissionsCache().then((_) {
      _realtimeChannel ??= _client
          .channel('voters_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'voters',
            callback: (payload) {
              if (payload.newRecord.isNotEmpty) {
                try {
                  final model = VoterModel.fromJson(payload.newRecord);

                  if (!_isAdmin) {
                    if (_hasGlobalAccess) {
                      _voterChangeController.add(model);
                      return;
                    }

                    if (_cachedFamilyScopeIds != null &&
                        _cachedSubClanIds != null) {
                      final hasFam =
                          model.familyId != null &&
                          _cachedFamilyScopeIds!.contains(model.familyId);
                      final hasSub =
                          model.subClanId != null &&
                          _cachedSubClanIds!.contains(model.subClanId);
                      if (!hasFam && !hasSub) return;
                    }
                  }

                  _voterChangeController.add(model);
                } catch (_) {}
              }
            },
          )
          .subscribe();
    });

    return _voterChangeController.stream;
  }

  /// Dispose real-time subscription.
  void disposeRealtime() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    debugPrint('[SupabaseVoterDatasource] realtime channel disposed');
  }

  /// Get all voters without pagination (for initial load)
  Future<List<VoterModel>> getAllVoters() async {
    final allVoters = <Map<String, dynamic>>[];
    const pageSize = 1000;

    await _ensurePermissionsLoaded();
    var baseQuery = _client.from('voters').select(_selectWithJoins);
    baseQuery = _applyAgentPermissionsFilter(baseQuery);
    debugPrint('[SupabaseVoterDatasource] getAllVoters start');

    Future<List<Map<String, dynamic>>> loadAll(bool includeHouseholdSort) async {
      final rows = <Map<String, dynamic>>[];
      int localOffset = 0;

      while (true) {
        var ordered = baseQuery.order('family_id', ascending: true);
        if (includeHouseholdSort) {
          ordered = ordered
              .order('household_group', ascending: true)
              .order('household_role_rank', ascending: true);
        }

        final response = await ordered
            .order('voter_symbol', ascending: true)
            .range(localOffset, localOffset + pageSize - 1);

        if (response.isEmpty) {
          break;
        }
        rows.addAll((response as List).cast<Map<String, dynamic>>());
        if (response.length < pageSize) {
          break;
        }
        localOffset += pageSize;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      return rows;
    }

    if (_householdColumnsAvailable == false) {
      allVoters.addAll(await loadAll(false));
    } else {
      try {
        allVoters.addAll(await loadAll(true));
        _householdColumnsAvailable ??= true;
      } catch (e) {
        if (_isMissingHouseholdColumnError(e)) {
          _markHouseholdColumnsUnavailable('getAllVoters');
          allVoters
            ..clear()
            ..addAll(await loadAll(false));
        } else {
          rethrow;
        }
      }
    }

    debugPrint(
      '[SupabaseVoterDatasource] getAllVoters result count=${allVoters.length}',
    );

    return allVoters.map((json) => VoterModel.fromJson(json)).toList();
  }

  /// Get voters updated after a specific timestamp (for incremental sync)
  Future<List<VoterModel>> getVotersUpdatedAfter(DateTime since) async {
    await _ensurePermissionsLoaded();
    var query = _client
        .from('voters')
        .select(_selectWithJoins)
        .gt('updated_at', since.toIso8601String());
    query = _applyAgentPermissionsFilter(query);

    Future<dynamic> load(bool includeHouseholdSort) {
      var ordered = query.order('family_id', ascending: true);
      if (includeHouseholdSort) {
        ordered = ordered
            .order('household_group', ascending: true)
            .order('household_role_rank', ascending: true);
      }
      return ordered.order('voter_symbol', ascending: true);
    }

    dynamic response;
    if (_householdColumnsAvailable == false) {
      response = await load(false);
    } else {
      try {
        response = await load(true);
        _householdColumnsAvailable ??= true;
      } catch (e) {
        if (_isMissingHouseholdColumnError(e)) {
          _markHouseholdColumnsUnavailable('getVotersUpdatedAfter');
          response = await load(false);
        } else {
          rethrow;
        }
      }
    }

    return (response as List)
        .map((json) => VoterModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveVoterCandidates({
    required String voterSymbol,
    required List<int> candidateIds,
  }) async {
    final uniqueCandidateIds = <int>[];
    for (final candidateId in candidateIds) {
      if (!uniqueCandidateIds.contains(candidateId)) {
        uniqueCandidateIds.add(candidateId);
      }
    }

    if (uniqueCandidateIds.length > 5) {
      throw ServerException(
        message: 'ظٹط¬ط¨ ط§ط®طھظٹط§ط± 5 ظ…ط±ط´ط­ظٹظ† ظƒط­ط¯ ط£ظ‚طµظ‰',
      );
    }

    try {
      await _client.rpc(
        'replace_voter_candidates',
        params: {
          'p_voter_symbol': voterSymbol,
          'p_candidate_ids': uniqueCandidateIds,
        },
      );
      return;
    } catch (rpcError) {
      debugPrint(
        '[SupabaseVoterDatasource] replace_voter_candidates fallback '
        'voterSymbol=$voterSymbol, error=$rpcError',
      );
    }

    try {
      await _client
          .from('voter_candidates')
          .delete()
          .eq('voter_symbol', voterSymbol);

      if (uniqueCandidateIds.isEmpty) {
        return;
      }

      final rows = <Map<String, dynamic>>[];
      for (int i = 0; i < uniqueCandidateIds.length; i++) {
        rows.add({
          'voter_symbol': voterSymbol,
          'candidate_id': uniqueCandidateIds[i],
          'vote_order': i + 1,
        });
      }

      await _client.from('voter_candidates').insert(rows);
    } catch (e) {
      throw ServerException(message: 'ط®ط·ط£ ظپظٹ ط­ظپط¸ ط§ظ„ظ…ط±ط´ط­ظٹظ†: $e');
    }
  }

  Future<List<int>> getVoterCandidates(String voterSymbol) async {
    final response = await _client
        .rpc('get_voter_candidates', params: {'p_voter_symbol': voterSymbol})
        .order('vote_order', ascending: true);

    if (response == null || (response as List).isEmpty) return [];

    return (response).map((row) => row['candidate_id'] as int).toList();
  }

  Future<Map<String, Map<int, int>>> getListAndCandidateVotes() async {
    final stopwatch = Stopwatch()..start();
    try {
      final rpcResponse = await _client.rpc('get_list_and_candidate_votes');
      if (rpcResponse is Map) {
        final parsed = {
          'listVotes': _parseCountMap(rpcResponse['listVotes']),
          'candidateVotes': _parseCountMap(rpcResponse['candidateVotes']),
        };
        debugPrint(
          '[SupabaseVoterDatasource] getListAndCandidateVotes via RPC in '
          '${stopwatch.elapsedMilliseconds}ms '
          'lists=${parsed['listVotes']!.length}, '
          'candidates=${parsed['candidateVotes']!.length}',
        );
        return parsed;
      }
    } catch (rpcError) {
      debugPrint(
        '[SupabaseVoterDatasource] get_list_and_candidate_votes fallback '
        'error=$rpcError',
      );
    }

    try {
      await _ensurePermissionsLoaded();
      var votersQuery = _client
          .from('voters')
          .select('voter_symbol, list_id')
          .eq('status', AppConstants.statusVoted)
          .not('list_id', 'is', null);
      votersQuery = _applyAgentPermissionsFilter(votersQuery);

      final listData = await votersQuery;
      final Map<int, int> listVotes = {};
      final visibleVoterSymbols = <String>[];

      for (final row in listData as List) {
        final voterSymbol = row['voter_symbol'] as String?;
        if (voterSymbol != null && voterSymbol.isNotEmpty) {
          visibleVoterSymbols.add(voterSymbol);
        }
        final listId = row['list_id'] as int;
        listVotes[listId] = (listVotes[listId] ?? 0) + 1;
      }

      final Map<int, int> candidateVotes = {};
      const chunkSize = 500;
      for (var i = 0; i < visibleVoterSymbols.length; i += chunkSize) {
        final chunk = visibleVoterSymbols.sublist(
          i,
          i + chunkSize > visibleVoterSymbols.length
              ? visibleVoterSymbols.length
              : i + chunkSize,
        );
        if (chunk.isEmpty) continue;

        final candidatesData = await _client
            .from('voter_candidates')
            .select('candidate_id')
            .inFilter('voter_symbol', chunk);

        for (final row in candidatesData as List) {
          final candidateId = row['candidate_id'] as int;
          candidateVotes[candidateId] = (candidateVotes[candidateId] ?? 0) + 1;
        }
      }

      debugPrint(
        '[SupabaseVoterDatasource] getListAndCandidateVotes fallback in '
        '${stopwatch.elapsedMilliseconds}ms '
        'lists=${listVotes.length}, candidates=${candidateVotes.length}',
      );
      return {'listVotes': listVotes, 'candidateVotes': candidateVotes};
    } catch (e) {
      throw ServerException(
        message: 'خطأ في جلب إحصائيات القوائم والمرشحين: $e',
      );
    }
  }
}
