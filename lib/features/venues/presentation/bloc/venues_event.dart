import 'package:equatable/equatable.dart';

abstract class VenuesEvent extends Equatable {
  const VenuesEvent();
  @override
  List<Object?> get props => [];
}

class LoadVenues extends VenuesEvent {
  const LoadVenues();
}

class SearchVenues extends VenuesEvent {
  final String query;
  const SearchVenues(this.query);
  @override
  List<Object?> get props => [query];
}

class LoadVenueDetail extends VenuesEvent {
  final String venueId;
  const LoadVenueDetail(this.venueId);
  @override
  List<Object?> get props => [venueId];
}
