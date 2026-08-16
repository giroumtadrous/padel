import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/features/venues/data/models/court_model.dart';
import 'package:padel/features/venues/data/models/venue_model.dart';

class VenueService {
  final FirebaseFirestore _db;

  VenueService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<VenueModel>> getVenuesStream() {
    return _db
        .collection(AppConstants.venuesCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => VenueModel.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<VenueModel> getVenue(String venueId) async {
    final doc = await _db.collection(AppConstants.venuesCollection).doc(venueId).get();
    if (!doc.exists) throw Exception('Venue not found');
    return VenueModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  Stream<List<CourtModel>> getCourtsStream(String venueId) {
    return _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CourtModel.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<List<CourtModel>> getVenueCourts(String venueId) async {
    final snap = await _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .get();
    return snap.docs
        .map((d) => CourtModel.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  Future<CourtModel> getCourt(String venueId, String courtId) async {
    final doc = await _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(courtId)
        .get();
    if (!doc.exists) throw Exception('Court not found');
    return CourtModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  // Admin operations

  Future<String> addVenue(VenueModel venue) async {
    final ref = _db.collection(AppConstants.venuesCollection).doc();
    final withId = VenueModel(
      id: ref.id,
      name: venue.name,
      description: venue.description,
      address: venue.address,
      city: venue.city,
      googleMapsUrl: venue.googleMapsUrl,
      latitude: venue.latitude,
      longitude: venue.longitude,
      imageUrls: venue.imageUrls,
      amenities: venue.amenities,
      openingHour: venue.openingHour,
      closingHour: venue.closingHour,
      rating: venue.rating,
      reviewCount: venue.reviewCount,
      adminId: venue.adminId,
      createdAt: DateTime.now(),
    );
    await ref.set(withId.toJson());
    return ref.id;
  }

  Future<String> addCourt(String venueId, CourtModel court) async {
    final ref = _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc();
    final withId = CourtModel(
      id: ref.id,
      venueId: venueId,
      name: court.name,
      courtType: court.courtType,
      surface: court.surface,
      imageUrl: court.imageUrl,
      peakHourPrice: court.peakHourPrice,
      offPeakPrice: court.offPeakPrice,
      peakStartHour: court.peakStartHour,
      peakEndHour: court.peakEndHour,
    );
    await ref.set(withId.toJson());
    return ref.id;
  }

  Future<void> updateCourt(String venueId, CourtModel court) async {
    await _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .collection(AppConstants.courtsSubcollection)
        .doc(court.id)
        .update(court.toJson());
  }
}
