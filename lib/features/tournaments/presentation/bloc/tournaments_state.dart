import 'package:equatable/equatable.dart';
import 'package:padel/features/tournaments/data/models/tournament_model.dart';

abstract class TournamentsState extends Equatable {
  const TournamentsState();
  @override
  List<Object?> get props => [];
}

class TournamentsInitial extends TournamentsState {
  const TournamentsInitial();
}

class TournamentsLoading extends TournamentsState {
  const TournamentsLoading();
}

class TournamentsLoaded extends TournamentsState {
  final List<TournamentModel> tournaments;
  const TournamentsLoaded(this.tournaments);
  @override
  List<Object?> get props => [tournaments];
}

class TournamentActionInProgress extends TournamentsState {
  const TournamentActionInProgress();
}

class TournamentJoined extends TournamentsState {
  final String tournamentId;
  const TournamentJoined(this.tournamentId);
  @override
  List<Object?> get props => [tournamentId];
}

class TournamentCreated extends TournamentsState {
  final String tournamentId;
  const TournamentCreated(this.tournamentId);
  @override
  List<Object?> get props => [tournamentId];
}

class TournamentsError extends TournamentsState {
  final String message;
  const TournamentsError(this.message);
  @override
  List<Object?> get props => [message];
}
