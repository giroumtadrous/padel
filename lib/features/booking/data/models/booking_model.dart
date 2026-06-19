import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';

enum BookingStatus { upcoming, completed, cancelled }

BookingStatus bookingStatusFromString(String s) {
  switch (s) {
    case AppConstants.bookingCompleted:
      return BookingStatus.completed;
    case AppConstants.bookingCancelled:
      return BookingStatus.cancelled;
    default:
      return BookingStatus.upcoming;
  }
}

String bookingStatusToString(BookingStatus s) {
  switch (s) {
    case BookingStatus.completed:
      return AppConstants.bookingCompleted;
    case BookingStatus.cancelled:
      return AppConstants.bookingCancelled;
    case BookingStatus.upcoming:
      return AppConstants.bookingUpcoming;
  }
}

class BookingModel {
  final String id;
  final String userId;
  final String courtId;
  final String venueId;
  final String venueName;
  final String courtName;
  final String slotId;
  final String date;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final double totalPrice;
  final BookingStatus status;
  final bool isOpenMatch;
  final String? openMatchId;
  final String paymentStatus;
  final DateTime createdAt;
  final DateTime? cancelledAt;

  const BookingModel({
    required this.id,
    required this.userId,
    required this.courtId,
    required this.venueId,
    required this.venueName,
    required this.courtName,
    required this.slotId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.totalPrice,
    this.status = BookingStatus.upcoming,
    this.isOpenMatch = false,
    this.openMatchId,
    this.paymentStatus = 'paid',
    required this.createdAt,
    this.cancelledAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        courtId: json['courtId'] as String? ?? '',
        venueId: json['venueId'] as String? ?? '',
        venueName: json['venueName'] as String? ?? '',
        courtName: json['courtName'] as String? ?? '',
        slotId: json['slotId'] as String? ?? '',
        date: json['date'] as String? ?? '',
        startTime: (json['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endTime: (json['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        durationMinutes: json['durationMinutes'] as int? ?? 60,
        totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
        status: bookingStatusFromString(json['status'] as String? ?? AppConstants.bookingUpcoming),
        isOpenMatch: json['isOpenMatch'] as bool? ?? false,
        openMatchId: json['openMatchId'] as String?,
        paymentStatus: json['paymentStatus'] as String? ?? 'paid',
        createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        cancelledAt: json['cancelledAt'] != null
            ? (json['cancelledAt'] as Timestamp).toDate()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'courtId': courtId,
        'venueId': venueId,
        'venueName': venueName,
        'courtName': courtName,
        'slotId': slotId,
        'date': date,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'durationMinutes': durationMinutes,
        'totalPrice': totalPrice,
        'status': bookingStatusToString(status),
        'isOpenMatch': isOpenMatch,
        'openMatchId': openMatchId,
        'paymentStatus': paymentStatus,
        'createdAt': Timestamp.fromDate(createdAt),
        'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      };

  BookingModel copyWith({
    BookingStatus? status,
    bool? isOpenMatch,
    String? openMatchId,
    DateTime? cancelledAt,
  }) {
    return BookingModel(
      id: id,
      userId: userId,
      courtId: courtId,
      venueId: venueId,
      venueName: venueName,
      courtName: courtName,
      slotId: slotId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      totalPrice: totalPrice,
      status: status ?? this.status,
      isOpenMatch: isOpenMatch ?? this.isOpenMatch,
      openMatchId: openMatchId ?? this.openMatchId,
      paymentStatus: paymentStatus,
      createdAt: createdAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }
}
