import 'package:equatable/equatable.dart';

import '../../../domain/entities/voter.dart';

/// Voters list states.
abstract class VotersState extends Equatable {
  const VotersState();

  @override
  List<Object?> get props => [];
}

class VotersInitial extends VotersState {
  const VotersInitial();
}

class VotersLoading extends VotersState {
  const VotersLoading();
}

/// Loaded state with voters list, filter info, and pagination.
class VotersLoaded extends VotersState {
  final List<Voter> voters;
  final int totalCount;
  final bool hasReachedEnd;
  final bool isLoadingMore;
  final List<int>? filterFamilyIds;
  final int? filterSubClanId;
  final int? filterCenterId;
  final String? filterStatus;
  final String? searchQuery;

  const VotersLoaded({
    required this.voters,
    required this.totalCount,
    this.hasReachedEnd = false,
    this.isLoadingMore = false,
    this.filterFamilyIds,
    this.filterSubClanId,
    this.filterCenterId,
    this.filterStatus,
    this.searchQuery,
  });

  VotersLoaded copyWith({
    List<Voter>? voters,
    int? totalCount,
    bool? hasReachedEnd,
    bool? isLoadingMore,
    List<int>? filterFamilyIds,
    int? filterSubClanId,
    int? filterCenterId,
    String? filterStatus,
    String? searchQuery,
  }) {
    return VotersLoaded(
      voters: voters ?? this.voters,
      totalCount: totalCount ?? this.totalCount,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      filterFamilyIds: filterFamilyIds ?? this.filterFamilyIds,
      filterSubClanId: filterSubClanId ?? this.filterSubClanId,
      filterCenterId: filterCenterId ?? this.filterCenterId,
      filterStatus: filterStatus ?? this.filterStatus,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
    voters.length,
    identityHashCode(voters),
    totalCount,
    hasReachedEnd,
    isLoadingMore,
    filterFamilyIds,
    filterSubClanId,
    filterCenterId,
    filterStatus,
    searchQuery,
  ];
}

class VotersError extends VotersState {
  final String message;

  const VotersError(this.message);

  @override
  List<Object?> get props => [message];
}
