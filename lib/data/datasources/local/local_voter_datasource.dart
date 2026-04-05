import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/voter_model.dart';

/// Local datasource for voter data using Hive (offline cache).
class LocalVoterDatasource {
  Box? _votersBox;
  Map<String, Map<String, dynamic>>? _cachedRawBySymbol;

  Future<Box> get _box async {
    _votersBox ??= await Hive.openBox(AppConstants.hiveVotersBox);
    return _votersBox!;
  }

  Future<Map<String, Map<String, dynamic>>> _ensureMemoryCache() async {
    final cached = _cachedRawBySymbol;
    if (cached != null) {
      return cached;
    }

    final box = await _box;
    final loaded = <String, Map<String, dynamic>>{};

    for (final key in box.keys) {
      final value = box.get(key);
      if (value is Map) {
        // Use cast instead of Map.from to avoid deep-copying each voter's data
        loaded[key.toString()] = value.cast<String, dynamic>();
      }
    }

    _cachedRawBySymbol = loaded;
    return loaded;
  }

  /// Cache a list of voters locally.
  Future<void> cacheVoters(List<VoterModel> voters) async {
    try {
      final box = await _box;
      final cache = await _ensureMemoryCache();
      final batch = <String, Map<String, dynamic>>{};

      for (final voter in voters) {
        final hiveMap = voter.toHiveMap();
        batch[voter.voterSymbol] = hiveMap;
        cache[voter.voterSymbol] = hiveMap;
      }

      await box.putAll(batch);
    } catch (e) {
      throw CacheException(message: 'ط®ط·ط£ ظپظٹ ط­ظپط¸ ط§ظ„ط¨ظٹط§ظ†ط§طھ ط§ظ„ظ…ط­ظ„ظٹط©: $e');
    }
  }

  /// Get cached voters with optional filters.
  Future<List<VoterModel>> getCachedVoters({
    List<int>? familyIds,
    int? subClanId,
    int? centerId,
    String? status,
    String? searchQuery,
    int page = 0,
    int pageSize = 0,
  }) async {
    try {
      final cache = await _ensureMemoryCache();
      final params = _ProcessParams(
        rawValues: cache.values.toList(growable: false),
        familyIds: familyIds,
        subClanId: subClanId,
        centerId: centerId,
        status: status,
        searchQuery: searchQuery,
        page: page,
        pageSize: pageSize,
      );

      return compute(_processVotersInIsolate, params);
    } catch (e) {
      throw CacheException(message: 'ط®ط·ط£ ظپظٹ ظ‚ط±ط§ط،ط© ط§ظ„ط¨ظٹط§ظ†ط§طھ ط§ظ„ظ…ط­ظ„ظٹط©: $e');
    }
  }

  /// Update a single voter in the cache.
  Future<void> updateCachedVoter(VoterModel voter) async {
    try {
      final box = await _box;
      final hiveMap = voter.toHiveMap();
      await box.put(voter.voterSymbol, hiveMap);

      final cache = await _ensureMemoryCache();
      cache[voter.voterSymbol] = hiveMap;
    } catch (e) {
      throw CacheException(message: 'ط®ط·ط£ ظپظٹ طھط­ط¯ظٹط« ط§ظ„ط¨ظٹط§ظ†ط§طھ ط§ظ„ظ…ط­ظ„ظٹط©: $e');
    }
  }

  /// Get a single cached voter by symbol.
  Future<VoterModel?> getCachedVoter(String voterSymbol) async {
    try {
      final cache = await _ensureMemoryCache();
      final data = cache[voterSymbol];
      if (data == null) return null;
      return VoterModel.fromHiveMap(data);
    } catch (e) {
      return null;
    }
  }

  /// Get cached voter count for stats.
  Future<Map<String, int>> getCachedStats({
    int? familyId,
    int? subClanId,
    int? centerId,
  }) async {
    try {
      final cache = await _ensureMemoryCache();
      int total = 0, voted = 0, refused = 0, notVoted = 0;

      for (final voter in cache.values) {
        if (familyId != null && voter['family_id'] != familyId) continue;
        if (subClanId != null && voter['sub_clan_id'] != subClanId) continue;
        if (centerId != null && voter['center_id'] != centerId) continue;

        total++;
        switch (voter['status']) {
          case AppConstants.statusVoted:
            voted++;
            break;
          case AppConstants.statusRefused:
            refused++;
            break;
          default:
            notVoted++;
            break;
        }
      }

      return {
        'total': total,
        'voted': voted,
        'refused': refused,
        'notVoted': notVoted,
      };
    } catch (e) {
      throw CacheException(message: 'خطأ في حساب الإحصائيات المحلية: $e');
    }
  }

