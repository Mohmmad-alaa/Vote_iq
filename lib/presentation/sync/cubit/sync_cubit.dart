import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/sync/sync_manager.dart';
import '../../../data/sync/sync_queue.dart';
import 'sync_state.dart';

/// Sync cubit — tracks sync status and pending operation count.
class SyncCubit extends Cubit<SyncState> {
  final SyncManager _syncManager;
  final SyncQueue _syncQueue;

  StreamSubscription? _statusSub;
  StreamSubscription? _countSub;

  SyncCubit({
    required SyncManager syncManager,
    required SyncQueue syncQueue,
  })  : _syncManager = syncManager,
        _syncQueue = syncQueue,
        super(const SyncIdle());

  /// Start monitoring sync state.
  void startMonitoring() {
    _syncManager.startMonitoring();

    _statusSub = _syncManager.statusStream.listen((status) async {
      final count = await _syncQueue.pendingCount;
      emit(SyncIdle(status: status, pendingCount: count));
    });

    _countSub = _syncManager.pendingCountStream.listen((count) {
      final currentState = state;
      if (currentState is SyncIdle) {
        emit(SyncIdle(status: currentState.status, pendingCount: count));
      }
    });
  }

  /// Manual sync trigger.
  Future<void> triggerSync() async {
    await _syncManager.syncPendingOperations();
  }

  @override
  Future<void> close() {
    _statusSub?.cancel();
    _countSub?.cancel();
    _syncManager.dispose();
    return super.close();
  }
}
