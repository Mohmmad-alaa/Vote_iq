import 'package:equatable/equatable.dart';

class Candidate extends Equatable {
  final int id;
  final String candidateName;
  final int? listId;
  final DateTime? createdAt;
  final String? listName;

  const Candidate({
    required this.id,
    required this.candidateName,
    this.listId,
    this.createdAt,
    this.listName,
  });

  @override
  List<Object?> get props => [id, candidateName, listId, createdAt, listName];
}
