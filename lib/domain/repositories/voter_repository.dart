import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/voter.dart';

/// Voter statistics data.
class VoterStats {
  final int total;
  final int voted;
  final int refused;
  final int notVoted;
  final int notFound;
  final double votedPercentage;

  const VoterStats({
    required this.total,
    required this.voted,
    required this.refused,
    required this.notVoted,
    required this.notFound,
    required this.votedPercentage,
  });
}

/// Filter parameters for voter queries.
class VoterFilter {
  final List<int>? familyIds;
  final int? subClanId;
  final int? centerId;
  final String? status;
  final String? searchQuery;
  final bool includeManageableUnassigned;
  final int page;
  final int pageSize;

  const VoterFilter({
    this.familyIds,
    this.subClanId,
    this.centerId,
    this.status,
    this.searchQuery,
    this.includeManageableUnassigned = false,
    this.page = 0,
    this.pageSize = 50,
  });

  VoterFilter copyWith({
    List<int>? familyIds,
    int? subClanId,
    int? centerId,
    String? status,
    String? searchQuery,
    bool? includeManageableUnassigned,
    int? page,
    int? pageSize,
  }) {
    return VoterFilter(
      familyIds: familyIds ?? this.familyIds,
      subClanId: subClanId ?? this.subClanId,
      centerId: centerId ?? this.centerId,
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
      includeManageableUnassigned:
          includeManageableUnassigned ?? this.includeManageableUnassigned,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

/// Voter repository contract.
abstract class VoterRepository {
  /// Get paginated voters with optional filters.
  /// [forceRefresh] forces a full reload from server
  Future<Either<Failure, List<Voter>>> getVoters(
    VoterFilter filter, {
    bool forceRefresh = false,
  });

  /// Get the total number of voters matching the current filters.
  Future<Either<Failure, int>> countVoters(VoterFilter filter);

  /// Search voters by name (uses pg_trgm similarity search).
  Future<Either<Failure, List<Voter>>> searchVoters(String query);

  /// Update a voter's status.
  Future<Either<Failure, Voter>> updateVoterStatus({
    required String voterSymbol,
    required String newStatus,
    String? refusalReason,
    int? listId,
    int? candidateId,
  });

  /// Get voting statistics (total, voted, refused, not voted).
  Future<Either<Failure, VoterStats>> getVoterStats({
    int? familyId,
    int? subClanId,
    int? centerId,
  });

  Future<Either<Failure, Map<int, VoterStats>>> getFamilyStatsBatch(
    List<int> familyIds,
  );

  Future<Either<Failure, Map<int, VoterStats>>> getSubClanStatsBatch(
    List<int> subClanIds,
  );

  /// Create a new voter record.
  Future<Either<Failure, Voter>> createVoter(Voter voter);

  /// Update an existing voter's details.
  Future<Either<Failure, Voter>> updateVoter(Voter voter);

  /// Delete a voter record.
  Future<Either<Failure, void>> deleteVoter(String voterSymbol);

  /// Import voters from an Excel file.
  Future<Either<Failure, int>> importVoters(String filePath);

  /// Safely update household fields only for existing voters from Excel.
  Future<Either<Failure, int>> importVoterHouseholdData(String filePath);

  /// Safely update family and sub-clan fields only for existing voters from Excel.
  Future<Either<Failure, int>> importVoterSubClans(String filePath);

  /// Get all unique family names (for filter dropdown).
  Future<Either<Failure, List<String>>> getAllUniqueFamilies();

  /// Get all family name to ID mapping (for server-side filtering).
  Future<Either<Failure, Map<String, int>>> getFamiliesMap();

  /// Subscribe to real-time voter changes.
  Stream<Voter> get voterChanges;

  /// Dispose real-time subscription.
  void disposeRealtime();

  /// Save voter candidates (up to 5) for a given voter.
  Future<Either<Failure, void>> saveVoterCandidates({
    required String voterSymbol,
    required List<int> candidateIds,
  });

  /// Get candidate IDs voted for by a specific voter
  Future<Either<Failure, List<int>>> getVoterCandidates(String voterSymbol);

  /// Get total votes for lists and candidates
  Future<Either<Failure, Map<String, Map<int, int>>>> getListAndCandidateVotes();

  /// Emits an event when background full data sync completes.
  Stream<void> get onFullSyncComplete;

  /// Clears the local cache when signing out or switching users.
  Future<void> clearCache();

  /// Reset all voters to default state (not voted, no list/candidate).
  Future<Either<Failure, void>> resetAllVoters();
}
