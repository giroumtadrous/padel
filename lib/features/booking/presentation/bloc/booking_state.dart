import 'package:equatable/equatable.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/booking/data/models/time_slot_model.dart';

abstract class BookingState extends Equatable {
  const BookingState();
  @override
  List<Object?> get props => [];
}

class BookingInitial extends BookingState {
  const BookingInitial();
}

class SlotHolding extends BookingState {
  const SlotHolding();
}

class SlotHeld extends BookingState {
  final List<TimeSlotModel> slots;
  final String venueId;
  final String courtId;
  const SlotHeld({required this.slots, required this.venueId, required this.courtId});

  double get totalPrice => slots.fold(0.0, (sum, s) => sum + s.price);
  DateTime get startTime => slots.first.startTime;
  DateTime get endTime => slots.last.endTime;
  int get durationMinutes => slots.fold(0, (sum, s) => sum + s.durationMinutes);

  @override
  List<Object?> get props => [slots.map((s) => s.id).toList()];
}

class BookingInProgress extends BookingState {
  const BookingInProgress();
}

class BookingSuccess extends BookingState {
  final BookingModel booking;
  const BookingSuccess(this.booking);
  @override
  List<Object?> get props => [booking.id];
}

class BookingHistoryLoading extends BookingState {
  const BookingHistoryLoading();
}

class BookingHistoryLoaded extends BookingState {
  final List<BookingModel> upcoming;
  final List<BookingModel> past;
  const BookingHistoryLoaded({required this.upcoming, required this.past});
  @override
  List<Object?> get props => [upcoming, past];
}

class BookingError extends BookingState {
  final String message;
  const BookingError(this.message);
  @override
  List<Object?> get props => [message];
}
