import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/admin/data/services/admin_service.dart';
import 'package:padel/features/auth/data/models/user_model.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';

/// Read-only customer lookup for admins — reached by tapping a booking on
/// the admin dashboard to see who booked.
class UserProfileViewScreen extends StatefulWidget {
  final String userId;
  final String venueId;

  const UserProfileViewScreen({super.key, required this.userId, required this.venueId});

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  UserModel? _user;
  List<BookingModel> _bookings = [];
  bool _loading = true;
  String? _error;

  static final _dateFmt = DateFormat('EEE, MMM d');
  static final _timeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final adminService = context.read<AdminService>();
      final user = await adminService.getUserProfile(widget.userId);
      final bookings = await adminService.getUserBookingsAtVenue(widget.userId, widget.venueId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _bookings = bookings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: _loading
          ? const AppLoadingSpinner()
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _load)
              : _user == null
                  ? const AppErrorView(message: 'This user could not be found')
                  : _buildContent(_user!),
    );
  }

  Widget _buildContent(UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary,
                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null
                    ? Text(
                        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName, style: Theme.of(context).textTheme.displayMedium),
                    Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatBox(value: user.skillLevel.toStringAsFixed(1), label: 'Skill'),
              _StatBox(
                value: user.preferredSide == AppConstants.sideForerhand ? 'Right' : 'Left',
                label: 'Side',
              ),
              _StatBox(value: '${user.matchesPlayed}', label: 'Matches'),
              _StatBox(value: '${_bookings.length}', label: 'Here'),
            ],
          ),
          const SizedBox(height: 20),
          _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: user.phone ?? 'Not provided'),
          _InfoRow(
            icon: Icons.verified_user_outlined,
            label: 'Phone verified',
            value: user.phoneVerified ? 'Yes' : 'No',
          ),
          const SizedBox(height: 24),
          Text('Bookings at this venue', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          if (_bookings.isEmpty)
            const AppEmptyView(
              title: 'No bookings here yet',
              icon: Icons.calendar_today_rounded,
            )
          else
            ..._bookings.map((b) => _BookingRow(booking: b, dateFmt: _dateFmt, timeFmt: _timeFmt)),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final BookingModel booking;
  final DateFormat dateFmt;
  final DateFormat timeFmt;

  const _BookingRow({required this.booking, required this.dateFmt, required this.timeFmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.courtName, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${dateFmt.format(booking.startTime)} · ${timeFmt.format(booking.startTime)}–${timeFmt.format(booking.endTime)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            'EGP ${booking.totalPrice.toInt()}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.success),
          ),
        ],
      ),
    );
  }
}
