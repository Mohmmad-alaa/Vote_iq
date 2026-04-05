import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/connectivity_helper.dart';
import '../datasources/remote/supabase_voter_datasource.dart';
import '../datasources/local/local_voter_datasource.dart';
import 'conflict_resolver.dart';
import 'sync_queue.dart';

/// Sync status for UI indicator.
enum SyncStatus { synced, syncing, offline, error }

/// Manages background synchronization of offline changes.
class SyncManager {
  final SyncQueue _syncQueue;
  final SupabaseVoterDatasource _remoteDatasource;
  final LocalVoterDatasource _localDatasource;
  final ConflictResolver _conflictResolver;
  final ConnectivityHelper _connectivity;

  StreamSubscription<bool>? _connectivitySubscription;
  final _statusController = StreamController<SyncStatus>.broadcast();
  final _pendingCountController = StreamController<int>.broadcast();

  SyncStatus _currentStatus = SyncStatus.synced;
  bool _isSyncing = false;

  SyncManager({
    required SyncQueue syncQueue,
    required SupabaseVoterDatasource remoteDatasource,
    required LocalVoterDatasource localDatasource,
    required ConflictResolver conflictResolver,
    required ConnectivityHelper connectivity,
  })  : _syncQueue = syncQueue,
        _remoteDatasource = remoteDatasource,
        _localDatasource = localDatasource,
        _conflictResolver = conflictResolver,
        _connectivity = connectivity;

  /// Stream of sync status changes.
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Stream of pending operation count changes.
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Current sync status.
  SyncStatus get currentStatus => _currentStatus;

  /// Start monitoring connectivity and auto-sync.
  void startMonitoring() {
    _connectivity.hasInternet.then((hasInternet) {
      debugPrint(
        'SyncManager: startMonitoring initial check hasInternet=$hasInternet',
      );
      if (hasInternet) {
        debugPrint('SyncManager: startMonitoring triggering initial sync');
        syncPendingOperations();
      } else {
        _updateStatus(SyncStatus.offline);
      }
    });

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (hasInternet) {
        debugPrint(
          'SyncManager: connectivity changed hasInternet=$hasInternet',
        );
        if (hasInternet) {
          syncPendingOperations();
        } else {
          _updateStatus(SyncStatus.offline);
        }
      },
    );
  }

  /// Sync all pending operations.
  Future<void> syncPendingOperations() async {
    if (_isSyncing) return;
    _isSyncing = true;

    final pendingOps = await _syncQueue.getPendingOperations();
    debugPrint(
      'SyncManager: syncPendingOperations start pendingCount=${pendingOps.length}',
    );
    if (pendingOps.isEmpty) {
      _updateStatus(SyncStatus.synced);
      _isSyncing = false;
      return;
    }

    _updateStatus(SyncStatus.syncing);

    int successCount = 0;
    for (final op in pendingOps) {
      try {
        // Check if local change should override server
        final shouldApply = await _conflictResolver.shouldApplyLocalChange(
          voterSymbol: op.voterSymbol,
          localUpdatedAt: op.timestamp,
        );

        if (shouldApply) {
          // Apply the change to the server
          final updated = await _remoteDatasource.updateVoterStatus(
            voterSymbol: op.voterSymbol,
            newStatus: op.newStatus,
            refusalReason: op.refusalReason,
            listId: op.listId,
            candidateId: op.candidateId,
            agentId: op.agentId,
          );
          // Update local cache with server response
          await _localDatasource.updateCachedVoter(updated);
        } else {
          // Server has a newer version — update local cache
          final serverVersion =
              await _conflictResolver.getServerVersion(op.voterSymbol);
          if (serverVersion != null) {
            await _localDatasource.updateCachedVoter(serverVersion);
          }
        }

        debugPrint(
          'SyncManager: synced pending voter ${op.voterSymbol} with status ${op.newStatus}',
        );
        // Remove from queue
        await _syncQueue.dequeue(op.id);
        successCount++;
        _pendingCountController.add(pendingOps.length - successCount);
      } catch (e) {
        debugPrint('SyncManager: Failed to sync ${op.voterSymbol}: $e');
        // Keep in queue for retry
      }
    }

    final remaining = await _syncQueue.pendingCount;
    debugPrint(
      'SyncManager: syncPendingOperations finished remaining=$remaining',
    );
    if (remaining == 0) {
      _updateStatus(SyncStatus.synced);
    } else {
      _updateStatus(SyncStatus.error);
    }

    _isSyncing = false;
  }

  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  /// Dispose resources.
  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
    _pendingCountController.close();
  }
}
