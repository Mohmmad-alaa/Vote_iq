import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/connectivity_helper.dart';
import '../../../domain/entities/candidate.dart';
import '../../../domain/entities/electoral_list.dart';
import '../../../domain/entities/family.dart';
import '../../../domain/entities/sub_clan.dart';
import '../../../domain/entities/voting_center.dart';
import '../../../domain/repositories/lookup_repository.dart';
import '../datasources/local/local_lookup_datasource.dart';
import '../datasources/remote/supabase_lookup_datasource.dart';
import '../services/list_candidate_import_service.dart';

/// Lookup repository implementation - online-first with local cache fallback.
class LookupRepositoryImpl implements LookupRepository {
  final SupabaseLookupDatasource _remoteDatasource;
  final LocalLookupDatasource _localDatasource;
  final ConnectivityHelper _connectivity;
  final ListCandidateImportService _importService;

  LookupRepositoryImpl({
    required SupabaseLookupDatasource remoteDatasource,
    required LocalLookupDatasource localDatasource,
    required ConnectivityHelper connectivity,
    required ListCandidateImportService importService,
  })  : _remoteDatasource = remoteDatasource,
        _localDatasource = localDatasource,
        _connectivity = connectivity,
        _importService = importService;

  @override
  Future<void> clearCache() {
    return _localDatasource.clearCache();
  }

  @override
  Future<Either<Failure, List<Family>>> getFamilies() async {
    try {
      if (await _connectivity.hasInternet) {
        final models = await _remoteDatasource.getFamilies();
        _localDatasource.cacheFamilies(models).catchError((e) {
          debugPrint('LookupRepository: cache families error: $e');
        });
        return Right(models.map((m) => m.toEntity()).toList());
      }

      final models = await _localDatasource.getCachedFamilies();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      try {
        final models = await _localDatasource.getCachedFamilies();
        return Right(models.map((m) => m.toEntity()).toList());
      } catch (_) {
        return Left(ServerFailure(message: e.message));
      }
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في جلب العائلات: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SubClan>>> getSubClans({int? familyId}) async {
    try {
      if (await _connectivity.hasInternet) {
        final models = await _remoteDatasource.getSubClans(familyId: familyId);
        _localDatasource.cacheSubClans(models).catchError((e) {
          debugPrint('LookupRepository: cache sub-clans error: $e');
        });
        return Right(models.map((m) => m.toEntity()).toList());
      }

      final models = await _localDatasource.getCachedSubClans(familyId: familyId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      try {
        final models = await _localDatasource.getCachedSubClans(familyId: familyId);
        return Right(models.map((m) => m.toEntity()).toList());
      } catch (_) {
        return Left(ServerFailure(message: e.message));
      }
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في جلب الفروع: $e'));
    }
  }

  @override
  Future<Either<Failure, List<VotingCenter>>> getVotingCenters() async {
    try {
      if (await _connectivity.hasInternet) {
        final models = await _remoteDatasource.getVotingCenters();
        _localDatasource.cacheVotingCenters(models).catchError((e) {
          debugPrint('LookupRepository: cache centers error: $e');
        });
        return Right(models.map((m) => m.toEntity()).toList());
      }

      final models = await _localDatasource.getCachedVotingCenters();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      try {
        final models = await _localDatasource.getCachedVotingCenters();
        return Right(models.map((m) => m.toEntity()).toList());
      } catch (_) {
        return Left(ServerFailure(message: e.message));
      }
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في جلب المراكز: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ElectoralList>>> getLists() async {
    try {
      if (await _connectivity.hasInternet) {
        final models = await _remoteDatasource.getLists();
        _localDatasource.cacheElectoralLists(models).catchError((e) {
          debugPrint('LookupRepository: cache electoral lists error: $e');
        });
        return Right(models.map((m) => m.toEntity()).toList());
      }

      final models = await _localDatasource.getCachedElectoralLists();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      try {
        final models = await _localDatasource.getCachedElectoralLists();
        return Right(models.map((m) => m.toEntity()).toList());
      } catch (_) {
        return Left(ServerFailure(message: e.message));
      }
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في جلب القوائم الانتخابية: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Candidate>>> getCandidates({int? listId}) async {
    try {
      if (await _connectivity.hasInternet) {
        final models = await _remoteDatasource.getCandidates(listId: listId);
        if (listId == null) {
          _localDatasource.cacheCandidates(models).catchError((e) {
            debugPrint('LookupRepository: cache candidates error: $e');
          });
        }
        return Right(models.map((m) => m.toEntity()).toList());
      }

      final models = await _localDatasource.getCachedCandidates(listId: listId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      try {
        final models = await _localDatasource.getCachedCandidates(listId: listId);
        return Right(models.map((m) => m.toEntity()).toList());
      } catch (_) {
        return Left(ServerFailure(message: e.message));
      }
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في جلب المرشحين: $e'));
    }
  }

  @override
  Future<Either<Failure, Family>> addFamily(String name) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالًا بالإنترنت'),
        );
      }
      final model = await _remoteDatasource.addFamily(name);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteFamily(int id) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالًا بالإنترنت'),
        );
      }
      await _remoteDatasource.deleteFamily(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, SubClan>> addSubClan(int familyId, String name) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالًا بالإنترنت'),
        );
      }
      final model = await _remoteDatasource.addSubClan(familyId, name);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSubClan(int id) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالًا بالإنترنت'),
        );
      }
      await _remoteDatasource.deleteSubClan(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, VotingCenter>> addVotingCenter(String name) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالًا بالإنترنت'),
        );
      }
      final model = await _remoteDatasource.addVotingCenter(name);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteVotingCenter(int id) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالًا بالإنترنت'),
        );
      }
      await _remoteDatasource.deleteVotingCenter(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, ElectoralList>> addElectoralList(String name) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالًا بالإنترنت'),
        );
      }
      final model = await _remoteDatasource.addElectoralList(name);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteElectoralList(int id) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالًا بالإنترنت'),
        );
      }
      await _remoteDatasource.deleteElectoralList(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, Candidate>> addCandidate(
    String name, {
    int? listId,
  }) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالًا بالإنترنت'),
        );
      }
      final model = await _remoteDatasource.addCandidate(name, listId: listId);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCandidate(int id) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالًا بالإنترنت'),
        );
      }
      await _remoteDatasource.deleteCandidate(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> importListsAndCandidates(String filePath) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالًا بالإنترنت'),
        );
      }

      final parsedData = await _importService.parseExcel(filePath);
      if (parsedData.isEmpty) {
        return const Left(
          ServerFailure(message: 'لم يتم العثور على بيانات صالحة في الملف'),
        );
      }

      // 1. Get existing lists
      final existingLists = await _remoteDatasource.getLists();
      final listMap = {for (var l in existingLists) l.listName.trim(): l.id};

      int candidatesAdded = 0;

      // 2. Process data
      for (final item in parsedData) {
        final listName = item.listName.trim();
        final candidateName = item.candidateName.trim();

        // Get or create list
        int? listId = listMap[listName];
        if (listId == null) {
          final newList = await _remoteDatasource.addElectoralList(listName);
          listId = newList.id;
          listMap[listName] = listId;
        }

        // Add candidate
        try {
          await _remoteDatasource.addCandidate(
            candidateName,
            listId: listId,
          );
          candidatesAdded++;
        } catch (e) {
          // Ignore duplicate candidate errors, continue to next
          debugPrint('Failed to add candidate $candidateName: $e');
        }
      }

      return Right(candidatesAdded);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع أثناء الاستيراد: $e'));
    }
  }
}
