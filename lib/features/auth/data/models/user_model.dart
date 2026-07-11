import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String role;
  final double skillLevel;
  final double? pendingSkillLevel;
  final String preferredSide;
  final int matchesPlayed;
  final String? phone;
  final List<String> managedVenueIds;
  // Scoped, per-court admin access — independent of managedVenueIds/role.
  // Each entry is "venueId::courtId" since courts live in a venue subcollection.
  final List<String> managedCourtIds;
  final DateTime createdAt;

  // New features
  final List<String> favoriteVenueIds;
  final double walletBalance;
  final int loyaltyBookingCount;
  final bool loyaltyDiscountEligible;
  final String? fcmToken;
  final bool phoneVerified;
  final bool phoneVerificationSkipped;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.role = AppConstants.rolePlayer,
    this.skillLevel = 3.0,
    this.pendingSkillLevel,
    this.preferredSide = AppConstants.sideForerhand,
    this.matchesPlayed = 0,
    this.phone,
    this.managedVenueIds = const [],
    this.managedCourtIds = const [],
    required this.createdAt,
    this.favoriteVenueIds = const [],
    this.walletBalance = 0.0,
    this.loyaltyBookingCount = 0,
    this.loyaltyDiscountEligible = false,
    this.fcmToken,
    this.phoneVerified = false,
    this.phoneVerificationSkipped = false,
  });

  bool get isAdmin => role == AppConstants.roleAdmin;

  /// True if this account can reach the admin dashboard in any capacity —
  /// either a full venue admin (role == 'admin') or a scoped single-court
  /// admin (managedCourtIds non-empty), which never changes `role`.
  bool get hasAdminAccess => isAdmin || managedCourtIds.isNotEmpty;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      role: json['role'] as String? ?? AppConstants.rolePlayer,
      skillLevel: (json['skillLevel'] as num?)?.toDouble() ?? 3.0,
      pendingSkillLevel: (json['pendingSkillLevel'] as num?)?.toDouble(),
      preferredSide: json['preferredSide'] as String? ?? AppConstants.sideForerhand,
      matchesPlayed: json['matchesPlayed'] as int? ?? 0,
      phone: json['phone'] as String?,
      managedVenueIds: List<String>.from(json['managedVenueIds'] as List? ?? []),
      managedCourtIds: List<String>.from(json['managedCourtIds'] as List? ?? []),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      favoriteVenueIds: List<String>.from(json['favoriteVenueIds'] as List? ?? []),
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.0,
      loyaltyBookingCount: json['loyaltyBookingCount'] as int? ?? 0,
      loyaltyDiscountEligible: json['loyaltyDiscountEligible'] as bool? ?? false,
      fcmToken: json['fcmToken'] as String?,
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      phoneVerificationSkipped: json['phoneVerificationSkipped'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'role': role,
        'skillLevel': skillLevel,
        'pendingSkillLevel': pendingSkillLevel,
        'preferredSide': preferredSide,
        'matchesPlayed': matchesPlayed,
        'phone': phone,
        'managedVenueIds': managedVenueIds,
        'managedCourtIds': managedCourtIds,
        'createdAt': Timestamp.fromDate(createdAt),
        'favoriteVenueIds': favoriteVenueIds,
        'walletBalance': walletBalance,
        'loyaltyBookingCount': loyaltyBookingCount,
        'loyaltyDiscountEligible': loyaltyDiscountEligible,
        'fcmToken': fcmToken,
        'phoneVerified': phoneVerified,
        'phoneVerificationSkipped': phoneVerificationSkipped,
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
    List<String>? favoriteVenueIds,
    double? walletBalance,
    int? loyaltyBookingCount,
    bool? loyaltyDiscountEligible,
    String? fcmToken,
    bool? phoneVerified,
    bool? phoneVerificationSkipped,
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
      favoriteVenueIds: favoriteVenueIds ?? this.favoriteVenueIds,
      walletBalance: walletBalance ?? this.walletBalance,
      loyaltyBookingCount: loyaltyBookingCount ?? this.loyaltyBookingCount,
      loyaltyDiscountEligible: loyaltyDiscountEligible ?? this.loyaltyDiscountEligible,
      fcmToken: fcmToken ?? this.fcmToken,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      phoneVerificationSkipped: phoneVerificationSkipped ?? this.phoneVerificationSkipped,
    );
  }
}
