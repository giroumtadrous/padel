import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padel/features/matches/data/services/matchmaking_service.dart';
import 'matches_event.dart';
import 'matches_state.dart';

class MatchesBloc extends Bloc<MatchesEvent, MatchesState> {
  final MatchmakingService _matchmakingService;

  MatchesBloc({required MatchmakingService matchmakingService})
      : _matchmakingService = matchmakingService,
        super(const MatchesInitial()) {
    on<LoadOpenMatches>(_onLoad);
    on<JoinMatch>(_onJoin);
    on<LeaveMatch>(_onLeave);
    on<CreateOpenMatch>(_onCreate);
    on<CancelOpenMatch>(_onCancel);
    on<ApplySkillFilter>(_onFilter);
  }

  Future<void> _onLoad(LoadOpenMatches event, Emitter<MatchesState> emit) async {
    emit(const MatchesLoading());
    await emit.onEach(
      _matchmakingService.getOpenMatchesStream(
        minSkill: event.filterMinSkill,
        maxSkill: event.filterMaxSkill,
      ),
      onData: (matches) => emit(MatchesLoaded(
        matches: matches,
        filterMinSkill: event.filterMinSkill,
        filterMaxSkill: event.filterMaxSkill,
      )),
      onError: (e, _) => emit(MatchesError(e.toString())),
    );
  }

  Future<void> _onJoin(JoinMatch event, Emitter<MatchesState> emit) async {
    final current = state;
    emit(const MatchActionInProgress());
    try {
      await _matchmakingService.joinMatch(event.matchId, event.userId);
      emit(MatchJoined(event.matchId));
      if (current is MatchesLoaded) emit(current);
    } catch (e) {
      emit(MatchesError(e.toString()));
      if (current is MatchesLoaded) emit(current);
    }
  }

  Future<void> _onLeave(LeaveMatch event, Emitter<MatchesState> emit) async {
    final current = state;
    try {
      await _matchmakingService.leaveMatch(event.matchId, event.userId);
      if (current is MatchesLoaded) emit(current);
    } catch (e) {
      emit(MatchesError(e.toString()));
    }
  }

  Future<void> _onCreate(CreateOpenMatch event, Emitter<MatchesState> emit) async {
    emit(const MatchActionInProgress());
    try {
      final id = await _matchmakingService.createOpenMatch(event.match);
      emit(MatchCreated(id));
    } catch (e) {
      emit(MatchesError(e.toString()));
    }
  }

  Future<void> _onCancel(CancelOpenMatch event, Emitter<MatchesState> emit) async {
    try {
      await _matchmakingService.cancelMatch(event.matchId, event.organizerId);
    } catch (e) {
      emit(MatchesError(e.toString()));
    }
  }

  void _onFilter(ApplySkillFilter event, Emitter<MatchesState> emit) {
    add(LoadOpenMatches(filterMinSkill: event.minSkill, filterMaxSkill: event.maxSkill));
  }
}
