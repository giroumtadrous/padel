import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padel/features/venues/data/services/venue_service.dart';
import 'venues_event.dart';
import 'venues_state.dart';

class VenuesBloc extends Bloc<VenuesEvent, VenuesState> {
  final VenueService _venueService;

  VenuesBloc({required VenueService venueService})
      : _venueService = venueService,
        super(const VenuesInitial()) {
    on<LoadVenues>(_onLoadVenues);
    on<SearchVenues>(_onSearchVenues);
    on<LoadVenueDetail>(_onLoadVenueDetail);
  }

  Future<void> _onLoadVenues(LoadVenues event, Emitter<VenuesState> emit) async {
    emit(const VenuesLoading());
    await emit.onEach(
      _venueService.getVenuesStream(),
      onData: (venues) => emit(VenuesLoaded(venues: venues)),
      onError: (e, _) => emit(VenuesError(e.toString())),
    );
  }

  void _onSearchVenues(SearchVenues event, Emitter<VenuesState> emit) {
    final current = state;
    if (current is! VenuesLoaded) return;

    if (event.query.isEmpty) {
      emit(VenuesLoaded(venues: current.venues));
      return;
    }

    final q = event.query.toLowerCase();
    final filtered = current.venues
        .where((v) =>
            v.name.toLowerCase().contains(q) ||
            v.city.toLowerCase().contains(q) ||
            v.address.toLowerCase().contains(q))
        .toList();

    emit(VenuesLoaded(venues: current.venues, filtered: filtered));
  }

  Future<void> _onLoadVenueDetail(LoadVenueDetail event, Emitter<VenuesState> emit) async {
    emit(const VenueDetailLoading());
    try {
      final venue = await _venueService.getVenue(event.venueId);
      await emit.onEach(
        _venueService.getCourtsStream(event.venueId),
        onData: (courts) => emit(VenueDetailLoaded(venue: venue, courts: courts)),
        onError: (e, _) => emit(VenuesError(e.toString())),
      );
    } catch (e) {
      emit(VenuesError(e.toString()));
    }
  }
}
