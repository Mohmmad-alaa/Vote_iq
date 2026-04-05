import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/voter.dart';

/// Voter statistics data.
class VoterStats {
  final int total;
  final int voted;
  final int refused;
  final int notVoted;
  final double votedPercentage;

  const VoterStats({
    required this.total,
    required this.voted,
    required this.refused,
    required this.notVoted,
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
  final int page;
  final int pageSize;

  const VoterFilter({
    this.familyIds,
    this.subClanId,
    this.centerId,
    this.status,
    this.searchQuery,
    this.page = 0,
    this.pageSize = 50,
  });

  VoterFilter copyWith({
    List<int>? familyIds,
    int? subClanId,
    int? centerId,
    String? status,
    String? searchQuery,
    int? page,
    int? pageSize,
  }) {
    return VoterFilter(
      familyIds: familyIds ?? this.familyIds,
      subClanId: subClanId ?? this.subClanId,
      centerId: centerId ?? this.centerId,
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
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
}
