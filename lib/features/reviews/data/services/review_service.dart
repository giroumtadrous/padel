import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/features/reviews/data/models/review_model.dart';
import 'package:uuid/uuid.dart';

class ReviewService {
  final FirebaseFirestore _db;
  static const _uuid = Uuid();

  ReviewService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  /// Submits a review and updates the venue's average rating.
  Future<ReviewModel> submitReview({
    required String userId,
    required String userDisplayName,
    required String venueId,
    required String bookingId,
    required int rating,
    String comment = '',
  }) async {
    final reviewId = _uuid.v4();
    final review = ReviewModel(
      id: reviewId,
      userId: userId,
      userDisplayName: userDisplayName,
      venueId: venueId,
      bookingId: bookingId,
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
    );

    await _db.collection(AppConstants.reviewsCollection).doc(reviewId).set(review.toJson());

    // Update venue average rating
    await _updateVenueRating(venueId);

    return review;
  }

  Future<void> _updateVenueRating(String venueId) async {
    final snap = await _db
        .collection(AppConstants.reviewsCollection)
        .where('venueId', isEqualTo: venueId)
        .get();

    if (snap.docs.isEmpty) return;

    final ratings = snap.docs
        .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 5.0)
        .toList();

    final avg = ratings.reduce((a, b) => a + b) / ratings.length;

    await _db
        .collection(AppConstants.venuesCollection)
        .doc(venueId)
        .update({
      'rating': double.parse(avg.toStringAsFixed(1)),
      'reviewCount': ratings.length,
    });
  }

  Stream<List<ReviewModel>> getVenueReviews(String venueId) {
    return _db
        .collection(AppConstants.reviewsCollection)
        .where('venueId', isEqualTo: venueId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReviewModel.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

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
