import 'package:equatable/equatable.dart';

import '../../../domain/repositories/voter_repository.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class ListStatItem extends Equatable {
  final String listName;
  final int totalVotes;
  final List<CandidateStatItem> candidates;

  const ListStatItem({
    required this.listName,
    required this.totalVotes,
    required this.candidates,
  });

  @override
  List<Object?> get props => [listName, totalVotes, candidates];
}

class CandidateStatItem extends Equatable {
  final String candidateName;
  final int votes;

  const CandidateStatItem({required this.candidateName, required this.votes});

  @override
  List<Object?> get props => [candidateName, votes];
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  final VoterStats overallStats;
  final Map<String, VoterStats>? statsByFamily;
  final Map<String, VoterStats>? statsBySubClan;
  final List<ListStatItem>? statsByList;
  final bool isLoadingFamilyStats;
  final bool isLoadingSubClanStats;
  final bool isLoadingListStats;
  final bool hasLoadedFamilyStats;
  final bool hasLoadedSubClanStats;
  final bool hasLoadedListStats;

  const DashboardLoaded({
    required this.overallStats,
    this.statsByFamily,
    this.statsBySubClan,
    this.statsByList,
    this.isLoadingFamilyStats = false,
    this.isLoadingSubClanStats = false,
    this.isLoadingListStats = false,
    this.hasLoadedFamilyStats = false,
    this.hasLoadedSubClanStats = false,
    this.hasLoadedListStats = false,
  });

  DashboardLoaded copyWith({
    VoterStats? overallStats,
    Map<String, VoterStats>? statsByFamily,
    Map<String, VoterStats>? statsBySubClan,
    List<ListStatItem>? statsByList,
    bool? isLoadingFamilyStats,
    bool? isLoadingSubClanStats,
    bool? isLoadingListStats,
    bool? hasLoadedFamilyStats,
    bool? hasLoadedSubClanStats,
    bool? hasLoadedListStats,
  }) {
    return DashboardLoaded(
      overallStats: overallStats ?? this.overallStats,
      statsByFamily: statsByFamily ?? this.statsByFamily,
      statsBySubClan: statsBySubClan ?? this.statsBySubClan,
      statsByList: statsByList ?? this.statsByList,
      isLoadingFamilyStats: isLoadingFamilyStats ?? this.isLoadingFamilyStats,
      isLoadingSubClanStats:
          isLoadingSubClanStats ?? this.isLoadingSubClanStats,
      isLoadingListStats: isLoadingListStats ?? this.isLoadingListStats,
      hasLoadedFamilyStats: hasLoadedFamilyStats ?? this.hasLoadedFamilyStats,
      hasLoadedSubClanStats:
          hasLoadedSubClanStats ?? this.hasLoadedSubClanStats,
      hasLoadedListStats: hasLoadedListStats ?? this.hasLoadedListStats,
    );
  }

  @override
  List<Object?> get props => [
    overallStats,
    statsByFamily,
    statsBySubClan,
    statsByList,
    isLoadingFamilyStats,
    isLoadingSubClanStats,
    isLoadingListStats,
    hasLoadedFamilyStats,
    hasLoadedSubClanStats,
    hasLoadedListStats,
  ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
