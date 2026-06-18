import 'package:equatable/equatable.dart';
import 'package:padel/features/matches/data/models/open_match_model.dart';

abstract class MatchesState extends Equatable {
  const MatchesState();
  @override
  List<Object?> get props => [];
}

class MatchesInitial extends MatchesState {
  const MatchesInitial();
}

class MatchesLoading extends MatchesState {
  const MatchesLoading();
}

class MatchesLoaded extends MatchesState {
  final List<OpenMatchModel> matches;
  final double? filterMinSkill;
  final double? filterMaxSkill;
  const MatchesLoaded({required this.matches, this.filterMinSkill, this.filterMaxSkill});
  @override
  List<Object?> get props => [matches, filterMinSkill, filterMaxSkill];
}

class MatchActionInProgress extends MatchesState {
  const MatchActionInProgress();
}

class MatchJoined extends MatchesState {
  final String matchId;
  const MatchJoined(this.matchId);
  @override
  List<Object?> get props => [matchId];
}

class MatchCreated extends MatchesState {
  final String matchId;
  const MatchCreated(this.matchId);
  @override
  List<Object?> get props => [matchId];
}

class MatchesError extends MatchesState {
  final String message;
  const MatchesError(this.message);
  @override
  List<Object?> get props => [message];
}
