import 'package:equatable/equatable.dart';
import 'package:padel/features/booking/data/models/time_slot_model.dart';

abstract class BookingEvent extends Equatable {
  const BookingEvent();
  @override
  List<Object?> get props => [];
}

class HoldSlots extends BookingEvent {
  final List<TimeSlotModel> slots;
  final String userId;
  const HoldSlots({required this.slots, required this.userId});
  @override
  List<Object?> get props => [slots.map((s) => s.id).toList(), userId];
}

class ReleaseHold extends BookingEvent {
  final String userId;
  const ReleaseHold(this.userId);
  @override
  List<Object?> get props => [userId];
}

class ConfirmBooking extends BookingEvent {
  final String userId;
  final String venueName;
  final String courtName;
  final String paymentMethod;
  final bool useLoyaltyDiscount;
  final String? paymentProofUrl;
  const ConfirmBooking({
    required this.userId,
    required this.venueName,
    required this.courtName,
    this.paymentMethod = 'card',
    this.useLoyaltyDiscount = false,
    this.paymentProofUrl,
  });
  @override
  List<Object?> get props => [userId, paymentMethod, useLoyaltyDiscount, paymentProofUrl];
}

class CancelBooking extends BookingEvent {
  final String bookingId;
  final double totalPrice;
  final double depositAmount;
  final DateTime bookingTime;
  
  const CancelBooking({
    required this.bookingId,
    required this.totalPrice,
    required this.depositAmount,
    required this.bookingTime,
  });
  
  @override
  List<Object?> get props => [bookingId, totalPrice, depositAmount, bookingTime];
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
