import 'package:equatable/equatable.dart';
import 'package:padel/features/venues/data/models/court_model.dart';

abstract class AdminEvent extends Equatable {
  const AdminEvent();
  @override
  List<Object?> get props => [];
}

class LoadAdminDashboard extends AdminEvent {
  final String adminId;
  final String venueId;
  final DateTime date;
  const LoadAdminDashboard({required this.adminId, required this.venueId, required this.date});
  @override
  List<Object?> get props => [adminId, venueId, date];
}

class ChangeDashboardDate extends AdminEvent {
  final DateTime date;
  const ChangeDashboardDate(this.date);
  @override
  List<Object?> get props => [date];
}

class BlockSlot extends AdminEvent {
  final String venueId;
  final String courtId;
  final String date;
  final String slotId;
  final String? note;
  const BlockSlot({
    required this.venueId,
    required this.courtId,
    required this.date,
    required this.slotId,
    this.note,
  });
  @override
  List<Object?> get props => [venueId, courtId, date, slotId];
}

class UnblockSlot extends AdminEvent {
  final String venueId;
  final String courtId;
  final String date;
  final String slotId;
  const UnblockSlot({
    required this.venueId,
    required this.courtId,
    required this.date,
    required this.slotId,
  });
  @override
  List<Object?> get props => [venueId, courtId, date, slotId];
}

class ToggleCourtActive extends AdminEvent {
  final String venueId;
  final String courtId;
  final bool isActive;
  const ToggleCourtActive({required this.venueId, required this.courtId, required this.isActive});
  @override
  List<Object?> get props => [venueId, courtId, isActive];
}

class UpdateCourt extends AdminEvent {
  final String venueId;
  final CourtModel court;
  const UpdateCourt({required this.venueId, required this.court});
  @override
  List<Object?> get props => [venueId, court.id];
}

class AssignCourtAdmin extends AdminEvent {
  final String venueId;
  final String courtId;
  final String adminEmail;
  const AssignCourtAdmin({required this.venueId, required this.courtId, required this.adminEmail});
  @override
  List<Object?> get props => [venueId, courtId, adminEmail];
}

class UnassignCourtAdmin extends AdminEvent {
  final String venueId;
  final String courtId;
  const UnassignCourtAdmin({required this.venueId, required this.courtId});
  @override
  List<Object?> get props => [venueId, courtId];
}
