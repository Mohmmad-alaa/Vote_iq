import 'package:equatable/equatable.dart';

class ElectoralList extends Equatable {
  final int id;
  final String listName;
  final DateTime? createdAt;

  const ElectoralList({
    required this.id,
    required this.listName,
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, listName, createdAt];
}
