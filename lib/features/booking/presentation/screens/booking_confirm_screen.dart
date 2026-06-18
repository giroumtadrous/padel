import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/booking/data/models/time_slot_model.dart';
import 'package:padel/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:padel/features/booking/presentation/bloc/booking_event.dart';
import 'package:padel/features/booking/presentation/bloc/booking_state.dart';
import 'package:padel/features/matches/data/models/open_match_model.dart';
import 'package:padel/features/matches/presentation/bloc/matches_bloc.dart';
import 'package:padel/features/matches/presentation/bloc/matches_event.dart';
import 'package:padel/features/venues/presentation/bloc/venues_state.dart';
import 'package:padel/features/venues/presentation/bloc/venues_bloc.dart';

class BookingConfirmScreen extends StatefulWidget {
  const BookingConfirmScreen({super.key});

  @override
  State<BookingConfirmScreen> createState() => _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends State<BookingConfirmScreen> {
  bool _openToMatchmaking = false;
  double _minSkill = 1.0;
  double _maxSkill = 7.0;
  static final _dateFmt = DateFormat('EEE, MMM d');
  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is BookingSuccess) {
          if (_openToMatchmaking) {
            _createOpenMatch(context, state);
          }
          context.go('/bookings');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Court booked successfully!')),
          );
        } else if (state is BookingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
        }
      },
      builder: (context, state) {
        if (state is! SlotHeld) {
          return Scaffold(
            appBar: AppBar(title: const Text('Confirm Booking')),
            body: const Center(child: Text('No slot selected.')),
          );
        }

        final slot = state.slot;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Confirm Booking'),
            leading: BackButton(
              onPressed: () {
                context.read<BookingBloc>().add(const ReleaseHold());
                context.pop();
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBookingSummary(context, slot),
                const SizedBox(height: 24),
                _buildOpenMatchSection(context, slot),
                const SizedBox(height: 32),
                _buildTotalRow(context, slot),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Confirm & Pay',
                  isLoading: state is BookingInProgress,
                  onPressed: () => _confirm(context),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Cancel',
                  isOutlined: true,
                  onPressed: () {
                    context.read<BookingBloc>().add(const ReleaseHold());
                    context.pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookingSummary(BuildContext context, TimeSlotModel slot) {
    final venueState = context.read<VenuesBloc>().state;
    String venueName = '';
    String courtName = '';
    if (venueState is VenueDetailLoaded) {
      venueName = venueState.venue.name;
      final court = venueState.courts.firstWhere(
        (c) => c.id == slot.courtId,
        orElse: () => venueState.courts.first,
      );
      courtName = court.name;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _SummaryRow(icon: Icons.sports_tennis_rounded, label: 'Venue', value: venueName),
          const Divider(height: 20),
          _SummaryRow(icon: Icons.grid_view_rounded, label: 'Court', value: courtName),
          const Divider(height: 20),
          _SummaryRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: _dateFmt.format(slot.startTime),
          ),
          const Divider(height: 20),
          _SummaryRow(
            icon: Icons.access_time_rounded,
            label: 'Time',
            value: '${_timeFmt.format(slot.startTime)} — ${_timeFmt.format(slot.endTime)}',
          ),
          const Divider(height: 20),
          _SummaryRow(
            icon: Icons.timer_outlined,
            label: 'Duration',
            value: '${slot.durationMinutes} min',
          ),
        ],
      ),
    );
  }

  Widget _buildOpenMatchSection(BuildContext context, TimeSlotModel slot) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_add_rounded, color: AppColors.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Open to Community', style: Theme.of(context).textTheme.titleLarge),
                    Text('Let other players join & split the cost', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Switch(
                value: _openToMatchmaking,
                onChanged: (v) => setState(() => _openToMatchmaking = v),
                activeColor: AppColors.secondary,
              ),
            ],
          ),
          if (_openToMatchmaking) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text('Skill Range', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${_minSkill.toStringAsFixed(1)} – ${_maxSkill.toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
            ),
            RangeSlider(
              values: RangeValues(_minSkill, _maxSkill),
              min: 1.0,
              max: 7.0,
              divisions: 12,
              activeColor: AppColors.secondary,
              inactiveColor: AppColors.divider,
              onChanged: (r) => setState(() {
                _minSkill = r.start;
                _maxSkill = r.end;
              }),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your price: EGP ${(slot.price / 4).toStringAsFixed(0)}/player (split 4 ways)',
                      style: const TextStyle(color: AppColors.secondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalRow(BuildContext context, TimeSlotModel slot) {
    final displayPrice = _openToMatchmaking ? slot.price / 4 : slot.price;
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total', style: Theme.of(context).textTheme.bodyMedium),
            Text(
              'EGP ${displayPrice.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const Spacer(),
        if (slot.isPeakHour)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.peakHour.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Peak Hour', style: TextStyle(color: AppColors.peakHour, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  void _confirm(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final venueState = context.read<VenuesBloc>().state;
    String venueName = '';
    String courtName = '';
    if (venueState is VenueDetailLoaded) {
      venueName = venueState.venue.name;
      final slot = (context.read<BookingBloc>().state as SlotHeld).slot;
      final court = venueState.courts.firstWhere(
        (c) => c.id == slot.courtId,
        orElse: () => venueState.courts.first,
      );
      courtName = court.name;
    }

    context.read<BookingBloc>().add(ConfirmBooking(
          userId: authState.user.uid,
          venueName: venueName,
          courtName: courtName,
        ));
  }

  void _createOpenMatch(BuildContext context, BookingSuccess state) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final venueState = context.read<VenuesBloc>().state;
    if (venueState is! VenueDetailLoaded) return;

    final booking = state.booking;
    final match = OpenMatchModel(
      id: '',
      bookingId: booking.id,
      courtId: booking.courtId,
      venueId: booking.venueId,
      venueName: booking.venueName,
      courtName: booking.courtName,
      organizerId: authState.user.uid,
      organizerName: authState.user.displayName,
      date: booking.date,
      startTime: booking.startTime,
      endTime: booking.endTime,
      totalSlots: 4,
      filledSlots: 1,
      participantIds: [authState.user.uid],
      minSkillLevel: _minSkill,
      maxSkillLevel: _maxSkill,
      pricePerPlayer: booking.totalPrice / 4,
      createdAt: DateTime.now(),
    );

    context.read<MatchesBloc>().add(CreateOpenMatch(match));
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
