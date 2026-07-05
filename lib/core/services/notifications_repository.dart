import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final bool read;
  final String? bookingId;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.read,
    this.bookingId,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        read: json['read'] as bool? ?? false,
        bookingId: json['bookingId'] as String?,
        createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

/// Lightweight, client-only notifications: written whenever an admin action
/// (currently only payment verification) produces an outcome the user should
/// see. There is no Cloud Functions project behind this, so nothing is
/// pushed to a closed app — this is read the next time the app is open.
class NotificationsRepository {
  final FirebaseFirestore _db;

  NotificationsRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<AppNotification>> userNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppNotification.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<void> markRead(String notificationId) {
    return _db.collection('notifications').doc(notificationId).update({'read': true});
  }
}
