import 'package:equatable/equatable.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/venues/data/models/court_model.dart';
import 'package:padel/features/venues/data/models/venue_model.dart';

abstract class AdminState extends Equatable {
  const AdminState();
  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {
  const AdminInitial();
}

class AdminLoading extends AdminState {
  const AdminLoading();
}

class AdminDashboardLoaded extends AdminState {
  final VenueModel venue;
  final List<CourtModel> courts;
  final List<BookingModel> todaysBookings;
  final double totalRevenue;
  final DateTime selectedDate;
  const AdminDashboardLoaded({
    required this.venue,
    required this.courts,
    required this.todaysBookings,
    required this.totalRevenue,
    required this.selectedDate,
  });
  @override
  List<Object?> get props => [venue.id, todaysBookings.length, totalRevenue, selectedDate];
}

class AdminActionSuccess extends AdminState {
  final String message;
  const AdminActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class AdminError extends AdminState {
  final String message;
  const AdminError(this.message);
  @override
  List<Object?> get props => [message];
}
