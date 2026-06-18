import 'package:equatable/equatable.dart';
import 'package:padel/features/venues/data/models/court_model.dart';
import 'package:padel/features/venues/data/models/venue_model.dart';

abstract class VenuesState extends Equatable {
  const VenuesState();
  @override
  List<Object?> get props => [];
}

class VenuesInitial extends VenuesState {
  const VenuesInitial();
}

class VenuesLoading extends VenuesState {
  const VenuesLoading();
}

class VenuesLoaded extends VenuesState {
  final List<VenueModel> venues;
  final List<VenueModel> filtered;
  const VenuesLoaded({required this.venues, List<VenueModel>? filtered})
      : filtered = filtered ?? venues;
  @override
  List<Object?> get props => [venues, filtered];
}

class VenueDetailLoading extends VenuesState {
  const VenueDetailLoading();
}

class VenueDetailLoaded extends VenuesState {
  final VenueModel venue;
  final List<CourtModel> courts;
  const VenueDetailLoaded({required this.venue, required this.courts});
  @override
  List<Object?> get props => [venue.id, courts];
}

class VenuesError extends VenuesState {
  final String message;
  const VenuesError(this.message);
  @override
  List<Object?> get props => [message];
}
