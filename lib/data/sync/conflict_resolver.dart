import '../../../core/errors/exceptions.dart';
import '../models/voter_model.dart';
import '../datasources/remote/supabase_voter_datasource.dart';

/// Resolves conflicts between offline local changes and server data.
///
/// Strategy: Last-Write-Wins based on `updated_at` timestamp.
class ConflictResolver {
  final SupabaseVoterDatasource _remoteDatasource;

  ConflictResolver(this._remoteDatasource);

  /// Check if a local change should be applied to the server.
  ///
  /// Returns `true` if the local change is newer than the server version.
  Future<bool> shouldApplyLocalChange({
    required String voterSymbol,
    required DateTime localUpdatedAt,
  }) async {
    try {
      final voters = await _remoteDatasource.searchVoters(voterSymbol);

      if (voters.isEmpty) {
        return true;
      }

      final serverVoter = voters.first;
      if (serverVoter.updatedAt == null) return true;

      return localUpdatedAt.isAfter(serverVoter.updatedAt!);
    } catch (e) {
      throw ServerException(message: 'خطأ في فحص التعارض: $e');
    }
  }

  /// Get the server version of a voter for comparison.
  Future<VoterModel?> getServerVersion(String voterSymbol) async {
    try {
      final voters = await _remoteDatasource.searchVoters(voterSymbol);
      return voters.isNotEmpty ? voters.first : null;
    } catch (e) {
      return null;
    }
  }
}
