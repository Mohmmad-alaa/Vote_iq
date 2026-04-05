import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/candidate_model.dart';
import '../../models/electoral_list_model.dart';
import '../../models/family_model.dart';
import '../../models/sub_clan_model.dart';
import '../../models/voting_center_model.dart';

/// Local datasource for lookup data using Hive (offline cache).
class LocalLookupDatasource {
  Box? _lookupBox;

  Future<Box> get _box async {
    _lookupBox ??= await Hive.openBox(AppConstants.hiveLookupBox);
    return _lookupBox!;
  }

  // ── Families ──

  Future<void> cacheFamilies(List<FamilyModel> families) async {
    try {
      final box = await _box;
      await box.put(
        'families',
        families.map((f) => f.toHiveMap()).toList(),
      );
    } catch (e) {
      throw CacheException(message: 'خطأ في حفظ بيانات العائلات: $e');
    }
  }

  Future<List<FamilyModel>> getCachedFamilies() async {
    try {
      final box = await _box;
      final data = box.get('families');
      if (data == null) return [];
      return (data as List)
          .map((m) => FamilyModel.fromHiveMap(m as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      throw CacheException(message: 'خطأ في قراءة بيانات العائلات: $e');
    }
  }

  // ── Sub-clans ──

  Future<void> cacheSubClans(List<SubClanModel> subClans) async {
    try {
      final box = await _box;
      await box.put(
        'sub_clans',
        subClans.map((s) => s.toHiveMap()).toList(),
      );
    } catch (e) {
      throw CacheException(message: 'خطأ في حفظ بيانات الفروع: $e');
    }
  }

  Future<List<SubClanModel>> getCachedSubClans({int? familyId}) async {
    try {
      final box = await _box;
      final data = box.get('sub_clans');
      if (data == null) return [];
      var subClans = (data as List)
          .map((m) => SubClanModel.fromHiveMap(m as Map<dynamic, dynamic>))
          .toList();

      if (familyId != null) {
        subClans = subClans.where((s) => s.familyId == familyId).toList();
      }

      return subClans;
    } catch (e) {
      throw CacheException(message: 'خطأ في قراءة بيانات الفروع: $e');
    }
  }

  // ── Voting Centers ──

  Future<void> cacheVotingCenters(List<VotingCenterModel> centers) async {
    try {
      final box = await _box;
      await box.put(
        'voting_centers',
        centers.map((c) => c.toHiveMap()).toList(),
      );
    } catch (e) {
      throw CacheException(message: 'خطأ في حفظ بيانات المراكز: $e');
    }
  }

  Future<List<VotingCenterModel>> getCachedVotingCenters() async {
    try {
      final box = await _box;
      final data = box.get('voting_centers');
      if (data == null) return [];
      return (data as List)
          .map(
              (m) => VotingCenterModel.fromHiveMap(m as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      throw CacheException(message: 'خطأ في قراءة بيانات المراكز: $e');
    }
  }

  // —— Electoral Lists ——

  Future<void> cacheElectoralLists(List<ElectoralListModel> lists) async {
    try {
      final box = await _box;
      await box.put(
        'electoral_lists',
        lists.map((item) => item.toHiveMap()).toList(),
      );
    } catch (e) {
      throw CacheException(message: 'خطأ في حفظ بيانات القوائم الانتخابية: $e');
    }
  }

  Future<List<ElectoralListModel>> getCachedElectoralLists() async {
    try {
      final box = await _box;
      final data = box.get('electoral_lists');
      if (data == null) return [];
      return (data as List)
          .map(
            (m) => ElectoralListModel.fromHiveMap(m as Map<dynamic, dynamic>),
          )
          .toList();
    } catch (e) {
      throw CacheException(
        message: 'خطأ في قراءة بيانات القوائم الانتخابية: $e',
      );
    }
  }

  // —— Candidates ——

  Future<void> cacheCandidates(List<CandidateModel> candidates) async {
    try {
      final box = await _box;
      await box.put(
        'candidates',
        candidates.map((item) => item.toHiveMap()).toList(),
      );
    } catch (e) {
      throw CacheException(message: 'خطأ في حفظ بيانات المرشحين: $e');
    }
  }

  Future<List<CandidateModel>> getCachedCandidates({int? listId}) async {
    try {
      final box = await _box;
      final data = box.get('candidates');
      if (data == null) return [];

      var candidates = (data as List)
          .map((m) => CandidateModel.fromHiveMap(m as Map<dynamic, dynamic>))
          .toList();

      if (listId != null) {
        candidates = candidates.where((c) => c.listId == listId).toList();
      }

      return candidates;
    } catch (e) {
      throw CacheException(message: 'خطأ في قراءة بيانات المرشحين: $e');
    }
  }

  /// Clear all lookup cache.
  Future<void> clearCache() async {
    final box = await _box;
    await box.clear();
  }
}
