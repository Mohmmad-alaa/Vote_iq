import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/lookup_repository.dart';

class ImportListsCandidatesUseCase {
  final LookupRepository repository;

  ImportListsCandidatesUseCase(this.repository);

  Future<Either<Failure, int>> call(String filePath) async {
    return await repository.importListsAndCandidates(filePath);
  }
}
