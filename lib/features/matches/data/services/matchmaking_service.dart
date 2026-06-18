import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/features/matches/data/models/open_match_model.dart';

class MatchmakingService {
  final FirebaseFirestore _db;

  MatchmakingService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<OpenMatchModel>> getOpenMatchesStream({
    double? minSkill,
    double? maxSkill,
  }) {
    // Skill filtering is done client-side: Firestore forbids an inequality
    // filter (>=) after orderBy on a *different* field in the same query.
    return _db
        .collection(AppConstants.openMatchesCollection)
        .where('status', isEqualTo: AppConstants.matchOpen)
        .orderBy('startTime')
        .snapshots()
        .map((snap) {
      var matches = snap.docs.map((d) => OpenMatchModel.fromJson(d.data())).toList();
      if (minSkill != null) {
        matches = matches.where((m) => m.maxSkillLevel >= minSkill).toList();
      }
      if (maxSkill != null) {
        matches = matches.where((m) => m.minSkillLevel <= maxSkill).toList();
      }
      return matches;
    });
  }

  Stream<OpenMatchModel> getMatchStream(String matchId) {
    return _db
        .collection(AppConstants.openMatchesCollection)
        .doc(matchId)
        .snapshots()
        .map((snap) => OpenMatchModel.fromJson(snap.data()!));
  }

  Future<String> createOpenMatch(OpenMatchModel match) async {
    final ref = _db.collection(AppConstants.openMatchesCollection).doc();
    final withId = OpenMatchModel(
      id: ref.id,
      bookingId: match.bookingId,
      courtId: match.courtId,
      venueId: match.venueId,
      venueName: match.venueName,
      courtName: match.courtName,
      organizerId: match.organizerId,
      organizerName: match.organizerName,
      date: match.date,
      startTime: match.startTime,
      endTime: match.endTime,
      totalSlots: match.totalSlots,
      filledSlots: match.filledSlots,
      participantIds: match.participantIds,
      minSkillLevel: match.minSkillLevel,
      maxSkillLevel: match.maxSkillLevel,
      pricePerPlayer: match.pricePerPlayer,
      description: match.description,
      createdAt: DateTime.now(),
    );
    await ref.set(withId.toJson());
    return ref.id;
  }

  Future<void> joinMatch(String matchId, String userId) async {
    final ref = _db.collection(AppConstants.openMatchesCollection).doc(matchId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Match not found');

      final match = OpenMatchModel.fromJson(snap.data()!);

      if (match.participantIds.contains(userId)) {
        throw Exception('Already joined this match');
      }
      if (match.isFull) throw Exception('Match is full');
      if (match.status != MatchStatus.open) throw Exception('Match is no longer open');

      final newFilled = match.filledSlots + 1;
      tx.update(ref, {
        'filledSlots': newFilled,
        'participantIds': FieldValue.arrayUnion([userId]),
        'status': newFilled >= match.totalSlots ? AppConstants.matchFull : AppConstants.matchOpen,
      });
    });
  }

  Future<void> leaveMatch(String matchId, String userId) async {
    final ref = _db.collection(AppConstants.openMatchesCollection).doc(matchId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Match not found');

      final match = OpenMatchModel.fromJson(snap.data()!);

      if (!match.participantIds.contains(userId)) return;

      tx.update(ref, {
        'filledSlots': match.filledSlots - 1,
        'participantIds': FieldValue.arrayRemove([userId]),
        'status': AppConstants.matchOpen,
      });
    });
  }

  Future<void> cancelMatch(String matchId, String organizerId) async {
    final ref = _db.collection(AppConstants.openMatchesCollection).doc(matchId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Match not found');

    final match = OpenMatchModel.fromJson(snap.data()!);
    if (match.organizerId != organizerId) throw Exception('Only the organizer can cancel');

    await ref.update({'status': AppConstants.matchCancelled});
  }
}
