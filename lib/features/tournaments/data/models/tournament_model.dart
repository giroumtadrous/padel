import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';

enum TournamentStatus { scheduled, cancelled, completed }

TournamentStatus tournamentStatusFromString(String s) {
  switch (s) {
    case AppConstants.tournamentCancelled:
      return TournamentStatus.cancelled;
    case AppConstants.tournamentCompleted:
      return TournamentStatus.completed;
    default:
      return TournamentStatus.scheduled;
  }
}

String tournamentStatusToString(TournamentStatus s) {
  switch (s) {
    case TournamentStatus.cancelled:
      return AppConstants.tournamentCancelled;
    case TournamentStatus.completed:
      return AppConstants.tournamentCompleted;
    case TournamentStatus.scheduled:
      return AppConstants.tournamentScheduled;
  }
}

class TournamentModel {
  final String id;
  final String name;
  final String description;
  final String venueId;
  final String venueName;
  final String adminId;
  final DateTime startTime;
  final double entryFee;
  final int maxParticipants;
  final List<String> participantIds;
  final double minSkillLevel;
  final double maxSkillLevel;
  final TournamentStatus status;
  final DateTime createdAt;

  const TournamentModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.venueId,
    required this.venueName,
    required this.adminId,
    required this.startTime,
    required this.entryFee,
    this.maxParticipants = 16,
    this.participantIds = const [],
    this.minSkillLevel = AppConstants.minSkillLevel,
    this.maxSkillLevel = AppConstants.maxSkillLevel,
    this.status = TournamentStatus.scheduled,
    required this.createdAt,
  });

  bool get isFull => participantIds.length >= maxParticipants;

  bool canJoin(double userSkill) =>
      userSkill >= minSkillLevel &&
      userSkill <= maxSkillLevel &&
      !isFull &&
      status == TournamentStatus.scheduled &&
      startTime.isAfter(DateTime.now());

  factory TournamentModel.fromJson(Map<String, dynamic> json) => TournamentModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        venueId: json['venueId'] as String? ?? '',
        venueName: json['venueName'] as String? ?? '',
        adminId: json['adminId'] as String? ?? '',
        startTime: (json['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        entryFee: (json['entryFee'] as num?)?.toDouble() ?? 0.0,
        maxParticipants: json['maxParticipants'] as int? ?? 16,
        participantIds: List<String>.from(json['participantIds'] as List? ?? []),
        minSkillLevel: (json['minSkillLevel'] as num?)?.toDouble() ?? AppConstants.minSkillLevel,
        maxSkillLevel: (json['maxSkillLevel'] as num?)?.toDouble() ?? AppConstants.maxSkillLevel,
        status: tournamentStatusFromString(json['status'] as String? ?? AppConstants.tournamentScheduled),
        createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'venueId': venueId,
        'venueName': venueName,
        'adminId': adminId,
        'startTime': Timestamp.fromDate(startTime),
        'entryFee': entryFee,
        'maxParticipants': maxParticipants,
        'participantIds': participantIds,
        'minSkillLevel': minSkillLevel,
        'maxSkillLevel': maxSkillLevel,
        'status': tournamentStatusToString(status),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