  Future<Map<int, Map<String, int>>> getGroupedCachedStats({
    required String groupField,
    List<int>? allowedIds,
  }) async {
    try {
      final cache = await _ensureMemoryCache();
      final allowed = allowedIds == null ? null : allowedIds.toSet();
      final grouped = <int, Map<String, int>>{};

      for (final voter in cache.values) {
        final rawGroupId = voter[groupField];
        if (rawGroupId is! int) continue;
        if (allowed != null && !allowed.contains(rawGroupId)) continue;

        final bucket = grouped.putIfAbsent(
          rawGroupId,
          () => {
            'total': 0,
            'voted': 0,
            'refused': 0,
            'notVoted': 0,
          },
        );

        bucket['total'] = (bucket['total'] ?? 0) + 1;

        switch (voter['status']) {
          case AppConstants.statusVoted:
            bucket['voted'] = (bucket['voted'] ?? 0) + 1;
            break;
          case AppConstants.statusRefused:
            bucket['refused'] = (bucket['refused'] ?? 0) + 1;
            break;
          default:
            bucket['notVoted'] = (bucket['notVoted'] ?? 0) + 1;
            break;
        }
      }

      return grouped;
    } catch (e) {
      throw CacheException(message: 'خطأ في تجميع الإحصائيات المحلية: $e');
    }
  }

  /// Get all unique family names from cache (for filter dropdown).
  Future<List<String>> getAllUniqueFamilies() async {
    try {
      final cache = await _ensureMemoryCache();
      final names = cache.values
          .map((v) => (v['family_name'] as String?)?.trim())
          .where((name) => name != null && name.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      names.sort();
      return names;
    } catch (e) {
      throw CacheException(message: 'ط®ط·ط£ ظپظٹ ظ‚ط±ط§ط،ط© ط£ط³ظ…ط§ط، ط§ظ„ط¹ط§ط¦ظ„ط§طھ: $e');
    }
  }

  /// Get all family name to ID mapping from cache.
  Future<Map<String, int>> getFamiliesMap() async {
    try {
      final cache = await _ensureMemoryCache();
      final map = <String, int>{};

      for (final voter in cache.values) {
        final familyName = (voter['family_name'] as String?)?.trim();
        final familyId = voter['family_id'] as int?;

        if (familyName != null && familyName.isNotEmpty && familyId != null) {
          map[familyName] = familyId;
        }
      }

      return map;
    } catch (e) {
      throw CacheException(message: 'ط®ط·ط£ ظپظٹ ظ‚ط±ط§ط،ط© ط®ط±ظٹط·ط© ط§ظ„ط¹ط§ط¦ظ„ط§طھ: $e');
    }
  }

  /// Clear all cached voters.
  Future<void> clearCache() async {
    final box = await _box;
    await box.clear();
    _cachedRawBySymbol = <String, Map<String, dynamic>>{};
  }

  /// Get total number of cached voters
  Future<int> getVotersCount() async {
    try {
      final cache = await _ensureMemoryCache();
      return cache.length;
    } catch (e) {
      return 0;
    }
  }
}

class _ProcessParams {
  final List<dynamic> rawValues;
  final List<int>? familyIds;
  final int? subClanId;
  final int? centerId;
  final String? status;
  final String? searchQuery;
  final int page;
  final int pageSize;

  _ProcessParams({
    required this.rawValues,
    this.familyIds,
    this.subClanId,
    this.centerId,
    this.status,
    this.searchQuery,
    required this.page,
    required this.pageSize,
  });
}

List<VoterModel> _processVotersInIsolate(_ProcessParams params) {
  var rows = params.rawValues
      .whereType<Map>()
      .map((v) => Map<String, dynamic>.from(v))
      .toList();

  if (params.familyIds != null && params.familyIds!.isNotEmpty) {
    rows = rows
        .where(
          (v) =>
              v['family_id'] != null &&
              params.familyIds!.contains(v['family_id']),
        )
        .toList();
  }
  if (params.subClanId != null) {
    rows = rows.where((v) => v['sub_clan_id'] == params.subClanId).toList();
  }
  if (params.centerId != null) {
    rows = rows.where((v) => v['center_id'] == params.centerId).toList();
  }
  if (params.status != null) {
    rows = rows.where((v) => v['status'] == params.status).toList();
  }
  if (params.searchQuery != null && params.searchQuery!.isNotEmpty) {
    final cleanQuery = params.searchQuery!
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '')
        .trim()
        .toLowerCase();

    if (cleanQuery.isNotEmpty) {
      final terms = cleanQuery
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList(growable: false);

      rows = rows.where((v) {
        final searchText =
            (v['search_blob'] as String? ?? _buildSearchBlob(v)).toLowerCase();
        return terms.every((term) => searchText.contains(term));
      }).toList();
    }
  }

  rows.sort(
    (a, b) => (a['voter_symbol'] as String).compareTo(
      b['voter_symbol'] as String,
    ),
  );

  if (params.pageSize <= 0) {
    return rows.map(VoterModel.fromHiveMap).toList(growable: false);
  }

  final startIndex = params.page * params.pageSize;
  if (startIndex >= rows.length) return [];

  return rows
      .skip(startIndex)
      .take(params.pageSize)
      .map(VoterModel.fromHiveMap)
      .toList(growable: false);
}

String _buildSearchBlob(Map<dynamic, dynamic> map) {
  return [
    map['voter_symbol'],
    map['first_name'],
    map['father_name'],
    map['grandfather_name'],
    map['family_name'],
    map['sub_clan_name'],
  ]
      .whereType<String>()
      .join(' ')
      .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '')
      .trim()
      .toLowerCase();
}
