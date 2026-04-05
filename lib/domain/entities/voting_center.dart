import 'package:equatable/equatable.dart';

/// Voting center entity (e.g., مركز الشهداء).
class VotingCenter extends Equatable {
  final int id;
  final String centerName;
  final DateTime? createdAt;

  const VotingCenter({
    required this.id,
    required this.centerName,
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, centerName, createdAt];
}
