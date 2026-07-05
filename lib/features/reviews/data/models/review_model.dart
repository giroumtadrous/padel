import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String userId;
  final String userDisplayName;
  final String venueId;
  final String bookingId;
  final int rating; // 1-5
  final String comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.venueId,
    required this.bookingId,
    required this.rating,
    this.comment = '',
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        userDisplayName: json['userDisplayName'] as String? ?? '',
        venueId: json['venueId'] as String? ?? '',
        bookingId: json['bookingId'] as String? ?? '',
        rating: json['rating'] as int? ?? 5,
        comment: json['comment'] as String? ?? '',
        createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userDisplayName': userDisplayName,
        'venueId': venueId,
        'bookingId': bookingId,
        'rating': rating,
        'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
