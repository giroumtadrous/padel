import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String role;
  final double skillLevel;
  final String preferredSide;
  final int matchesPlayed;
  final String? phone;
  final List<String> managedVenueIds;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.role = AppConstants.rolePlayer,
    this.skillLevel = 3.0,
    this.preferredSide = AppConstants.sideForerhand,
    this.matchesPlayed = 0,
    this.phone,
    this.managedVenueIds = const [],
    required this.createdAt,
  });

  bool get isAdmin => role == AppConstants.roleAdmin;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      role: json['role'] as String? ?? AppConstants.rolePlayer,
      skillLevel: (json['skillLevel'] as num?)?.toDouble() ?? 3.0,
      preferredSide: json['preferredSide'] as String? ?? AppConstants.sideForerhand,
      matchesPlayed: json['matchesPlayed'] as int? ?? 0,
      phone: json['phone'] as String?,
      managedVenueIds: List<String>.from(json['managedVenueIds'] as List? ?? []),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'role': role,
        'skillLevel': skillLevel,
        'preferredSide': preferredSide,
        'matchesPlayed': matchesPlayed,
        'phone': phone,
        'managedVenueIds': managedVenueIds,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    String? role,
    double? skillLevel,
    String? preferredSide,
    int? matchesPlayed,
    String? phone,
    List<String>? managedVenueIds,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      skillLevel: skillLevel ?? this.skillLevel,
      preferredSide: preferredSide ?? this.preferredSide,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      phone: phone ?? this.phone,
      managedVenueIds: managedVenueIds ?? this.managedVenueIds,
      createdAt: createdAt,
    );
  }
}
