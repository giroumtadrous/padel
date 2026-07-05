import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/booking/data/models/time_slot_model.dart';
import 'package:padel/features/booking/data/services/booking_service.dart';
import 'booking_event.dart';
import 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingService _bookingService;

  BookingBloc({required BookingService bookingService})
      : _bookingService = bookingService,
        super(const BookingInitial()) {
    on<HoldSlots>(_onHoldSlots);
    on<ReleaseHold>(_onReleaseHold);
    on<ConfirmBooking>(_onConfirmBooking);
    on<CancelBooking>(_onCancelBooking);
    on<LoadBookingHistory>(_onLoadHistory);
    on<ResetBooking>(_onReset);
  }

  Future<void> _onHoldSlots(HoldSlots event, Emitter<BookingState> emit) async {
    emit(const SlotHolding());

    final firstSlot = event.slots.first;
    final hasConflict = await _bookingService.hasOverlappingBookingAtVenue(
      userId: event.userId,
      venueId: firstSlot.venueId,
      courtId: firstSlot.courtId,
      dateStr: firstSlot.date,
      startTime: event.slots.first.startTime,
      endTime: event.slots.last.endTime,
    );
    if (hasConflict) {
      emit(const BookingError(
          'You already have a booking at this venue for an overlapping time on another court.'));
      return;
    }

    final heldSoFar = <TimeSlotModel>[];
    for (final slot in event.slots) {
      final ok = await _bookingService.holdSlot(
        venueId: slot.venueId,
        courtId: slot.courtId,
        date: slot.date,
        slotId: slot.id,
        userId: event.userId,
      );
      if (!ok) {
        // Roll back any holds already acquired in this batch.
        for (final held in heldSoFar) {
          await _bookingService.releaseHold(
            venueId: held.venueId,
            courtId: held.courtId,
            date: held.date,
            slotId: held.id,
            userId: event.userId,
          );
        }
        emit(const BookingError(
            'One or more selected slots are no longer available. Please choose again.'));
        return;
      }
      heldSoFar.add(slot);
    }
    emit(SlotHeld(
      slots: event.slots,
      venueId: event.slots.first.venueId,
      courtId: event.slots.first.courtId,
    ));
  }

  Future<void> _onReleaseHold(ReleaseHold event, Emitter<BookingState> emit) async {
    final current = state;
    if (current is SlotHeld) {
      for (final slot in current.slots) {
        await _bookingService.releaseHold(
          venueId: slot.venueId,
          courtId: slot.courtId,
          date: slot.date,
          slotId: slot.id,
          userId: event.userId,
        );
      }
    }
    emit(const BookingInitial());
  }

  Future<void> _onConfirmBooking(ConfirmBooking event, Emitter<BookingState> emit) async {
    final current = state;
    if (current is! SlotHeld) return;

    emit(const BookingInProgress());
    try {
      final booking = await _bookingService.confirmBooking(
        venueId: current.venueId,
        courtId: current.courtId,
        slots: current.slots,
        userId: event.userId,
        venueName: event.venueName,
        courtName: event.courtName,
        paymentMethod: event.paymentMethod,
        applyLoyaltyDiscount: event.useLoyaltyDiscount,
        paymentProofUrl: event.paymentProofUrl,
      );
      emit(BookingSuccess(booking));
    } catch (e) {
      emit(BookingError(e.toString()));
    }
  }

  Future<void> _onCancelBooking(CancelBooking event, Emitter<BookingState> emit) async {
    try {
      await _bookingService.cancelBooking(event.bookingId);
    } catch (e) {
      emit(BookingError(e.toString()));
    }
  }

  Future<void> _onLoadHistory(LoadBookingHistory event, Emitter<BookingState> emit) async {
    emit(const BookingHistoryLoading());
    await emit.onEach(
      _bookingService.getUserBookingsStream(event.userId),
      onData: (bookings) {
        final now = DateTime.now();
        final upcoming = bookings
            .where((b) => b.status == BookingStatus.upcoming && b.startTime.isAfter(now))
            .toList();
        final past = bookings
            .where((b) =>
                b.status == BookingStatus.cancelled ||
                b.status == BookingStatus.completed ||
                (b.status == BookingStatus.upcoming && b.startTime.isBefore(now)))
            .toList();
        emit(BookingHistoryLoaded(upcoming: upcoming, past: past));
      },
      onError: (e, _) => emit(BookingError(e.toString())),
    );
  }

  void _onReset(ResetBooking event, Emitter<BookingState> emit) {
    emit(const BookingInitial());
  }
}
