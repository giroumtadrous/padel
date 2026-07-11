import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';

enum SkillRequestStatus { pending, approved, rejected }

SkillRequestStatus skillRequestStatusFromString(String s) {
  switch (s) {
    case AppConstants.skillRequestApproved:
      return SkillRequestStatus.approved;
    case AppConstants.skillRequestRejected:
      return SkillRequestStatus.rejected;
    default:
      return SkillRequestStatus.pending;
  }
}

String skillRequestStatusToString(SkillRequestStatus s) {
  switch (s) {
    case SkillRequestStatus.approved:
      return AppConstants.skillRequestApproved;
    case SkillRequestStatus.rejected:
      return AppConstants.skillRequestRejected;
    case SkillRequestStatus.pending:
      return AppConstants.skillRequestPending;
  }
}

class SkillRequestModel {
  final String id;
  final String userId;
  final String userName;
  final double currentLevel;
  final double requestedLevel;
  final SkillRequestStatus status;
  final DateTime createdAt;

  const SkillRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.currentLevel,
    required this.requestedLevel,
    this.status = SkillRequestStatus.pending,
    required this.createdAt,
  });

  factory SkillRequestModel.fromJson(Map<String, dynamic> json) => SkillRequestModel(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        userName: json['userName'] as String? ?? '',
        currentLevel: (json['currentLevel'] as num?)?.toDouble() ?? 0.0,
        requestedLevel: (json['requestedLevel'] as num?)?.toDouble() ?? 0.0,
        status: skillRequestStatusFromString(json['status'] as String? ?? AppConstants.skillRequestPending),
        createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'currentLevel': currentLevel,
        'requestedLevel': requestedLevel,
        'status': skillRequestStatusToString(status),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
