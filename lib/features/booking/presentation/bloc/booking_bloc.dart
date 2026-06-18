import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/booking/data/services/booking_service.dart';
import 'booking_event.dart';
import 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingService _bookingService;

  BookingBloc({required BookingService bookingService})
      : _bookingService = bookingService,
        super(const BookingInitial()) {
    on<LoadSlots>(_onLoadSlots);
    on<HoldSlot>(_onHoldSlot);
    on<ReleaseHold>(_onReleaseHold);
    on<ConfirmBooking>(_onConfirmBooking);
    on<CancelBooking>(_onCancelBooking);
    on<LoadBookingHistory>(_onLoadHistory);
    on<ResetBooking>(_onReset);
  }

  Future<void> _onLoadSlots(LoadSlots event, Emitter<BookingState> emit) async {
    emit(const SlotsLoading());
    await _bookingService.generateSlotsForDay(
      venueId: event.venueId,
      courtId: event.courtId,
      court: event.court,
      date: event.date,
      openingHour: event.openingHour,
      closingHour: event.closingHour,
    );
    await emit.onEach(
      _bookingService.getSlotsStream(event.venueId, event.courtId, event.date),
      onData: (slots) => emit(SlotsLoaded(slots: slots)),
      onError: (e, _) => emit(BookingError(e.toString())),
    );
  }

  Future<void> _onHoldSlot(HoldSlot event, Emitter<BookingState> emit) async {
    emit(const SlotHolding());
    final held = await _bookingService.holdSlot(
      venueId: event.slot.venueId,
      courtId: event.slot.courtId,
      date: event.slot.date,
      slotId: event.slot.id,
      userId: event.userId,
    );
    if (held) {
      emit(SlotHeld(
        slot: event.slot,
        venueId: event.slot.venueId,
        courtId: event.slot.courtId,
      ));
    } else {
      emit(const BookingError('This slot is no longer available. Please choose another.'));
    }
  }

  Future<void> _onReleaseHold(ReleaseHold event, Emitter<BookingState> emit) async {
    final current = state;
    if (current is SlotHeld) {
      // Fire-and-forget release
      _bookingService.releaseHold(
        venueId: current.venueId,
        courtId: current.courtId,
        date: current.slot.date,
        slotId: current.slot.id,
        userId: '',
      );
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
        slotId: current.slot.id,
        date: current.slot.date,
        userId: event.userId,
        venueName: event.venueName,
        courtName: event.courtName,
        slot: current.slot,
      );
      emit(BookingSuccess(booking));
    } catch (e) {
      emit(BookingError(e.toString()));
    }
  }

  Future<void> _onCancelBooking(CancelBooking event, Emitter<BookingState> emit) async {
    try {
      await _bookingService.cancelBooking(event.bookingId);
      // History will be refreshed via stream
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
