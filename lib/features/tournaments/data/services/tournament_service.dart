import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/features/auth/data/models/user_model.dart';
import 'package:padel/features/tournaments/data/models/tournament_model.dart';

class TournamentService {
  final FirebaseFirestore _db;

  TournamentService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<TournamentModel>> getTournamentsStream() {
    return _db
        .collection(AppConstants.tournamentsCollection)
        .where('status', isEqualTo: AppConstants.tournamentScheduled)
        .orderBy('startTime')
        .snapshots()
        .map((snap) => snap.docs.map((d) => TournamentModel.fromJson(d.data())).toList());
  }

  Future<String> createTournament(TournamentModel tournament) async {
    final ref = _db.collection(AppConstants.tournamentsCollection).doc();
    final withId = TournamentModel(
      id: ref.id,
      name: tournament.name,
      description: tournament.description,
      venueId: tournament.venueId,
      venueName: tournament.venueName,
      adminId: tournament.adminId,
      startTime: tournament.startTime,
      entryFee: tournament.entryFee,
      maxParticipants: tournament.maxParticipants,
      minSkillLevel: tournament.minSkillLevel,
      maxSkillLevel: tournament.maxSkillLevel,
      createdAt: DateTime.now(),
    );
    await ref.set(withId.toJson());
    return ref.id;
  }

  Future<List<TournamentModel>> getAdminTournaments(String adminId) async {
    final snap = await _db
        .collection(AppConstants.tournamentsCollection)
        .where('adminId', isEqualTo: adminId)
        .get();
    return snap.docs.map((d) => TournamentModel.fromJson(d.data())).toList();
  }

  Future<void> cancelTournament(String tournamentId, String adminId) async {
    final ref = _db.collection(AppConstants.tournamentsCollection).doc(tournamentId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Tournament not found');

    final tournament = TournamentModel.fromJson(snap.data()!);
    if (tournament.adminId != adminId) throw Exception('Only the organizing admin can cancel');

    await ref.update({'status': AppConstants.tournamentCancelled});
  }

  /// Joins a tournament and deducts the entry fee from the user's wallet in
  /// the same transaction, so a player is never charged without a confirmed
  /// slot (or vice versa).
  Future<void> joinTournament(String tournamentId, String userId) async {
    final tournamentRef = _db.collection(AppConstants.tournamentsCollection).doc(tournamentId);
    final userRef = _db.collection(AppConstants.usersCollection).doc(userId);

    await _db.runTransaction((tx) async {
      final tournamentSnap = await tx.get(tournamentRef);
      if (!tournamentSnap.exists) throw Exception('Tournament not found');
      final tournament = TournamentModel.fromJson(tournamentSnap.data()!);

      if (tournament.participantIds.contains(userId)) {
        throw Exception('Already joined this tournament');
      }
      if (tournament.isFull) throw Exception('Tournament is full');
      if (tournament.status != TournamentStatus.scheduled) {
        throw Exception('Tournament is no longer open');
      }

      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw Exception('User profile not found');
      final user = UserModel.fromJson(userSnap.data()!);

      if (user.skillLevel < tournament.minSkillLevel || user.skillLevel > tournament.maxSkillLevel) {
        throw Exception('Your skill level does not meet this tournament\'s requirements');
      }
      if (user.walletBalance < tournament.entryFee) {
        throw Exception('Insufficient wallet balance for the entry fee');
      }

      tx.update(tournamentRef, {
        'participantIds': FieldValue.arrayUnion([userId]),
      });
      tx.update(userRef, {
        'walletBalance': FieldValue.increment(-tournament.entryFee),
      });
    });
  }
}
