import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/admin/data/services/admin_service.dart';
import 'package:padel/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:padel/features/admin/presentation/bloc/admin_event.dart';
import 'package:padel/features/admin/presentation/bloc/admin_state.dart';
import 'package:padel/features/admin/presentation/screens/court_admin_dashboard_screen.dart';
import 'package:padel/features/admin/presentation/screens/courts_hours_grid.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/venues/data/models/venue_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedVenueId;
  List<VenueModel> _managedVenues = [];

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.user.managedVenueIds.isNotEmpty) {
      _selectedVenueId = authState.user.managedVenueIds.first;
      _loadVenueList(authState.user.uid);
    }
    _load();
  }

  Future<void> _loadVenueList(String adminId) async {
    final venues = await context.read<AdminService>().getAdminVenues(adminId);
    if (!mounted) return;
    setState(() => _managedVenues = venues);
  }

  void _load() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && _selectedVenueId != null) {
      context.read<AdminBloc>().add(LoadAdminDashboard(
            adminId: authState.user.uid,
            venueId: _selectedVenueId!,
            date: _selectedDate,
          ));
    }
  }

  void _onVenueChanged(String venueId) {
    setState(() => _selectedVenueId = venueId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is AuthAuthenticated &&
        authState.user.managedVenueIds.isEmpty &&
        authState.user.managedCourtIds.isNotEmpty) {
      return CourtAdminDashboardScreen(managedCourtIds: authState.user.managedCourtIds);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => _pickDate(),
            icon: const Icon(Icons.calendar_today_rounded),
          ),
        ],
      ),
      body: BlocConsumer<AdminBloc, AdminState>(
        listener: (context, state) {
          if (state is AdminActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            _load();
          } else if (state is AdminError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminLoading) return const AppLoadingSpinner();
          if (state is AdminError) {
            return AppErrorView(message: state.message, onRetry: _load);
          }
          if (state is AdminDashboardLoaded) {
            return _DashboardContent(
              state: state,
              selectedDate: _selectedDate,
              managedVenues: _managedVenues,
              onVenueChanged: _onVenueChanged,
              onCourtsTap: () => context.go('/admin/courts?venueId=${state.venue.id}'),
              onRevenueTap: () => context.go('/admin/revenue?venueId=${state.venue.id}'),
              onPaymentsTap: () => context.go('/admin/payments?venueId=${state.venue.id}'),
              onTournamentsTap: () => context.go('/admin/tournaments'),
              onMarketTap: () => context.go('/admin/market'),
              onSkillRequestsTap: () => context.go('/admin/skill-requests'),
              onReviewsTap: () => context.go('/admin/reviews?venueId=${state.venue.id}'),
              onUserTap: (userId) => context.push('/admin/user/$userId?venueId=${state.venue.id}'),
            );
          }

          final authState = context.read<AuthBloc>().state;
          if (authState is AuthAuthenticated && authState.user.managedVenueIds.isEmpty) {
            return const AppEmptyView(
              title: 'No venues assigned',
              subtitle: 'Contact support to get a venue assigned to your account',
              icon: Icons.store_outlined,
            );
          }
          return const AppLoadingSpinner();
        },
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
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }
}

class _DashboardContent extends StatelessWidget {
  final AdminDashboardLoaded state;
  final DateTime selectedDate;
  final List<VenueModel> managedVenues;
  final ValueChanged<String> onVenueChanged;
  final VoidCallback onCourtsTap;
  final VoidCallback onRevenueTap;
  final VoidCallback onPaymentsTap;
  final VoidCallback onTournamentsTap;
  final VoidCallback onMarketTap;
  final VoidCallback onSkillRequestsTap;
  final VoidCallback onReviewsTap;
  final ValueChanged<String> onUserTap;

  static final _dateFmt = DateFormat('EEE, MMM d');
  static final _timeFmt = DateFormat('HH:mm');

  const _DashboardContent({
    required this.state,
    required this.selectedDate,
    required this.managedVenues,
    required this.onVenueChanged,
    required this.onCourtsTap,
    required this.onRevenueTap,
    required this.onPaymentsTap,
    required this.onTournamentsTap,
    required this.onMarketTap,
    required this.onSkillRequestsTap,
    required this.onReviewsTap,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (managedVenues.length > 1)
            DropdownButtonFormField<String>(
              value: state.venue.id,
              decoration: const InputDecoration(labelText: 'Venue'),
              dropdownColor: AppColors.card,
              items: managedVenues
                  .map((v) => DropdownMenuItem(value: v.id, child: Text(v.name)))
                  .toList(),
              onChanged: (id) {
                if (id != null) onVenueChanged(id);
              },
            )
          else
            Text(state.venue.name, style: Theme.of(context).textTheme.displayMedium),
          Text(_dateFmt.format(selectedDate), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          _buildStatsRow(context),
          const SizedBox(height: 20),
          _buildQuickActions(context),
          const SizedBox(height: 24),
          Text('Courts Schedule', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          CourtsHoursGrid(
            key: ValueKey('${state.venue.id}-${_dateFmt.format(selectedDate)}'),
            venueId: state.venue.id,
            courts: state.courts,
            date: selectedDate,
            openingHour: state.venue.openingHour,
            closingHour: state.venue.closingHour,
            todaysBookings: state.todaysBookings,
            onUserTap: onUserTap,
          ),
          const SizedBox(height: 24),
          Text('Today\'s Bookings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          if (state.todaysBookings.isEmpty)
            const AppEmptyView(
              title: 'No bookings today',
              subtitle: 'Bookings will appear here',
              icon: Icons.calendar_today_rounded,
            )
          else
            ...state.todaysBookings.map((b) => _AdminBookingRow(
                  booking: b,
                  timeFmt: _timeFmt,
                  onTap: () => onUserTap(b.userId),
                )),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          label: 'Revenue',
          value: 'EGP ${state.totalRevenue.toInt()}',
          icon: Icons.payments_rounded,
          color: AppColors.success,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Bookings',
          value: '${state.todaysBookings.length}',
          icon: Icons.calendar_today_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Courts',
          value: '${state.courts.length}',
          icon: Icons.sports_tennis_rounded,
          color: AppColors.secondary,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Rating',
          value: state.venue.reviewCount > 0 ? state.venue.rating.toStringAsFixed(1) : '—',
          icon: Icons.star_rounded,
          color: AppColors.gold,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.grid_view_rounded,
                label: 'Manage Courts',
                onTap: onCourtsTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.bar_chart_rounded,
                label: 'Revenue Report',
                onTap: onRevenueTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.receipt_long_rounded,
          label: 'Payment Verification',
          onTap: onPaymentsTap,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.emoji_events_outlined,
                label: 'Tournaments',
                onTap: onTournamentsTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.storefront_outlined,
                label: 'Market',
                onTap: onMarketTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.verified_user_outlined,
                label: 'Skill Requests',
                onTap: onSkillRequestsTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.star_outline_rounded,
                label: 'Reviews',
                onTap: onReviewsTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: color)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _AdminBookingRow extends StatelessWidget {
  final BookingModel booking;
  final DateFormat timeFmt;
  final VoidCallback onTap;

  const _AdminBookingRow({required this.booking, required this.timeFmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          child: Row(
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
                    Text(booking.courtName, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${timeFmt.format(booking.startTime)} – ${timeFmt.format(booking.endTime)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                'EGP ${booking.totalPrice.toInt()}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.success),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
