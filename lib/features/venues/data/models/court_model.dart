import 'package:cloud_firestore/cloud_firestore.dart';

class CourtModel {
  final String id;
  final String venueId;
  final String name;
  final String courtType;
  final String surface;
  final String? imageUrl;
  final double peakHourPrice;
  final double offPeakPrice;
  final int peakStartHour;
  final int peakEndHour;
  final bool isActive;
  final String? maintenanceNote;
  final List<DateTime> blockedDates;

  const CourtModel({
    required this.id,
    required this.venueId,
    required this.name,
    this.courtType = 'indoor',
    this.surface = 'glass',
    this.imageUrl,
    required this.peakHourPrice,
    required this.offPeakPrice,
    this.peakStartHour = 17,
    this.peakEndHour = 22,
    this.isActive = true,
    this.maintenanceNote,
    this.blockedDates = const [],
  });

  double priceForHour(int hour) =>
      (hour >= peakStartHour && hour < peakEndHour) ? peakHourPrice : offPeakPrice;

  bool isPeak(int hour) => hour >= peakStartHour && hour < peakEndHour;

  bool isDateBlocked(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return blockedDates.any((d) =>
        d.year == normalized.year &&
        d.month == normalized.month &&
        d.day == normalized.day);
  }

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    List<DateTime> blocked = [];
    if (json['blockedDates'] is List) {
      for (final item in json['blockedDates'] as List) {
        if (item is Timestamp) {
          blocked.add(item.toDate());
        } else if (item is String) {
          blocked.add(DateTime.tryParse(item) ?? DateTime(2000));
        }
      }
    }

    return CourtModel(
      id: json['id'] as String? ?? '',
      venueId: json['venueId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      courtType: json['courtType'] as String? ?? 'indoor',
      surface: json['surface'] as String? ?? 'glass',
      imageUrl: json['imageUrl'] as String?,
      peakHourPrice: (json['peakHourPrice'] as num?)?.toDouble() ?? 150.0,
      offPeakPrice: (json['offPeakPrice'] as num?)?.toDouble() ?? 90.0,
      peakStartHour: json['peakStartHour'] as int? ?? 17,
      peakEndHour: json['peakEndHour'] as int? ?? 22,
      isActive: json['isActive'] as bool? ?? true,
      maintenanceNote: json['maintenanceNote'] as String?,
      blockedDates: blocked,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'venueId': venueId,
        'name': name,
        'courtType': courtType,
        'surface': surface,
        'imageUrl': imageUrl,
        'peakHourPrice': peakHourPrice,
        'offPeakPrice': offPeakPrice,
        'peakStartHour': peakStartHour,
        'peakEndHour': peakEndHour,
        'isActive': isActive,
        'maintenanceNote': maintenanceNote,
        'blockedDates': blockedDates
            .map((d) => Timestamp.fromDate(d))
            .toList(),
      };

  CourtModel copyWith({
    String? name,
    String? courtType,
    String? surface,
    String? imageUrl,
    double? peakHourPrice,
    double? offPeakPrice,
    int? peakStartHour,
    int? peakEndHour,
    bool? isActive,
    String? maintenanceNote,
    List<DateTime>? blockedDates,
  }) {
    return CourtModel(
      id: id,
      venueId: venueId,
      name: name ?? this.name,
      courtType: courtType ?? this.courtType,
      surface: surface ?? this.surface,
      imageUrl: imageUrl ?? this.imageUrl,
      peakHourPrice: peakHourPrice ?? this.peakHourPrice,
      offPeakPrice: offPeakPrice ?? this.offPeakPrice,
      peakStartHour: peakStartHour ?? this.peakStartHour,
      peakEndHour: peakEndHour ?? this.peakEndHour,
      isActive: isActive ?? this.isActive,
      maintenanceNote: maintenanceNote ?? this.maintenanceNote,
      blockedDates: blockedDates ?? this.blockedDates,
    );
  }
}
