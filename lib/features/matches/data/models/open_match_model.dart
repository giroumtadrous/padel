import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';

enum MatchStatus { open, full, cancelled, completed }

MatchStatus matchStatusFromString(String s) {
  switch (s) {
    case AppConstants.matchFull:
      return MatchStatus.full;
    case AppConstants.matchCancelled:
      return MatchStatus.cancelled;
    case AppConstants.matchCompleted:
      return MatchStatus.completed;
    default:
      return MatchStatus.open;
  }
}

String matchStatusToString(MatchStatus s) {
  switch (s) {
    case MatchStatus.full:
      return AppConstants.matchFull;
    case MatchStatus.cancelled:
      return AppConstants.matchCancelled;
    case MatchStatus.completed:
      return AppConstants.matchCompleted;
    case MatchStatus.open:
      return AppConstants.matchOpen;
  }
}

class OpenMatchModel {
  final String id;
  final String bookingId;
  final String courtId;
  final String venueId;
  final String venueName;
  final String courtName;
  final String organizerId;
  final String organizerName;
  final String date;
  final DateTime startTime;
  final DateTime endTime;
  final int totalSlots;
  final int filledSlots;
  final List<String> participantIds;
  final double minSkillLevel;
  final double maxSkillLevel;
  final double pricePerPlayer;
  final String description;
  final MatchStatus status;
  final DateTime createdAt;

  const OpenMatchModel({
    required this.id,
    required this.bookingId,
    required this.courtId,
    required this.venueId,
    required this.venueName,
    required this.courtName,
    required this.organizerId,
    required this.organizerName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.totalSlots = AppConstants.maxMatchPlayers,
    this.filledSlots = 1,
    this.participantIds = const [],
    this.minSkillLevel = 1.0,
    this.maxSkillLevel = 7.0,
    required this.pricePerPlayer,
    this.description = '',
    this.status = MatchStatus.open,
    required this.createdAt,
  });

  int get openSlots => totalSlots - filledSlots;
  bool get isFull => filledSlots >= totalSlots;

  bool canJoin(double userSkill) =>
      userSkill >= minSkillLevel && userSkill <= maxSkillLevel && !isFull && status == MatchStatus.open;

  factory OpenMatchModel.fromJson(Map<String, dynamic> json) => OpenMatchModel(
        id: json['id'] as String? ?? '',
        bookingId: json['bookingId'] as String? ?? '',
        courtId: json['courtId'] as String? ?? '',
        venueId: json['venueId'] as String? ?? '',
        venueName: json['venueName'] as String? ?? '',
        courtName: json['courtName'] as String? ?? '',
        organizerId: json['organizerId'] as String? ?? '',
        organizerName: json['organizerName'] as String? ?? '',
        date: json['date'] as String? ?? '',
        startTime: (json['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endTime: (json['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        totalSlots: json['totalSlots'] as int? ?? AppConstants.maxMatchPlayers,
        filledSlots: json['filledSlots'] as int? ?? 1,
        participantIds: List<String>.from(json['participantIds'] as List? ?? []),
        minSkillLevel: (json['minSkillLevel'] as num?)?.toDouble() ?? 1.0,
        maxSkillLevel: (json['maxSkillLevel'] as num?)?.toDouble() ?? 7.0,
        pricePerPlayer: (json['pricePerPlayer'] as num?)?.toDouble() ?? 0.0,
        description: json['description'] as String? ?? '',
        status: matchStatusFromString(json['status'] as String? ?? AppConstants.matchOpen),
        createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookingId': bookingId,
        'courtId': courtId,
        'venueId': venueId,
        'venueName': venueName,
        'courtName': courtName,
        'organizerId': organizerId,
        'organizerName': organizerName,
        'date': date,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'totalSlots': totalSlots,
        'filledSlots': filledSlots,
        'participantIds': participantIds,
        'minSkillLevel': minSkillLevel,
        'maxSkillLevel': maxSkillLevel,
        'pricePerPlayer': pricePerPlayer,
        'description': description,
        'status': matchStatusToString(status),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
