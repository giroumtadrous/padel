import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/features/auth/data/models/user_model.dart';
import 'package:padel/features/skill_requests/data/models/skill_request_model.dart';

class SkillRequestService {
  final FirebaseFirestore _db;

  SkillRequestService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<SkillRequestModel>> getPendingRequestsStream() {
    return _db
        .collection(AppConstants.skillRequestsCollection)
        .where('status', isEqualTo: AppConstants.skillRequestPending)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => SkillRequestModel.fromJson(d.data())).toList());
  }

  /// Creates a pending skill-level change request and marks it on the user's
  /// own doc (so the profile screen can show a "pending" state without an
  /// extra query) — the request only takes effect once an admin approves it.
  Future<void> submitRequest({
    required String userId,
    required String userName,
    required double currentLevel,
    required double requestedLevel,
  }) async {
    final userRef = _db.collection(AppConstants.usersCollection).doc(userId);

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw Exception('User profile not found');
      final user = UserModel.fromJson(userSnap.data()!);

      if (user.pendingSkillLevel != null) {
        throw Exception('You already have a pending skill level request');
      }

      final requestRef = _db.collection(AppConstants.skillRequestsCollection).doc();
      final request = SkillRequestModel(
        id: requestRef.id,
        userId: userId,
        userName: userName,
        currentLevel: currentLevel,
        requestedLevel: requestedLevel,
        createdAt: DateTime.now(),
      );

      tx.set(requestRef, request.toJson());
      tx.update(userRef, {'pendingSkillLevel': requestedLevel});
    });
  }

  Future<void> approveRequest(String requestId) async {
    final requestRef = _db.collection(AppConstants.skillRequestsCollection).doc(requestId);

    await _db.runTransaction((tx) async {
      final requestSnap = await tx.get(requestRef);
      if (!requestSnap.exists) throw Exception('Request not found');
      final request = SkillRequestModel.fromJson(requestSnap.data()!);
      if (request.status != SkillRequestStatus.pending) throw Exception('Request already reviewed');

      final userRef = _db.collection(AppConstants.usersCollection).doc(request.userId);

      tx.update(requestRef, {'status': AppConstants.skillRequestApproved});
      tx.update(userRef, {
        'skillLevel': request.requestedLevel,
        'pendingSkillLevel': FieldValue.delete(),
      });
    });
  }

  Future<void> rejectRequest(String requestId) async {
    final requestRef = _db.collection(AppConstants.skillRequestsCollection).doc(requestId);

    await _db.runTransaction((tx) async {
      final requestSnap = await tx.get(requestRef);
      if (!requestSnap.exists) throw Exception('Request not found');
      final request = SkillRequestModel.fromJson(requestSnap.data()!);
      if (request.status != SkillRequestStatus.pending) throw Exception('Request already reviewed');

      final userRef = _db.collection(AppConstants.usersCollection).doc(request.userId);

      tx.update(requestRef, {'status': AppConstants.skillRequestRejected});
      tx.update(userRef, {'pendingSkillLevel': FieldValue.delete()});
    });
  }
}
