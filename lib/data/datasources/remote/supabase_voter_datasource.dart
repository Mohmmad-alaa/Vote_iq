import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/exceptions.dart';
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
  bool _isAdmin = false;
  bool _hasGlobalAccess = false;
  DateTime? _permissionsCacheTime;
  static const Duration _permissionsTTL = Duration(minutes: 10);

  SupabaseVoterDatasource(this._client);

  void invalidatePermissionsCache() {
    debugPrint('[SupabaseVoterDatasource] permissions cache invalidated');
    _cachedFamilyScopeIds = null;
    _cachedVisibleFamilyIds = null;
    _cachedSubClanIds = null;
    _isAdmin = false;
    _hasGlobalAccess = false;
    _permissionsCacheTime = null;
  }

  /// Only reload permissions if cache has expired or is empty.
  Future<void> _ensurePermissionsLoaded() async {
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

    final agentData = await _client
        .from('agents')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    if (agentData == null) return;
    _isAdmin = agentData['role'] == 'admin';
    var hasGlobalAccess = false;
    final familyScopeIds = <int>[];
    final visibleFamilyIds = <int>[];
    final subClanIds = <int>[];
    if (_isAdmin) return;

    final perms = await _client
        .from('agent_permissions')
        .select('family_id, sub_clan_id')
        .eq('agent_id', user.id);
    for (final p in (perms as List)) {
      final familyId = p['family_id'] as int?;
      final subClanId = p['sub_clan_id'] as int?;

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
      '[SupabaseVoterDatasource] permissions loaded: '
      'isAdmin=$_isAdmin, hasGlobalAccess=$_hasGlobalAccess, '
      'familyScopeIds=$_cachedFamilyScopeIds, '
      'visibleFamilyIds=$_cachedVisibleFamilyIds, '
      'subClanIds=$_cachedSubClanIds',
    );
  }

  dynamic _applyAgentPermissionsFilter(dynamic query) {
    if (_isAdmin || _hasGlobalAccess) return query;
    if (_cachedFamilyScopeIds == null || _cachedSubClanIds == null) {
      return query.eq('voter_symbol', 'NO_PERMISSION_FALLBACK');
    }

    if (_cachedFamilyScopeIds!.isEmpty && _cachedSubClanIds!.isEmpty) {
      return query.eq('voter_symbol', 'NO_PERMISSION_FALLBACK');
    }

    final orConditions = <String>[];
    if (_cachedFamilyScopeIds!.isNotEmpty) {
      orConditions.add('family_id.in.(${_cachedFamilyScopeIds!.join(',')})');
    }
    if (_cachedSubClanIds!.isNotEmpty) {
      orConditions.add('sub_clan_id.in.(${_cachedSubClanIds!.join(',')})');
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

  Future<List<Map<String, dynamic>>> _fetchPagedRows(
    dynamic query, {
    int page = 0,
    int pageSize = 0,
  }) async {
    if (pageSize > 0) {
      final offset = page * pageSize;
      final response = await query
          .order('voter_symbol', ascending: true)
          .range(offset, offset + pageSize - 1);
      return (response as List).cast<Map<String, dynamic>>();
    }

    final allRows = <Map<String, dynamic>>[];
    const chunkSize = 1000;
    int offset = 0;

    while (true) {
      final response = await query
          .order('voter_symbol', ascending: true)
          .range(offset, offset + chunkSize - 1);
      if (response.isEmpty) break;
      allRows.addAll((response as List).cast<Map<String, dynamic>>());
      if (response.length < chunkSize) break;
      offset += chunkSize;
    }

    return allRows;
  }

  /// Get paginated voters with optional filters.
  Future<List<VoterModel>> getVoters(VoterFilter filter) async {
    try {
      final queryText = _sanitizeSearchQuery(filter.searchQuery ?? '');
      final resultsBySymbol = <String, Map<String, dynamic>>{};

      if (queryText.isEmpty) {
        await _ensurePermissionsLoaded();
        var query = _client.from('voters').select(_selectWithJoins);
        query = _applyAgentPermissionsFilter(query);
        query = _applyFilterConstraints(query, filter);
        final allVoters = await _fetchPagedRows(
          query,
          page: filter.page,
          pageSize: filter.pageSize,
        );

        print(
          'DEBUG: getVoters returned ${allVoters.length} records (with filters)',
        );

        return allVoters.map(VoterModel.fromJson).toList();
      }

      final escapedQuery = _escapeOrValue(queryText);

      await _ensurePermissionsLoaded();
      var byNameOrSymbolQuery = _client.from('voters').select(_selectWithJoins);
      byNameOrSymbolQuery = _applyAgentPermissionsFilter(byNameOrSymbolQuery);
      byNameOrSymbolQuery = _applyFilterConstraints(
        byNameOrSymbolQuery,
        filter,
      );
      byNameOrSymbolQuery = byNameOrSymbolQuery.or(
        'voter_symbol.ilike.%$escapedQuery%,first_name.ilike.%$escapedQuery%,father_name.ilike.%$escapedQuery%,grandfather_name.ilike.%$escapedQuery%',
      );
      final byNameOrSymbolRows = await _fetchPagedRows(byNameOrSymbolQuery);
      for (final row in byNameOrSymbolRows) {
        final symbol = row['voter_symbol'] as String;
        resultsBySymbol[symbol] = row;
      }

      final familyData = await _client
          .from('families')
          .select('id')
          .ilike('family_name', '%$queryText%');
      final familyIds = (familyData as List)
          .map((f) => f['id'] as int)
          .toList();

      if (familyIds.isNotEmpty) {
        var byFamilyQuery = _client.from('voters').select(_selectWithJoins);
        byFamilyQuery = _applyAgentPermissionsFilter(byFamilyQuery);
        byFamilyQuery = _applyFilterConstraints(byFamilyQuery, filter);
        byFamilyQuery = byFamilyQuery.inFilter('family_id', familyIds);
        final byFamilyRows = await _fetchPagedRows(byFamilyQuery);
        for (final row in byFamilyRows) {
          final symbol = row['voter_symbol'] as String;
          resultsBySymbol[symbol] = row;
        }
      }

      final subClanData = await _client
          .from('sub_clans')
          .select('id')
          .ilike('sub_name', '%$queryText%');
      final subClanIds = (subClanData as List)
          .map((s) => s['id'] as int)
          .toList();

      if (subClanIds.isNotEmpty) {
        var bySubClanQuery = _client.from('voters').select(_selectWithJoins);
        bySubClanQuery = _applyAgentPermissionsFilter(bySubClanQuery);
        bySubClanQuery = _applyFilterConstraints(bySubClanQuery, filter);
        bySubClanQuery = bySubClanQuery.inFilter('sub_clan_id', subClanIds);
        final bySubClanRows = await _fetchPagedRows(bySubClanQuery);
        for (final row in bySubClanRows) {
          final symbol = row['voter_symbol'] as String;
          resultsBySymbol[symbol] = row;
        }
      }

      final allVoters = resultsBySymbol.values.toList()
        ..sort(
          (a, b) => (a['voter_symbol'] as String).compareTo(
            b['voter_symbol'] as String,
          ),
        );

      print(
        'DEBUG: getVoters returned ${allVoters.length} records (with filters)',
      );

      return allVoters.map(VoterModel.fromJson).toList();
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
        ..sort(
          (a, b) => (a['voter_symbol'] as String).compareTo(
            b['voter_symbol'] as String,
          ),
        );

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

      if (responseList == null || (responseList as List).isEmpty) {
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
      var query = _client.from('voters').select('status');
      query = _applyAgentPermissionsFilter(query);

      if (familyId != null) query = query.eq('family_id', familyId);
      if (subClanId != null) query = query.eq('sub_clan_id', subClanId);
      if (centerId != null) query = query.eq('center_id', centerId);

      final data = await query;
      final list = data as List;

      final total = list.length;
      final voted = list
          .where((r) => r['status'] == AppConstants.statusVoted)
          .length;
      final refused = list
          .where((r) => r['status'] == AppConstants.statusRefused)
          .length;
      final notVoted = total - voted - refused;

      return VoterStats(
        total: total,
        voted: voted,
        refused: refused,
        notVoted: notVoted,
        votedPercentage: total > 0 ? (voted / total) * 100 : 0,
      );
    } catch (e) {
      throw ServerException(message: 'خطأ في جلب الإحصائيات: $e');
    }
  }

  /// Create a new voter.
  Future<VoterModel> createVoter(VoterModel voter) async {
    try {
      final data = await _client
          .from('voters')
          .insert(voter.toJson())
          .select(_selectWithJoins)
          .single();
      return VoterModel.fromJson(data);
    } catch (e) {
      throw ServerException(message: 'خطأ في إضافة الناخب: $e');
    }
  }

  /// Update an existing voter.
  Future<VoterModel> updateVoter(VoterModel voter) async {
    try {
      final data = await _client
          .from('voters')
          .update(voter.toJson())
          .eq('voter_symbol', voter.voterSymbol)
          .select(_selectWithJoins)
          .single();
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

  /// Bulk insert voters (for Excel import).
  Future<void> bulkInsertVoters(List<VoterModel> voters) async {
    try {
      final jsonList = voters.map((v) => v.toJson()).toList();

      // Chunking to avoid Supabase/PostgREST payload limits
      const chunkSize = 1000;
      for (var i = 0; i < jsonList.length; i += chunkSize) {
        final end = (i + chunkSize < jsonList.length)
            ? i + chunkSize
            : jsonList.length;
        final chunk = jsonList.sublist(i, end);
        await _client.from('voters').upsert(chunk, onConflict: 'voter_symbol');
      }
    } catch (e) {
      throw ServerException(message: 'خطأ في الاستيراد الجماعي: $e');
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
    int offset = 0;

    await _ensurePermissionsLoaded();
    var baseQuery = _client.from('voters').select(_selectWithJoins);
    baseQuery = _applyAgentPermissionsFilter(baseQuery);
    debugPrint('[SupabaseVoterDatasource] getAllVoters start');

    while (true) {
      final response = await baseQuery
          .order('voter_symbol', ascending: true)
          .range(offset, offset + pageSize - 1);

      if (response.isEmpty) break;
      allVoters.addAll((response as List).cast<Map<String, dynamic>>());
      if (response.length < pageSize) break;
      offset += pageSize;
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

    final response = await query.order('voter_symbol', ascending: true);

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

    return (response as List).map((row) => row['candidate_id'] as int).toList();
  }

  Future<Map<String, Map<int, int>>> getListAndCandidateVotes() async {
    try {
      await _ensurePermissionsLoaded();
      var votersQuery = _client
          .from('voters')
          .select('list_id')
          .eq('status', AppConstants.statusVoted)
          .not('list_id', 'is', null);
      votersQuery = _applyAgentPermissionsFilter(votersQuery);

      final listData = await votersQuery;
      final Map<int, int> listVotes = {};

      for (final row in listData as List) {
        final listId = row['list_id'] as int;
        listVotes[listId] = (listVotes[listId] ?? 0) + 1;
      }

      // Use filtered query for candidate votes
      var candidatesQuery = _client
          .from('voter_candidates')
          .select('candidate_id');
      final candidatesData = await candidatesQuery;
      final Map<int, int> candidateVotes = {};

      for (final row in candidatesData as List) {
        final candidateId = row['candidate_id'] as int;
        candidateVotes[candidateId] = (candidateVotes[candidateId] ?? 0) + 1;
      }

      return {'listVotes': listVotes, 'candidateVotes': candidateVotes};
    } catch (e) {
      throw ServerException(
        message: 'خطأ في جلب إحصائيات القوائم والمرشحين: $e',
      );
    }
  }
}
