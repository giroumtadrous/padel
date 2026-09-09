import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/features/auth/data/models/user_model.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/venues/data/models/court_model.dart';
import 'package:padel/features/venues/data/models/venue_model.dart';

class AdminService {
  final FirebaseFirestore _db;
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  AdminService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  Stream<List<BookingModel>> getVenueBookingsStream(
    String venueId,
    DateTime date,
  ) {
    final dateStr = _dateFmt.format(date);
    return _db
        .collection(AppConstants.bookingsCollection)
        .where('venueId', isEqualTo: venueId)
        .where('date', isEqualTo: dateStr)
        .where(
          'status',
          whereIn: [
            AppConstants.bookingUpcoming,
            AppConstants.bookingCompleted,
          ],
        )
        .orderBy('startTime')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => BookingModel.fromJson({...d.data(), 'id': d.id}))
              .toList(),
        );
  }

  Stream<Map<String, dynamic>> getDailyRevenueStream(
    String venueId,
    DateTime date,
  ) {
    final dateStr = _dateFmt.format(date);
    return _db
        .collection(AppConstants.bookingsCollection)
        .where('venueId', isEqualTo: venueId)
        .where('date', isEqualTo: dateStr)
        .where(
          'status',
          whereIn: [
            AppConstants.bookingUpcoming,
            AppConstants.bookingCompleted,
          ],
        )
        .snapshots()
        .map((snap) {
          final bookings = snap.docs
              .map((d) => BookingModel.fromJson({...d.data(), 'id': d.id}))
              .toList();
          final total = bookings.fold<double>(
            0,
            (sum, b) => sum + b.totalPrice,
          );
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

  Future<List<VenueModel>> getAllVenues() async {
    final snap = await _db.collection(AppConstants.venuesCollection).get();
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

  Future<void> toggleCourtActive(
    String venueId,
    String courtId,
    bool isActive,
  ) async {
    await _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId)
        .update({'isActive': isActive});
  }

  /// Stores the venue's public Google Maps link in Firestore so the
  /// player-facing venue detail screen can open the canonical location URL
  /// instead of constructing one in code.
  Future<void> updateVenueGoogleMapsUrl({
    required String venueId,
    required String googleMapsUrl,
  }) async {
    await _db.collection(AppConstants.venuesCollection).doc(venueId).update({
      'googleMapsUrl': googleMapsUrl.trim(),
    });
  }

  /// Grants [adminPhone] access to the whole venue.
  Future<void> assignVenueAdmin({
    required String venueId,
    required String adminPhone,
  }) async {
    final normalizedPhone = adminPhone.trim();
    final userQuery = await _db
        .collection(AppConstants.usersCollection)
        .where('phone', isEqualTo: normalizedPhone)
        .limit(1)
        .get();
    if (userQuery.docs.isEmpty) {
      throw Exception('No account found for $normalizedPhone');
    }
    final adminUid = userQuery.docs.first.id;
    final venueRef = _db.collection(AppConstants.venuesCollection).doc(venueId);
    final venueSnap = await venueRef.get();
    final venueData = venueSnap.data() ?? <String, dynamic>{};
    final legacyOwnerId = venueData['venueOwnerId'] as String?;
    final legacyOwnerPhone = venueData['venueOwnerPhone'] as String?;
    await venueRef.update({
      'venueOwnerIds': FieldValue.arrayUnion([
        if (legacyOwnerId != null) legacyOwnerId,
        adminUid,
      ]),
      'venueOwnerPhones': FieldValue.arrayUnion([
        if (legacyOwnerPhone != null) legacyOwnerPhone,
        normalizedPhone,
      ]),
      'venueOwnerId': adminUid,
      'venueOwnerPhone': normalizedPhone,
    });
    await _db.collection(AppConstants.usersCollection).doc(adminUid).update({
      'managedVenueIds': FieldValue.arrayUnion([venueId]),
    });
  }

  Future<void> unassignVenueAdmin({
    required String venueId,
    required String adminPhone,
  }) async {
    final venueRef = _db.collection(AppConstants.venuesCollection).doc(venueId);
    final normalizedPhone = adminPhone.trim();
    final userQuery = await _db
        .collection(AppConstants.usersCollection)
        .where('phone', isEqualTo: normalizedPhone)
        .limit(1)
        .get();
    final adminUid = userQuery.docs.isNotEmpty ? userQuery.docs.first.id : null;
    final venueSnap = await venueRef.get();
    final venueData = venueSnap.data() ?? <String, dynamic>{};
    final ownerIds = List<String>.from(
      venueData['venueOwnerIds'] as List? ?? [],
    );
    final ownerPhones = List<String>.from(
      venueData['venueOwnerPhones'] as List? ?? [],
    );
    ownerIds.remove(adminUid);
    ownerPhones.remove(normalizedPhone);

    final updates = <String, dynamic>{
      'venueOwnerIds': FieldValue.arrayRemove([if (adminUid != null) adminUid]),
      'venueOwnerPhones': FieldValue.arrayRemove([normalizedPhone]),
    };
    if (ownerIds.isEmpty && ownerPhones.isEmpty) {
      updates['venueOwnerId'] = FieldValue.delete();
      updates['venueOwnerPhone'] = FieldValue.delete();
    } else if (ownerIds.isNotEmpty && ownerPhones.isNotEmpty) {
      updates['venueOwnerId'] = ownerIds.first;
      updates['venueOwnerPhone'] = ownerPhones.first;
    }
    await venueRef.update(updates);
    if (adminUid != null) {
      await _db.collection(AppConstants.usersCollection).doc(adminUid).update({
        'managedVenueIds': FieldValue.arrayRemove([venueId]),
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
    final snap = await _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .get();
    return snap.data()?['name'] as String? ?? '';
  }

  Future<VenueModel?> getVenue(String venueId) async {
    final snap = await _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .get();
    if (!snap.exists) return null;
    return VenueModel.fromJson({...snap.data()!, 'id': snap.id});
  }

  Stream<Map<String, dynamic>> getCourtDailyStatsStream(
    String courtId,
    DateTime date,
  ) {
    final dateStr = _dateFmt.format(date);
    return _db
        .collection(AppConstants.bookingsCollection)
        .where('courtId', isEqualTo: courtId)
        .where('date', isEqualTo: dateStr)
        .where(
          'status',
          whereIn: [
            AppConstants.bookingUpcoming,
            AppConstants.bookingCompleted,
          ],
        )
        .orderBy('startTime')
        .snapshots()
        .map((snap) {
          final bookings = snap.docs
              .map((d) => BookingModel.fromJson({...d.data(), 'id': d.id}))
              .toList();
          final total = bookings.fold<double>(
            0,
            (sum, b) => sum + b.totalPrice,
          );
          return {
            'total': total,
            'count': bookings.length,
            'bookings': bookings,
          };
        });
  }

  /// Occupancy = booked slots / total slots generated for that court+date.
  Stream<Map<String, int>> getCourtOccupancyStream(
    String venueId,
    String courtId,
    DateTime date,
  ) {
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

  Future<UserModel?> getUserProfile(String uid) async {
    final snap = await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!snap.exists) return null;
    return UserModel.fromJson(snap.data()!);
  }

  /// Most recent bookings [uid] has made at [venueId] — gives the admin quick
  /// context on a customer without exposing their activity at other venues.
  Future<List<BookingModel>> getUserBookingsAtVenue(
    String uid,
    String venueId,
  ) async {
    final snap = await _db
        .collection(AppConstants.bookingsCollection)
        .where('userId', isEqualTo: uid)
        .where('venueId', isEqualTo: venueId)
        .orderBy('startTime', descending: true)
        .limit(10)
        .get();
    return snap.docs
        .map((d) => BookingModel.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }
}
