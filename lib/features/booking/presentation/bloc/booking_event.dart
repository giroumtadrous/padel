import 'package:equatable/equatable.dart';
import 'package:padel/features/booking/data/models/time_slot_model.dart';
import 'package:padel/features/venues/data/models/court_model.dart';

abstract class BookingEvent extends Equatable {
  const BookingEvent();
  @override
  List<Object?> get props => [];
}

class LoadSlots extends BookingEvent {
  final String venueId;
  final String courtId;
  final CourtModel court;
  final DateTime date;
  final int openingHour;
  final int closingHour;
  const LoadSlots({
    required this.venueId,
    required this.courtId,
    required this.court,
    required this.date,
    required this.openingHour,
    required this.closingHour,
  });
  @override
  List<Object?> get props => [venueId, courtId, date];
}

class HoldSlot extends BookingEvent {
  final TimeSlotModel slot;
  final String userId;
  const HoldSlot({required this.slot, required this.userId});
  @override
  List<Object?> get props => [slot.id, userId];
}

class ReleaseHold extends BookingEvent {
  const ReleaseHold();
}

class ConfirmBooking extends BookingEvent {
  final String userId;
  final String venueName;
  final String courtName;
  const ConfirmBooking({required this.userId, required this.venueName, required this.courtName});
  @override
  List<Object?> get props => [userId];
}

class CancelBooking extends BookingEvent {
  final String bookingId;
  const CancelBooking(this.bookingId);
  @override
  List<Object?> get props => [bookingId];
}

class LoadBookingHistory extends BookingEvent {
  final String userId;
  const LoadBookingHistory(this.userId);
  @override
  List<Object?> get props => [userId];
}

class ResetBooking extends BookingEvent {
  const ResetBooking();
}
