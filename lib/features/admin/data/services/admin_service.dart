import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/venues/data/models/court_model.dart';
import 'package:padel/features/venues/data/models/venue_model.dart';

class AdminService {
  final FirebaseFirestore _db;
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  AdminService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<BookingModel>> getVenueBookingsStream(String venueId, DateTime date) {
    final dateStr = _dateFmt.format(date);
    return _db
        .collection(AppConstants.bookingsCollection)
        .where('venueId', isEqualTo: venueId)
        .where('date', isEqualTo: dateStr)
        .where('status', whereIn: [
          AppConstants.bookingUpcoming,
          AppConstants.bookingCompleted,
        ])
        .orderBy('startTime')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<Map<String, dynamic>> getDailyRevenueStream(String venueId, DateTime date) {
    final dateStr = _dateFmt.format(date);
    return _db
        .collection(AppConstants.bookingsCollection)
        .where('venueId', isEqualTo: venueId)
        .where('date', isEqualTo: dateStr)
        .where('status', whereIn: [
          AppConstants.bookingUpcoming,
          AppConstants.bookingCompleted,
        ])
        .snapshots()
        .map((snap) {
          final bookings = snap.docs
              .map((d) => BookingModel.fromJson({...d.data(), 'id': d.id}))
              .toList();
          final total = bookings.fold<double>(0, (sum, b) => sum + b.totalPrice);
          return {
            'total': total,
            'count': bookings.length,
            'bookings': bookings,
          };
        });
  }

  Future<void> blockSlot({
    required String venueId,
    required String courtId,
    required String date,
    required String slotId,
    String? note,
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

    await slotRef.update({
      'status': AppConstants.statusMaintenance,
      if (note != null) 'maintenanceNote': note,
    });
  }

  Future<void> unblockSlot({
    required String venueId,
    required String courtId,
    required String date,
    required String slotId,
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

    await slotRef.update({
      'status': AppConstants.statusAvailable,
      'maintenanceNote': FieldValue.delete(),
    });
  }

  Future<List<VenueModel>> getAdminVenues(String adminId) async {
    final snap = await _db
        .collection(AppConstants.venuesCollection)
        .where('adminId', isEqualTo: adminId)
        .get();
    return snap.docs
        .map((d) => VenueModel.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  Future<List<CourtModel>> getAdminCourts(String venueId) async {
    final snap = await _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .get();
    return snap.docs
        .map((d) => CourtModel.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  Future<void> toggleCourtActive(String venueId, String courtId, bool isActive) async {
    await _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId)
        .update({'isActive': isActive});
  }

  /// Grants [adminEmail]'s account scoped admin access to a single court —
  /// independent of role/managedVenueIds — by recording the composite
  /// "venueId::courtId" ref on their user doc and denormalising the admin's
  /// identity onto the court itself for display.
  Future<void> assignCourtAdmin({
    required String venueId,
    required String courtId,
    required String adminEmail,
  }) async {
    final userQuery = await _db
        .collection(AppConstants.usersCollection)
        .where('email', isEqualTo: adminEmail)
        .limit(1)
        .get();
    if (userQuery.docs.isEmpty) {
      throw Exception('No account found for $adminEmail');
    }
    final adminUid = userQuery.docs.first.id;
    final courtRef = _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId);

    await courtRef.update({
      'courtAdminId': adminUid,
      'courtAdminEmail': adminEmail,
    });
    await _db.collection(AppConstants.usersCollection).doc(adminUid).update({
      'managedCourtIds': FieldValue.arrayUnion(['$venueId::$courtId']),
    });
  }

  Future<void> unassignCourtAdmin({required String venueId, required String courtId}) async {
    final courtRef = _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId);
    final courtSnap = await courtRef.get();
    final currentAdminId = courtSnap.data()?['courtAdminId'] as String?;

    await courtRef.update({
      'courtAdminId': FieldValue.delete(),
      'courtAdminEmail': FieldValue.delete(),
    });
    if (currentAdminId != null) {
      await _db.collection(AppConstants.usersCollection).doc(currentAdminId).update({
        'managedCourtIds': FieldValue.arrayRemove(['$venueId::$courtId']),
      });
    }
  }

  Future<CourtModel?> getCourtByRef(String venueId, String courtId) async {
    final snap = await _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId)
        .get();
    if (!snap.exists) return null;
    return CourtModel.fromJson({...snap.data()!, 'id': snap.id});
  }

  Future<String> getVenueName(String venueId) async {
    final snap = await _db.collection(AppConstants.venuesCollection).doc(venueId).get();
    return snap.data()?['name'] as String? ?? '';
  }

  Stream<Map<String, dynamic>> getCourtDailyStatsStream(String courtId, DateTime date) {
    final dateStr = _dateFmt.format(date);
    return _db
        .collection(AppConstants.bookingsCollection)
        .where('courtId', isEqualTo: courtId)
        .where('date', isEqualTo: dateStr)
        .where('status', whereIn: [
          AppConstants.bookingUpcoming,
          AppConstants.bookingCompleted,
        ])
        .orderBy('startTime')
        .snapshots()
        .map((snap) {
          final bookings = snap.docs
              .map((d) => BookingModel.fromJson({...d.data(), 'id': d.id}))
              .toList();
          final total = bookings.fold<double>(0, (sum, b) => sum + b.totalPrice);
          return {
            'total': total,
            'count': bookings.length,
            'bookings': bookings,
          };
        });
  }

  /// Occupancy = booked slots / total slots generated for that court+date.
  Stream<Map<String, int>> getCourtOccupancyStream(String venueId, String courtId, DateTime date) {
    final dateStr = _dateFmt.format(date);
    return _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId)
        .collection(AppConstants.slotsSubcollection)
        .doc(dateStr)
        .collection('times')
        .snapshots()
        .map((snap) {
          final total = snap.docs.length;
          final booked = snap.docs
              .where((d) => d.data()['status'] == AppConstants.statusBooked)
              .length;
          return {'booked': booked, 'total': total};
        });
  }
}
