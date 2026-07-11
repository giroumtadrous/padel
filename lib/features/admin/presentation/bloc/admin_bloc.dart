import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padel/features/admin/data/services/admin_service.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/venues/data/services/venue_service.dart';
import 'admin_event.dart';
import 'admin_state.dart';

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final AdminService _adminService;
  final VenueService _venueService;

  AdminBloc({required AdminService adminService, required VenueService venueService})
      : _adminService = adminService,
        _venueService = venueService,
        super(const AdminInitial()) {
    on<LoadAdminDashboard>(_onLoadDashboard);
    on<BlockSlot>(_onBlockSlot);
    on<UnblockSlot>(_onUnblockSlot);
    on<ToggleCourtActive>(_onToggleCourt);
    on<UpdateCourt>(_onUpdateCourt);
    on<AssignCourtAdmin>(_onAssignCourtAdmin);
    on<UnassignCourtAdmin>(_onUnassignCourtAdmin);
  }

  Future<void> _onLoadDashboard(LoadAdminDashboard event, Emitter<AdminState> emit) async {
    emit(const AdminLoading());
    try {
      final venue = await _venueService.getVenue(event.venueId);
      final courts = await _adminService.getAdminCourts(event.venueId);

      await emit.onEach(
        _adminService.getDailyRevenueStream(event.venueId, event.date),
        onData: (data) => emit(AdminDashboardLoaded(
          venue: venue,
          courts: courts,
          todaysBookings: (data['bookings'] as List).cast<BookingModel>(),
          totalRevenue: data['total'] as double,
          selectedDate: event.date,
        )),
        onError: (e, _) => emit(AdminError(e.toString())),
      );
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> _onBlockSlot(BlockSlot event, Emitter<AdminState> emit) async {
    try {
      await _adminService.blockSlot(
        venueId: event.venueId,
        courtId: event.courtId,
        date: event.date,
        slotId: event.slotId,
        note: event.note,
      );
      emit(const AdminActionSuccess('Slot blocked for maintenance'));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> _onUnblockSlot(UnblockSlot event, Emitter<AdminState> emit) async {
    try {
      await _adminService.unblockSlot(
        venueId: event.venueId,
        courtId: event.courtId,
        date: event.date,
        slotId: event.slotId,
      );
      emit(const AdminActionSuccess('Slot unblocked'));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> _onToggleCourt(ToggleCourtActive event, Emitter<AdminState> emit) async {
    try {
      await _adminService.toggleCourtActive(event.venueId, event.courtId, event.isActive);
      emit(AdminActionSuccess(event.isActive ? 'Court activated' : 'Court deactivated'));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> _onUpdateCourt(UpdateCourt event, Emitter<AdminState> emit) async {
    try {
      await _venueService.updateCourt(event.venueId, event.court);
      emit(const AdminActionSuccess('Court updated'));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> _onAssignCourtAdmin(AssignCourtAdmin event, Emitter<AdminState> emit) async {
    try {
      await _adminService.assignCourtAdmin(
        venueId: event.venueId,
        courtId: event.courtId,
        adminEmail: event.adminEmail,
      );
      emit(AdminActionSuccess('${event.adminEmail} assigned to this court'));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> _onUnassignCourtAdmin(UnassignCourtAdmin event, Emitter<AdminState> emit) async {
    try {
      await _adminService.unassignCourtAdmin(venueId: event.venueId, courtId: event.courtId);
      emit(const AdminActionSuccess('Court admin removed'));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }
}
