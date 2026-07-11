import 'package:equatable/equatable.dart';
import 'package:padel/features/tournaments/data/models/tournament_model.dart';

abstract class TournamentsEvent extends Equatable {
  const TournamentsEvent();
  @override
  List<Object?> get props => [];
}

class LoadTournaments extends TournamentsEvent {
  const LoadTournaments();
}

class JoinTournament extends TournamentsEvent {
  final String tournamentId;
  final String userId;
  const JoinTournament({required this.tournamentId, required this.userId});
  @override
  List<Object?> get props => [tournamentId, userId];
}

class CreateTournament extends TournamentsEvent {
  final TournamentModel tournament;
  const CreateTournament(this.tournament);
  @override
  List<Object?> get props => [tournament.name, tournament.startTime];
}

class CancelTournament extends TournamentsEvent {
  final String tournamentId;
  final String adminId;
  const CancelTournament({required this.tournamentId, required this.adminId});
  @override
  List<Object?> get props => [tournamentId];
}
