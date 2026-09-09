import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/admin/data/services/admin_service.dart';
import 'package:padel/features/admin/presentation/screens/courts_hours_grid.dart';
import 'package:padel/features/auth/data/models/user_model.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/venues/data/models/court_model.dart';
import 'package:padel/features/venues/data/models/venue_model.dart';

/// Scoped venue-owner dashboard. Owners can inspect every assigned court and
/// block or unblock maintenance slots, but cannot edit venue configuration.
class CourtAdminDashboardScreen extends StatefulWidget {
  final List<String> managedVenueIds;
  const CourtAdminDashboardScreen({super.key, required this.managedVenueIds});

  @override
  State<CourtAdminDashboardScreen> createState() =>
      _CourtAdminDashboardScreenState();
}

class _ManagedCourt {
  final String venueId;
  final VenueModel venue;
  final CourtModel court;
  const _ManagedCourt({
    required this.venueId,
    required this.venue,
    required this.court,
  });
}

class _CourtAdminDashboardScreenState extends State<CourtAdminDashboardScreen> {
  List<_ManagedCourt> _courts = [];
  _ManagedCourt? _selected;
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();
  static final _headerFmt = DateFormat('EEE, MMM d');
  static final _timeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final adminService = context.read<AdminService>();
    final courts = <_ManagedCourt>[];
    for (final venueId in widget.managedVenueIds) {
      final venue = await adminService.getVenue(venueId);
      if (venue == null) continue;
      final venueCourts = await adminService.getAdminCourts(venueId);
      for (final court in venueCourts) {
        courts.add(_ManagedCourt(venueId: venueId, venue: venue, court: court));
      }
    }

    if (!mounted) return;
    setState(() {
      _courts = courts;
      _selected = courts.isNotEmpty ? courts.first : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Venues'),
        actions: [
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_rounded),
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingSpinner()
          : _selected == null
          ? const AppErrorView(message: 'No assigned venue could be found')
          : _DashboardBody(
              managed: _selected!,
              selectedDate: _selectedDate,
              headerFmt: _headerFmt,
              timeFmt: _timeFmt,
              allCourts: _courts,
              onCourtChanged: (c) => setState(() => _selected = c),
              onUserTap: (userId) => context.push(
                '/admin/user/$userId?venueId=${_selected!.venueId}',
              ),
            ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }
}

class _DashboardBody extends StatelessWidget {
  final _ManagedCourt managed;
  final DateTime selectedDate;
  final DateFormat headerFmt;
  final DateFormat timeFmt;
  final List<_ManagedCourt> allCourts;
  final ValueChanged<_ManagedCourt> onCourtChanged;
  final ValueChanged<String> onUserTap;

  const _DashboardBody({
    required this.managed,
    required this.selectedDate,
    required this.headerFmt,
    required this.timeFmt,
    required this.allCourts,
    required this.onCourtChanged,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    final adminService = context.read<AdminService>();
    final court = managed.court;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (allCourts.length > 1) ...[
            DropdownButtonFormField<_ManagedCourt>(
              value: managed,
              decoration: const InputDecoration(labelText: 'Court'),
              dropdownColor: AppColors.card,
              items: allCourts
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text('${c.venue.name} · ${c.court.name}'),
                    ),
                  )
                  .toList(),
              onChanged: (c) {
                if (c != null) onCourtChanged(c);
              },
            ),
            const SizedBox(height: 12),
          ],
          Text(court.name, style: Theme.of(context).textTheme.displayMedium),
          Text(
            managed.venue.name,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            headerFmt.format(selectedDate),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          StreamBuilder<Map<String, dynamic>>(
            stream: adminService.getCourtDailyStatsStream(
              court.id,
              selectedDate,
            ),
            builder: (context, statsSnap) {
              final total = (statsSnap.data?['total'] as double?) ?? 0.0;
              final count = (statsSnap.data?['count'] as int?) ?? 0;
              final bookings =
                  (statsSnap.data?['bookings'] as List<BookingModel>?) ??
                  const [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatCard(
                        label: 'Revenue',
                        value: 'EGP ${total.toInt()}',
                        icon: Icons.payments_rounded,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Bookings',
                        value: '$count',
                        icon: Icons.calendar_today_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      StreamBuilder<Map<String, int>>(
                        stream: adminService.getCourtOccupancyStream(
                          managed.venueId,
                          court.id,
                          selectedDate,
                        ),
                        builder: (context, occSnap) {
                          final booked = occSnap.data?['booked'] ?? 0;
                          final totalSlots = occSnap.data?['total'] ?? 0;
                          final pct = totalSlots == 0
                              ? 0
                              : ((booked / totalSlots) * 100).round();
                          return _StatCard(
                            label: 'Occupancy',
                            value: '$pct%',
                            icon: Icons.donut_large_rounded,
                            color: AppColors.secondary,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Court Schedule',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  CourtsHoursGrid(
                    venueId: managed.venueId,
                    courts: [court],
                    date: selectedDate,
                    openingHour: managed.venue.openingHour,
                    closingHour: managed.venue.closingHour,
                    todaysBookings: bookings,
                    onUserTap: onUserTap,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Bookings',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  if (bookings.isEmpty)
                    const AppEmptyView(
                      title: 'No bookings on this date',
                      subtitle: 'Bookings for this court will appear here',
                      icon: Icons.calendar_today_rounded,
                    )
                  else
                    ...bookings.map(
                      (b) => _BookingRow(
                        booking: b,
                        timeFmt: timeFmt,
                        venueId: managed.venueId,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(color: color),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final BookingModel booking;
  final DateFormat timeFmt;
  final String venueId;

  const _BookingRow({
    required this.booking,
    required this.timeFmt,
    required this.venueId,
  });

  @override
  Widget build(BuildContext context) {
    final adminService = context.read<AdminService>();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () =>
              context.push('/admin/user/${booking.userId}?venueId=$venueId'),
          child: FutureBuilder<UserModel?>(
            future: adminService.getUserProfile(booking.userId),
            builder: (context, snap) {
              final user = snap.data;
              final displayName = user?.displayName.isNotEmpty == true
                  ? user!.displayName
                  : booking.userId;

              return Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.courtName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Booked by $displayName',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${timeFmt.format(booking.startTime)} – ${timeFmt.format(booking.endTime)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'EGP ${booking.totalPrice.toInt()}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: AppColors.success),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
