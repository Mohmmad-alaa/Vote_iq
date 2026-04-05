import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/candidate.dart';
import '../entities/electoral_list.dart';
import '../entities/family.dart';
import '../entities/sub_clan.dart';
import '../entities/voting_center.dart';

/// Lookup data repository contract (families, sub-clans, voting centers).
abstract class LookupRepository {
  /// Get all families.
  Future<Either<Failure, List<Family>>> getFamilies();

  /// Get sub-clans, optionally filtered by family.
  Future<Either<Failure, List<SubClan>>> getSubClans({int? familyId});

  /// Get all voting centers.
  Future<Either<Failure, List<VotingCenter>>> getVotingCenters();

  /// Get all electoral lists.
  Future<Either<Failure, List<ElectoralList>>> getLists();

  /// Get candidates, optionally filtered by list.
  Future<Either<Failure, List<Candidate>>> getCandidates({int? listId});

  // --- Management ---
  Future<Either<Failure, Family>> addFamily(String name);
  Future<Either<Failure, void>> deleteFamily(int id);

  Future<Either<Failure, SubClan>> addSubClan(int familyId, String name);
  Future<Either<Failure, void>> deleteSubClan(int id);

  Future<Either<Failure, VotingCenter>> addVotingCenter(String name);
  Future<Either<Failure, void>> deleteVotingCenter(int id);

  Future<Either<Failure, ElectoralList>> addElectoralList(String name);
  Future<Either<Failure, void>> deleteElectoralList(int id);

  Future<Either<Failure, Candidate>> addCandidate(
    String name, {
    int? listId,
  });
  Future<Either<Failure, void>> deleteCandidate(int id);

  /// Import Electoral Lists and Candidates from Excel
  Future<Either<Failure, int>> importListsAndCandidates(String filePath);
}
