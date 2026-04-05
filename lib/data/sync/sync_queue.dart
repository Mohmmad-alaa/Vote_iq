import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_constants.dart';

/// Represents a pending sync operation queued while offline.
class SyncOperation {
  final String id;
  final String voterSymbol;
  final String newStatus;
  final String? refusalReason;
  final int? listId;
  final int? candidateId;
  final String agentId;
  final DateTime timestamp;

  SyncOperation({
    required this.id,
    required this.voterSymbol,
    required this.newStatus,
    this.refusalReason,
    this.listId,
    this.candidateId,
    required this.agentId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'voter_symbol': voterSymbol,
        'new_status': newStatus,
        'refusal_reason': refusalReason,
        'list_id': listId,
        'candidate_id': candidateId,
        'agent_id': agentId,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SyncOperation.fromMap(Map<dynamic, dynamic> map) {
    return SyncOperation(
      id: map['id'] as String,
      voterSymbol: map['voter_symbol'] as String,
      newStatus: map['new_status'] as String,
      refusalReason: map['refusal_reason'] as String?,
      listId: map['list_id'] as int?,
      candidateId: map['candidate_id'] as int?,
      agentId: map['agent_id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}

/// Queue for storing pending sync operations in Hive.
class SyncQueue {
  Box? _box;

  Future<Box> get box async {
    _box ??= await Hive.openBox(AppConstants.hiveSyncQueueBox);
    return _box!;
  }

  /// Add an operation to the queue.
  Future<void> enqueue(SyncOperation operation) async {
    final b = await box;
    await b.put(operation.id, operation.toMap());
  }

  /// Get all pending operations, sorted by timestamp.
  Future<List<SyncOperation>> getPendingOperations() async {
    final b = await box;
    final operations = b.values
        .map((v) => SyncOperation.fromMap(v as Map<dynamic, dynamic>))
        .toList();
    operations.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return operations;
  }

  /// Remove an operation after successful sync.
  Future<void> dequeue(String operationId) async {
    final b = await box;
    await b.delete(operationId);
  }

  /// Get count of pending operations.
  Future<int> get pendingCount async {
    final b = await box;
    return b.length;
  }

  /// Clear all pending operations.
  Future<void> clear() async {
    final b = await box;
    await b.clear();
  }
}
