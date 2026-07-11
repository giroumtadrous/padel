import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padel/features/tournaments/data/services/tournament_service.dart';
import 'tournaments_event.dart';
import 'tournaments_state.dart';

class TournamentsBloc extends Bloc<TournamentsEvent, TournamentsState> {
  final TournamentService _tournamentService;

  TournamentsBloc({required TournamentService tournamentService})
      : _tournamentService = tournamentService,
        super(const TournamentsInitial()) {
    on<LoadTournaments>(_onLoad);
    on<JoinTournament>(_onJoin);
    on<CreateTournament>(_onCreate);
    on<CancelTournament>(_onCancel);
  }

  Future<void> _onLoad(LoadTournaments event, Emitter<TournamentsState> emit) async {
    emit(const TournamentsLoading());
    await emit.onEach(
      _tournamentService.getTournamentsStream(),
      onData: (tournaments) => emit(TournamentsLoaded(tournaments)),
      onError: (e, _) => emit(TournamentsError(e.toString())),
    );
  }

  Future<void> _onJoin(JoinTournament event, Emitter<TournamentsState> emit) async {
    final current = state;
    emit(const TournamentActionInProgress());
    try {
      await _tournamentService.joinTournament(event.tournamentId, event.userId);
      emit(TournamentJoined(event.tournamentId));
      if (current is TournamentsLoaded) emit(current);
    } catch (e) {
      emit(TournamentsError(e.toString()));
      if (current is TournamentsLoaded) emit(current);
    }
  }

  Future<void> _onCreate(CreateTournament event, Emitter<TournamentsState> emit) async {
    emit(const TournamentActionInProgress());
    try {
      final id = await _tournamentService.createTournament(event.tournament);
      emit(TournamentCreated(id));
    } catch (e) {
      emit(TournamentsError(e.toString()));
    }
  }

  Future<void> _onCancel(CancelTournament event, Emitter<TournamentsState> emit) async {
    try {
      await _tournamentService.cancelTournament(event.tournamentId, event.adminId);
    } catch (e) {
      emit(TournamentsError(e.toString()));
    }
  }
}
