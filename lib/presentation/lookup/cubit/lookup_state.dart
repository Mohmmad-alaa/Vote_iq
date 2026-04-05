import 'package:equatable/equatable.dart';
import '../../../domain/entities/candidate.dart';
import '../../../domain/entities/electoral_list.dart';
import '../../../domain/entities/family.dart';
import '../../../domain/entities/sub_clan.dart';
import '../../../domain/entities/voting_center.dart';

abstract class LookupState extends Equatable {
  const LookupState();

  @override
  List<Object?> get props => [];
}

class LookupInitial extends LookupState {
  const LookupInitial();
}

class LookupLoading extends LookupState {
  const LookupLoading();
}

class LookupLoaded extends LookupState {
  final List<Family> families;
  final List<SubClan> subClans;
  final List<VotingCenter> centers;
  final List<ElectoralList> electoralLists;
  final List<Candidate> candidates;

  const LookupLoaded({
    required this.families,
    required this.subClans,
    required this.centers,
    required this.electoralLists,
    required this.candidates,
  });

  @override
  List<Object?> get props => [
        families,
        subClans,
        centers,
        electoralLists,
        candidates,
      ];
}

class LookupError extends LookupState {
  final String message;
  const LookupError(this.message);

  @override
  List<Object?> get props => [message];
}
