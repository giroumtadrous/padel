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
        .map((snap) => snap.docs.map((d) => BookingModel.fromJson(d.data())).toList());
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
          final bookings = snap.docs.map((d) => BookingModel.fromJson(d.data())).toList();
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
    return snap.docs.map((d) => VenueModel.fromJson(d.data())).toList();
  }

  Future<List<CourtModel>> getAdminCourts(String venueId) async {
    final snap = await _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .get();
    return snap.docs.map((d) => CourtModel.fromJson(d.data())).toList();
  }

  Future<void> toggleCourtActive(String venueId, String courtId, bool isActive) async {
    await _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId)
        .update({'isActive': isActive});
  }
}
