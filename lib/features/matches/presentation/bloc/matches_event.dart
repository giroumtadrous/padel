import 'package:equatable/equatable.dart';
import 'package:padel/features/matches/data/models/open_match_model.dart';

abstract class MatchesEvent extends Equatable {
  const MatchesEvent();
  @override
  List<Object?> get props => [];
}

class LoadOpenMatches extends MatchesEvent {
  final double? filterMinSkill;
  final double? filterMaxSkill;
  const LoadOpenMatches({this.filterMinSkill, this.filterMaxSkill});
  @override
  List<Object?> get props => [filterMinSkill, filterMaxSkill];
}

class JoinMatch extends MatchesEvent {
  final String matchId;
  final String userId;
  final double userSkillLevel;
  const JoinMatch({required this.matchId, required this.userId, required this.userSkillLevel});
  @override
  List<Object?> get props => [matchId, userId];
}

class LeaveMatch extends MatchesEvent {
  final String matchId;
  final String userId;
  const LeaveMatch({required this.matchId, required this.userId});
  @override
  List<Object?> get props => [matchId, userId];
}

class CreateOpenMatch extends MatchesEvent {
  final OpenMatchModel match;
  const CreateOpenMatch(this.match);
  @override
  List<Object?> get props => [match.bookingId];
}

class CancelOpenMatch extends MatchesEvent {
  final String matchId;
  final String organizerId;
  const CancelOpenMatch({required this.matchId, required this.organizerId});
  @override
  List<Object?> get props => [matchId];
}

class ApplySkillFilter extends MatchesEvent {
  final double? minSkill;
  final double? maxSkill;
  const ApplySkillFilter({this.minSkill, this.maxSkill});
  @override
  List<Object?> get props => [minSkill, maxSkill];
}
