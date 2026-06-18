import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';

enum SlotStatus { available, held, booked, maintenance }

SlotStatus slotStatusFromString(String s) {
  switch (s) {
    case AppConstants.statusHeld:
      return SlotStatus.held;
    case AppConstants.statusBooked:
      return SlotStatus.booked;
    case AppConstants.statusMaintenance:
      return SlotStatus.maintenance;
    default:
      return SlotStatus.available;
  }
}

String slotStatusToString(SlotStatus s) {
  switch (s) {
    case SlotStatus.held:
      return AppConstants.statusHeld;
    case SlotStatus.booked:
      return AppConstants.statusBooked;
    case SlotStatus.maintenance:
      return AppConstants.statusMaintenance;
    case SlotStatus.available:
      return AppConstants.statusAvailable;
  }
}

class TimeSlotModel {
  final String id;
  final String courtId;
  final String venueId;
  final String date;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final SlotStatus status;
  final double price;
  final bool isPeakHour;
  final String? bookingId;
  final String? heldBy;
  final DateTime? heldUntil;

  const TimeSlotModel({
    required this.id,
    required this.courtId,
    required this.venueId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.status = SlotStatus.available,
    required this.price,
    this.isPeakHour = false,
    this.bookingId,
    this.heldBy,
    this.heldUntil,
  });

  bool get isAvailable => status == SlotStatus.available;

  bool get isHeldByOther => status == SlotStatus.held;

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) => TimeSlotModel(
        id: json['id'] as String,
        courtId: json['courtId'] as String,
        venueId: json['venueId'] as String,
        date: json['date'] as String,
        startTime: (json['startTime'] as Timestamp).toDate(),
        endTime: (json['endTime'] as Timestamp).toDate(),
        durationMinutes: json['durationMinutes'] as int,
        status: slotStatusFromString(json['status'] as String? ?? AppConstants.statusAvailable),
        price: (json['price'] as num).toDouble(),
        isPeakHour: json['isPeakHour'] as bool? ?? false,
        bookingId: json['bookingId'] as String?,
        heldBy: json['heldBy'] as String?,
        heldUntil: json['heldUntil'] != null
            ? (json['heldUntil'] as Timestamp).toDate()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'courtId': courtId,
        'venueId': venueId,
        'date': date,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'durationMinutes': durationMinutes,
        'status': slotStatusToString(status),
        'price': price,
        'isPeakHour': isPeakHour,
        'bookingId': bookingId,
        'heldBy': heldBy,
        'heldUntil': heldUntil != null ? Timestamp.fromDate(heldUntil!) : null,
      };

  TimeSlotModel copyWith({
    SlotStatus? status,
    String? bookingId,
    String? heldBy,
    DateTime? heldUntil,
  }) {
    return TimeSlotModel(
      id: id,
      courtId: courtId,
      venueId: venueId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      status: status ?? this.status,
      price: price,
      isPeakHour: isPeakHour,
      bookingId: bookingId ?? this.bookingId,
      heldBy: heldBy ?? this.heldBy,
      heldUntil: heldUntil ?? this.heldUntil,
    );
  }
}
