import 'package:cloud_firestore/cloud_firestore.dart';

class VenueAmenities {
  final bool hasShowers;
  final bool hasRacketRental;
  final bool hasParking;
  final bool hasCafe;

  const VenueAmenities({
    this.hasShowers = false,
    this.hasRacketRental = false,
    this.hasParking = false,
    this.hasCafe = false,
  });

  factory VenueAmenities.fromJson(Map<String, dynamic> json) => VenueAmenities(
        hasShowers: json['hasShowers'] as bool? ?? false,
        hasRacketRental: json['hasRacketRental'] as bool? ?? false,
        hasParking: json['hasParking'] as bool? ?? false,
        hasCafe: json['hasCafe'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'hasShowers': hasShowers,
        'hasRacketRental': hasRacketRental,
        'hasParking': hasParking,
        'hasCafe': hasCafe,
      };
}

class VenueModel {
  final String id;
  final String name;
  final String description;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final List<String> imageUrls;
  final VenueAmenities amenities;
  final int openingHour;
  final int closingHour;
  final double rating;
  final int reviewCount;
  final String adminId;
  final bool isActive;
  final DateTime createdAt;

  const VenueModel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.imageUrls = const [],
    required this.amenities,
    this.openingHour = 7,
    this.closingHour = 23,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.adminId,
    this.isActive = true,
    required this.createdAt,
  });

  factory VenueModel.fromJson(Map<String, dynamic> json) => VenueModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        address: json['address'] as String,
        city: json['city'] as String,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        imageUrls: List<String>.from(json['imageUrls'] as List? ?? []),
        amenities: VenueAmenities.fromJson(
          json['amenities'] as Map<String, dynamic>? ?? {},
        ),
        openingHour: json['openingHour'] as int? ?? 7,
        closingHour: json['closingHour'] as int? ?? 23,
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: json['reviewCount'] as int? ?? 0,
        adminId: json['adminId'] as String,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: (json['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'address': address,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'imageUrls': imageUrls,
        'amenities': amenities.toJson(),
        'openingHour': openingHour,
        'closingHour': closingHour,
        'rating': rating,
        'reviewCount': reviewCount,
        'adminId': adminId,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
