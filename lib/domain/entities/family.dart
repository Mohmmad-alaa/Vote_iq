import 'package:equatable/equatable.dart';

/// Family entity (e.g., هرشة، خصيب، عمار).
class Family extends Equatable {
  final int id;
  final String familyName;
  final DateTime? createdAt;

  const Family({
    required this.id,
    required this.familyName,
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, familyName, createdAt];
}
