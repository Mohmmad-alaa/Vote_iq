import '../../domain/entities/candidate.dart';

class VoterCandidateModel {
  final int? id;
  final String voterSymbol;
  final int candidateId;
  final int voteOrder;
  final DateTime? createdAt;

  const VoterCandidateModel({
    this.id,
    required this.voterSymbol,
    required this.candidateId,
    required this.voteOrder,
    this.createdAt,
  });

  factory VoterCandidateModel.fromJson(Map<String, dynamic> json) {
    return VoterCandidateModel(
      id: json['id'] as int?,
      voterSymbol: json['voter_symbol'] as String,
      candidateId: json['candidate_id'] as int,
      voteOrder: json['vote_order'] as int,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'voter_symbol': voterSymbol,
      'candidate_id': candidateId,
      'vote_order': voteOrder,
    };
  }

  factory VoterCandidateModel.fromEntity(Candidate candidate, int voteOrder) {
    return VoterCandidateModel(
      voterSymbol: '',
      candidateId: candidate.id,
      voteOrder: voteOrder,
    );
  }
}
