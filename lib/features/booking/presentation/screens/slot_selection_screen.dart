import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/booking/data/models/time_slot_model.dart';
import 'package:padel/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:padel/features/booking/presentation/bloc/booking_event.dart';
import 'package:padel/features/booking/presentation/bloc/booking_state.dart';
import 'package:padel/features/venues/presentation/bloc/venues_bloc.dart';
import 'package:padel/features/venues/presentation/bloc/venues_event.dart';
import 'package:padel/features/venues/presentation/bloc/venues_state.dart';
import 'package:table_calendar/table_calendar.dart';

class SlotSelectionScreen extends StatefulWidget {
  final String venueId;
  final String courtId;

  const SlotSelectionScreen({super.key, required this.venueId, required this.courtId});

  @override
  State<SlotSelectionScreen> createState() => _SlotSelectionScreenState();
}

class _SlotSelectionScreenState extends State<SlotSelectionScreen> {
  DateTime _selectedDay = DateTime.now();
  static final _timeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _loadSlots(_selectedDay);
  }

  void _loadSlots(DateTime date) {
    final venueState = context.read<VenuesBloc>().state;
    if (venueState is VenueDetailLoaded) {
      final court = venueState.courts.firstWhere(
        (c) => c.id == widget.courtId,
        orElse: () => venueState.courts.first,
      );
      context.read<BookingBloc>().add(LoadSlots(
            venueId: widget.venueId,
            courtId: widget.courtId,
            court: court,
            date: date,
            openingHour: venueState.venue.openingHour,
            closingHour: venueState.venue.closingHour,
          ));
    } else {
      context.read<VenuesBloc>().add(LoadVenueDetail(widget.venueId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is SlotHeld) {
          context.go('/booking/confirm');
        } else if (state is BookingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select a Slot'),
          leading: BackButton(onPressed: () => context.go('/venues/${widget.venueId}')),
        ),
        body: Column(
          children: [
            _buildCalendar(),
            const Divider(height: 1),
            _buildLegend(),
            Expanded(child: _buildSlotGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.now(),
      lastDay: DateTime.now().add(const Duration(days: 30)),
      focusedDay: _selectedDay,
      selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
      calendarStyle: CalendarStyle(
        selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        todayDecoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
        defaultTextStyle: const TextStyle(color: AppColors.textPrimary),
        weekendTextStyle: const TextStyle(color: AppColors.textSecondary),
        outsideTextStyle: const TextStyle(color: AppColors.textHint),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: Theme.of(context).textTheme.titleLarge!,
        leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary),
        rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        weekendStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      onDaySelected: (selected, focused) {
        setState(() => _selectedDay = selected);
        _loadSlots(selected);
      },
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _LegendDot(color: AppColors.primary, label: 'Available'),
          const SizedBox(width: 16),
          _LegendDot(color: AppColors.peakHour, label: 'Peak'),
          const SizedBox(width: 16),
          _LegendDot(color: AppColors.divider, label: 'Unavailable'),
        ],
      ),
    );
  }

  Widget _buildSlotGrid() {
    return BlocBuilder<BookingBloc, BookingState>(
      builder: (context, state) {
        if (state is SlotsLoading || state is SlotHolding) {
          return const ShimmerSlotGrid();
        }
        if (state is BookingError) {
          return AppErrorView(message: state.message, onRetry: () => _loadSlots(_selectedDay));
        }
        if (state is SlotsLoaded) {
          if (state.slots.isEmpty) {
            return const AppEmptyView(
              title: 'No slots available',
              subtitle: 'Try another date',
              icon: Icons.event_busy_rounded,
            );
          }
          return _SlotGrid(
            slots: state.slots,
            onSlotTap: (slot) => _onSlotSelected(slot),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _onSlotSelected(TimeSlotModel slot) {
    if (!slot.isAvailable) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    context.read<BookingBloc>().add(HoldSlot(slot: slot, userId: authState.user.uid));
  }
}

class _SlotGrid extends StatelessWidget {
  final List<TimeSlotModel> slots;
  final ValueChanged<TimeSlotModel> onSlotTap;
  static final _timeFmt = DateFormat('HH:mm');

  const _SlotGrid({required this.slots, required this.onSlotTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemCount: slots.length,
      itemBuilder: (_, i) => _SlotTile(slot: slots[i], onTap: () => onSlotTap(slots[i])),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final TimeSlotModel slot;
  final VoidCallback onTap;
  static final _timeFmt = DateFormat('HH:mm');

  const _SlotTile({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAvailable = slot.isAvailable;
    final isPeak = slot.isPeakHour;

    Color borderColor;
    Color bgColor;
    Color textColor;

    if (!isAvailable) {
      borderColor = AppColors.divider;
      bgColor = AppColors.surface;
      textColor = AppColors.textHint;
    } else if (isPeak) {
      borderColor = AppColors.peakHour;
      bgColor = AppColors.peakHour.withOpacity(0.08);
      textColor = AppColors.peakHour;
    } else {
      borderColor = AppColors.primary;
      bgColor = AppColors.primary.withOpacity(0.08);
      textColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _timeFmt.format(slot.startTime),
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              'EGP ${slot.price.toInt()}',
              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 11),
            ),
            if (!isAvailable)
              const Text('Taken', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
