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
            .map((d) => TimeSlotModel.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  /// One-shot fetch of every court's slots for [date], keyed by courtId —
  /// used to render the courts x time grid. A snapshot rather than a live
  /// stream is enough here since this only drives browsing/picking; the
  /// actual hold still re-validates availability atomically server-side.
  Future<Map<String, List<TimeSlotModel>>> getVenueSlotsForDate({
    required String venueId,
    required List<CourtModel> courts,
    required DateTime date,
    required int openingHour,
    required int closingHour,
  }) async {
    await Future.wait(courts.map((court) => generateSlotsForDay(
          venueId: venueId,
          courtId: court.id,
          court: court,
          date: date,
          openingHour: openingHour,
          closingHour: closingHour,
        )));

    final dateStr = _dateFmt.format(date);
    final result = <String, List<TimeSlotModel>>{};
    await Future.wait(courts.map((court) async {
      final snap = await _db
          .collection(AppConstants.venuesCollection)
          .doc(venueId)
          .collection(AppConstants.courtsSubcollection)
          .doc(court.id)
          .collection(AppConstants.slotsSubcollection)
          .doc(dateStr)
          .collection('times')
          .orderBy('startTime')
          .get();
      result[court.id] = snap.docs
          .map((d) => TimeSlotModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    }));
    return result;
  }

  /// Checks if a date is in the court's blocked dates list.
  Future<bool> isDateBlocked({
    required String venueId,
    required String courtId,
    required String dateStr,
  }) async {
    final courtDoc = await _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId)
        .get();

    if (!courtDoc.exists) return false;
    final blockedDates = List<String>.from(courtDoc.data()?['blockedDates'] as List? ?? []);
    return blockedDates.contains(dateStr);
  }

  /// Whether [userId] already has an active (upcoming) booking at [venueId]
  /// on [dateStr] that overlaps [startTime]..[endTime] on a *different*
  /// court. Same-court overlaps can't happen — the slot-hold mechanism
  /// already prevents that — this only stops a user holding two different
  /// courts at the same club for the same time.
  Future<bool> hasOverlappingBookingAtVenue({
    required String userId,
    required String venueId,
    required String courtId,
    required String dateStr,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final snap = await _db
        .collection(AppConstants.bookingsCollection)
        .where('userId', isEqualTo: userId)
        .where('venueId', isEqualTo: venueId)
        .where('date', isEqualTo: dateStr)
        .where('status', isEqualTo: AppConstants.bookingUpcoming)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['courtId'] == courtId) continue;
      final existingStart = (data['startTime'] as Timestamp?)?.toDate();
      final existingEnd = (data['endTime'] as Timestamp?)?.toDate();
      if (existingStart == null || existingEnd == null) continue;
      if (startTime.isBefore(existingEnd) && endTime.isAfter(existingStart)) {
        return true;
      }
    }
    return false;
  }

  /// Generates slot documents for a court on a given date if they don't exist.
  /// Respects blockedDates — will not generate slots for blocked dates.
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

    // Check if date is blocked
    final blocked = await isDateBlocked(venueId: venueId, courtId: courtId, dateStr: dateStr);
    if (blocked) return;

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

  /// Atomically confirms a booking by converting one or more held, consecutive
  /// slots into a single booking. Supports loyalty discount and wallet payment.
  ///
  /// A flat deposit (`AppConstants.depositPerHour` per booked hour) is paid
  /// in-app to hold the slot; the full court price (`cashDueAmount`) is
  /// settled separately in cash at the venue. For manual transfer methods
  /// (Vodafone Cash / Fawry / InstaPay) a screenshot of the transfer is
  /// required and the deposit sits as `pending_verification` until an admin
  /// approves/rejects it via [verifyPayment].
  Future<BookingModel> confirmBooking({
    required String venueId,
    required String courtId,
    required List<TimeSlotModel> slots,
    required String userId,
    required String venueName,
    required String courtName,
    String paymentMethod = 'card',
    bool applyLoyaltyDiscount = false,
    String? paymentProofUrl,
  }) async {
    final isManualMethod = AppConstants.manualPaymentMethods.contains(paymentMethod);
    if (isManualMethod && (paymentProofUrl == null || paymentProofUrl.isEmpty)) {
      throw Exception('Payment proof screenshot is required for this payment method.');
    }

    final bookingId = _uuid.v4();
    final slotRefs = slots
        .map((slot) => _db
            .collection(AppConstants.venuesCollection)
            .doc(venueId)
            .collection(AppConstants.courtsSubcollection)
            .doc(courtId)
            .collection(AppConstants.slotsSubcollection)
            .doc(slot.date)
            .collection('times')
            .doc(slot.id))
        .toList();

    final bookingRef = _db.collection(AppConstants.bookingsCollection).doc(bookingId);

    final rawTotal = slots.fold(0.0, (sum, s) => sum + s.price);
    final finalPrice =
        applyLoyaltyDiscount ? rawTotal * (1 - AppConstants.loyaltyDiscountPercent) : rawTotal;
    final durationMinutes = slots.fold(0, (sum, s) => sum + s.durationMinutes);
    // Deposit is a flat per-hour booking fee, independent of the court's
    // price — the full court price is paid separately, in cash, at the venue.
    final depositAmount = AppConstants.depositPerHour * (durationMinutes / 60.0);
    final cashDueAmount = finalPrice;

    final booking = BookingModel(
      id: bookingId,
      userId: userId,
      courtId: courtId,
      venueId: venueId,
      venueName: venueName,
      courtName: courtName,
      slotIds: slots.map((s) => s.id).toList(),
      date: slots.first.date,
      startTime: slots.first.startTime,
      endTime: slots.last.endTime,
      durationMinutes: durationMinutes,
      totalPrice: finalPrice,
      depositAmount: depositAmount,
      cashDueAmount: cashDueAmount,
      paymentMethod: paymentMethod,
      paymentStatus: isManualMethod ? AppConstants.paymentPending : AppConstants.paymentPaid,
      paymentProofUrl: paymentProofUrl,
      createdAt: DateTime.now(),
    );

    if (paymentMethod == AppConstants.paymentWallet) {
      final userDoc = await _db.collection(AppConstants.usersCollection).doc(userId).get();
      final walletBalance = (userDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
      if (walletBalance < depositAmount) {
        throw Exception('Insufficient wallet balance for the deposit');
      }
    }

    await _db.runTransaction((tx) async {
      // Firestore transactions require all reads before any writes.
      final snaps = await Future.wait(slotRefs.map((ref) => tx.get(ref)));
      for (final snap in snaps) {
        if (!snap.exists) throw Exception('Slot not found');
        final currentSlot = TimeSlotModel.fromJson(snap.data()!);
        if (currentSlot.status != SlotStatus.held || currentSlot.heldBy != userId) {
          throw Exception('Slot hold expired or was taken');
        }
      }

      for (final ref in slotRefs) {
        tx.update(ref, {
          'status': AppConstants.statusBooked,
          'bookingId': bookingId,
          'heldBy': null,
          'heldUntil': null,
        });
      }

      tx.set(bookingRef, booking.toJson());
    });

    // If paying by wallet, only the deposit is deducted now — the rest is cash.
    if (paymentMethod == AppConstants.paymentWallet) {
      await _db.collection(AppConstants.usersCollection).doc(userId).update({
        'walletBalance': FieldValue.increment(-depositAmount),
      });
    }

    return booking;
  }

  /// Admin approves or rejects a manual-payment deposit proof.
  ///
  /// Approved: deposit status becomes `paid`, booking stands.
  /// Rejected: booking is cancelled, its slots are released back to
  /// `available`, and a wallet-paid deposit (shouldn't normally happen for
  /// manual methods, but defensive) is refunded.
  Future<void> verifyPayment({
    required String bookingId,
    required bool approved,
  }) async {
    final bookingRef = _db.collection(AppConstants.bookingsCollection).doc(bookingId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(bookingRef);
      if (!snap.exists) throw Exception('Booking not found');
      final booking = BookingModel.fromJson({...snap.data()!, 'id': snap.id});

      final notificationRef = _db.collection('notifications').doc();

      if (approved) {
        tx.update(bookingRef, {'paymentStatus': AppConstants.paymentPaid});
        tx.set(notificationRef, {
          'userId': booking.userId,
          'title': 'Payment approved',
          'message':
              'Your deposit for ${booking.courtName} was approved. Your booking is confirmed.',
          'read': false,
          'bookingId': booking.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      tx.update(bookingRef, {
        'paymentStatus': AppConstants.paymentRejected,
        'status': AppConstants.bookingCancelled,
        'cancelledAt': Timestamp.fromDate(DateTime.now()),
      });
      tx.set(notificationRef, {
        'userId': booking.userId,
        'title': 'Payment rejected',
        'message':
            'Your deposit proof for ${booking.courtName} was rejected and the booking was cancelled.',
        'read': false,
        'bookingId': booking.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (final slotId in booking.slotIds) {
        final slotRef = _db
            .collection(AppConstants.venuesCollection)
            .doc(booking.venueId)
            .collection(AppConstants.courtsSubcollection)
            .doc(booking.courtId)
            .collection(AppConstants.slotsSubcollection)
            .doc(booking.date)
            .collection('times')
            .doc(slotId);
        tx.update(slotRef, {
          'status': AppConstants.statusAvailable,
          'bookingId': null,
        });
      }

      if (booking.paymentMethod == AppConstants.paymentWallet) {
        final userRef = _db.collection(AppConstants.usersCollection).doc(booking.userId);
        tx.update(userRef, {
          'walletBalance': FieldValue.increment(booking.depositAmount),
        });
      }
    });
  }

  /// Bookings across a venue awaiting manual-payment proof review.
  Stream<List<BookingModel>> pendingPaymentBookings(String venueId) {
    return _db
        .collection(AppConstants.bookingsCollection)
        .where('venueId', isEqualTo: venueId)
        .where('paymentStatus', isEqualTo: AppConstants.paymentPending)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromJson({...d.data(), 'id': d.id}))
            .toList());
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

      final slotRefs = booking.slotIds
          .map((slotId) => _db
              .collection(AppConstants.venuesCollection)
              .doc(booking.venueId)
              .collection(AppConstants.courtsSubcollection)
              .doc(booking.courtId)
              .collection(AppConstants.slotsSubcollection)
              .doc(booking.date)
              .collection('times')
              .doc(slotId))
          .toList();

      tx.update(bookingRef, {
        'status': AppConstants.bookingCancelled,
        'cancelledAt': Timestamp.fromDate(DateTime.now()),
      });

      for (final slotRef in slotRefs) {
        tx.update(slotRef, {
          'status': AppConstants.statusAvailable,
          'bookingId': null,
        });
      }
    });
  }

  Stream<List<BookingModel>> getUserBookingsStream(String userId) {
    return _db
        .collection(AppConstants.bookingsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<List<BookingModel>> getVenueBookingsStream(String venueId, DateTime date) {
    final dateStr = _dateFmt.format(date);
    return _db
        .collection(AppConstants.bookingsCollection)
        .where('venueId', isEqualTo: venueId)
        .where('date', isEqualTo: dateStr)
        .orderBy('startTime')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  /// Checks whether a user has already submitted a review for a specific booking.
  Future<bool> hasReviewForBooking(String bookingId, String userId) async {
    final snap = await _db
        .collection(AppConstants.reviewsCollection)
        .where('bookingId', isEqualTo: bookingId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}
