import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/booking/data/models/time_slot_model.dart';
import 'package:padel/features/venues/data/models/court_model.dart';
import 'package:uuid/uuid.dart';

class BookingService {
  final FirebaseFirestore _db;
  static const _uuid = Uuid();
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  BookingService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<TimeSlotModel>> getSlotsStream(String venueId, String courtId, DateTime date) {
    final dateStr = _dateFmt.format(date);
    return _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId)
        .collection(AppConstants.slotsSubcollection)
        .doc(dateStr)
        .collection('times')
        .orderBy('startTime')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TimeSlotModel.fromJson(d.data()))
            .toList());
  }

  // Generates slot documents for a court on a given date if they don't exist.
  Future<void> generateSlotsForDay({
    required String venueId,
    required String courtId,
    required CourtModel court,
    required DateTime date,
    required int openingHour,
    required int closingHour,
    int durationMinutes = 60,
  }) async {
    final dateStr = _dateFmt.format(date);
    final slotsRef = _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId)
        .collection(AppConstants.slotsSubcollection)
        .doc(dateStr)
        .collection('times');

    final existing = await slotsRef.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _db.batch();
    var current = DateTime(date.year, date.month, date.day, openingHour);
    final end = DateTime(date.year, date.month, date.day, closingHour);

    while (current.add(Duration(minutes: durationMinutes)).compareTo(end) <= 0) {
      final slotEnd = current.add(Duration(minutes: durationMinutes));
      final slotId = '${courtId}_${dateStr}_${DateFormat('HHmm').format(current)}';
      final isPeak = court.isPeak(current.hour);
      final price = isPeak ? court.peakHourPrice : court.offPeakPrice;

      final slot = TimeSlotModel(
        id: slotId,
        courtId: courtId,
        venueId: venueId,
        date: dateStr,
        startTime: current,
        endTime: slotEnd,
        durationMinutes: durationMinutes,
        status: SlotStatus.available,
        price: price * (durationMinutes / 60),
        isPeakHour: isPeak,
      );

      batch.set(slotsRef.doc(slotId), slot.toJson());
      current = slotEnd;
    }

    await batch.commit();
  }

  /// Atomically holds a slot for 5 minutes. Returns true if successful.
  Future<bool> holdSlot({
    required String venueId,
    required String courtId,
    required String date,
    required String slotId,
    required String userId,
  }) async {
    final slotRef = _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId)
        .collection(AppConstants.slotsSubcollection)
        .doc(date)
        .collection('times')
        .doc(slotId);

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(slotRef);
        if (!snap.exists) throw Exception('Slot not found');

        final slot = TimeSlotModel.fromJson(snap.data()!);

        // Allow re-hold if current user already holds it
        if (slot.status == SlotStatus.held && slot.heldBy != userId) {
          final now = DateTime.now();
          if (slot.heldUntil != null && slot.heldUntil!.isAfter(now)) {
            throw Exception('Slot is currently held by another user');
          }
        }

        if (slot.status == SlotStatus.booked) {
          throw Exception('Slot is already booked');
        }

        if (slot.status == SlotStatus.maintenance) {
          throw Exception('Slot is blocked for maintenance');
        }

        tx.update(slotRef, {
          'status': AppConstants.statusHeld,
          'heldBy': userId,
          'heldUntil': Timestamp.fromDate(
            DateTime.now().add(Duration(minutes: AppConstants.slotHoldMinutes)),
          ),
        });
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Atomically confirms a booking by converting a held slot to booked.
  Future<BookingModel> confirmBooking({
    required String venueId,
    required String courtId,
    required String slotId,
    required String date,
    required String userId,
    required String venueName,
    required String courtName,
    required TimeSlotModel slot,
  }) async {
    final bookingId = _uuid.v4();
    final slotRef = _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId)
        .collection(AppConstants.slotsSubcollection)
        .doc(date)
        .collection('times')
        .doc(slotId);

    final bookingRef = _db.collection(AppConstants.bookingsCollection).doc(bookingId);

    final booking = BookingModel(
      id: bookingId,
      userId: userId,
      courtId: courtId,
      venueId: venueId,
      venueName: venueName,
      courtName: courtName,
      slotId: slotId,
      date: date,
      startTime: slot.startTime,
      endTime: slot.endTime,
      durationMinutes: slot.durationMinutes,
      totalPrice: slot.price,
      createdAt: DateTime.now(),
    );

    await _db.runTransaction((tx) async {
      final slotSnap = await tx.get(slotRef);
      if (!slotSnap.exists) throw Exception('Slot not found');

      final currentSlot = TimeSlotModel.fromJson(slotSnap.data()!);
      if (currentSlot.status != SlotStatus.held || currentSlot.heldBy != userId) {
        throw Exception('Slot hold expired or was taken');
      }

      tx.update(slotRef, {
        'status': AppConstants.statusBooked,
        'bookingId': bookingId,
        'heldBy': null,
        'heldUntil': null,
      });

      tx.set(bookingRef, booking.toJson());
    });

    return booking;
  }

  Future<void> releaseHold({
    required String venueId,
    required String courtId,
    required String date,
    required String slotId,
    required String userId,
  }) async {
    final slotRef = _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId)
        .collection(AppConstants.slotsSubcollection)
        .doc(date)
        .collection('times')
        .doc(slotId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(slotRef);
      if (!snap.exists) return;
      final slot = TimeSlotModel.fromJson(snap.data()!);
      if (slot.heldBy == userId) {
        tx.update(slotRef, {
          'status': AppConstants.statusAvailable,
          'heldBy': null,
          'heldUntil': null,
        });
      }
    });
  }

  Future<void> cancelBooking(String bookingId) async {
    final bookingRef = _db.collection(AppConstants.bookingsCollection).doc(bookingId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(bookingRef);
      if (!snap.exists) throw Exception('Booking not found');

      final booking = BookingModel.fromJson(snap.data()!);

      final slotRef = _db
          .collection(AppConstants.venuesCollection)
          .doc(booking.venueId)
          .collection(AppConstants.courtsSubcollection)
          .doc(booking.courtId)
          .collection(AppConstants.slotsSubcollection)
          .doc(booking.date)
          .collection('times')
          .doc(booking.slotId);

      tx.update(bookingRef, {
        'status': AppConstants.bookingCancelled,
        'cancelledAt': Timestamp.fromDate(DateTime.now()),
      });

      tx.update(slotRef, {
        'status': AppConstants.statusAvailable,
        'bookingId': null,
      });
    });
  }

  Stream<List<BookingModel>> getUserBookingsStream(String userId) {
    return _db
        .collection(AppConstants.bookingsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BookingModel.fromJson(d.data())).toList());
  }

  Stream<List<BookingModel>> getVenueBookingsStream(String venueId, DateTime date) {
    final dateStr = _dateFmt.format(date);
    return _db
        .collection(AppConstants.bookingsCollection)
        .where('venueId', isEqualTo: venueId)
        .where('date', isEqualTo: dateStr)
        .orderBy('startTime')
        .snapshots()
        .map((snap) => snap.docs.map((d) => BookingModel.fromJson(d.data())).toList());
  }
}
