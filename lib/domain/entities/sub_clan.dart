import 'package:equatable/equatable.dart';

/// Sub-clan entity (e.g., زبداوي، نافلة — فرع من عائلة هرشة).
class SubClan extends Equatable {
  final int id;
  final int familyId;
  final String subName;
  final DateTime? createdAt;

  // Resolved name from join
  final String? familyName;

  const SubClan({
    required this.id,
    required this.familyId,
    required this.subName,
    this.createdAt,
    this.familyName,
  });

  @override
  List<Object?> get props => [id, familyId, subName, createdAt];
}
