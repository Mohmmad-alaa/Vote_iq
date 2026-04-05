import 'package:equatable/equatable.dart';

import '../../../data/sync/sync_manager.dart';

/// Sync indicator states.
abstract class SyncState extends Equatable {
  const SyncState();

  @override
  List<Object?> get props => [];
}

class SyncIdle extends SyncState {
  final SyncStatus status;
  final int pendingCount;

  const SyncIdle({
    this.status = SyncStatus.synced,
    this.pendingCount = 0,
  });

  @override
  List<Object?> get props => [status, pendingCount];
}
