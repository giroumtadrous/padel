import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:padel/features/admin/presentation/bloc/admin_event.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/booking/data/models/time_slot_model.dart';
import 'package:padel/features/booking/data/services/booking_service.dart';
import 'package:padel/features/venues/data/models/court_model.dart';

/// Visual courts x hours schedule for the admin dashboard. Tapping an
/// available slot blocks it for maintenance, tapping a blocked slot
/// unblocks it, and tapping a booked slot surfaces who booked it.
class CourtsHoursGrid extends StatefulWidget {
  final String venueId;
  final List<CourtModel> courts;
  final DateTime date;
  final int openingHour;
  final int closingHour;
  final List<BookingModel> todaysBookings;
  final ValueChanged<String> onUserTap;

  const CourtsHoursGrid({
    super.key,
    required this.venueId,
    required this.courts,
    required this.date,
    required this.openingHour,
    required this.closingHour,
    required this.todaysBookings,
    required this.onUserTap,
  });

  @override
  State<CourtsHoursGrid> createState() => _CourtsHoursGridState();
}

class _CourtsHoursGridState extends State<CourtsHoursGrid> {
  Map<String, List<TimeSlotModel>> _slotsByCourt = {};
  bool _loading = true;
  static final _timeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CourtsHoursGrid old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date || old.venueId != widget.venueId || old.courts != widget.courts) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final bookingService = context.read<BookingService>();
    final result = await bookingService.getVenueSlotsForDate(
      venueId: widget.venueId,
      courts: widget.courts,
      date: widget.date,
      openingHour: widget.openingHour,
      closingHour: widget.closingHour,
    );
    if (!mounted) return;
    setState(() {
      _slotsByCourt = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (widget.courts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No courts yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );
    }

    final times = _slotsByCourt.values
        .expand((slots) => slots.map((s) => s.startTime))
        .toSet()
        .toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: AppColors.cardElevated, label: 'Booked'),
            const SizedBox(width: 12),
            _LegendDot(color: AppColors.error, label: 'Blocked'),
            const SizedBox(width: 12),
            _LegendDot(color: AppColors.card, label: 'Available'),
          ],
        ),
        const SizedBox(height: 10),
        if (times.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No slots for this date', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(116),
              children: [
                TableRow(
                  children: widget.courts
                      .map((court) => Center(
                            child: Text(
                              court.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                ...times.map((time) => TableRow(
                      children: widget.courts.map((court) => _buildCell(court, time)).toList(),
                    )),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCell(CourtModel court, DateTime time) {
    final slots = _slotsByCourt[court.id] ?? [];
    TimeSlotModel? slot;
    for (final s in slots) {
      if (s.startTime.isAtSameMomentAs(time)) {
        slot = s;
        break;
      }
    }
    if (slot == null) {
      return const Padding(padding: EdgeInsets.all(4), child: SizedBox(height: 46));
    }

    Color bgColor;
    Color textColor;
    switch (slot.status) {
      case SlotStatus.booked:
        bgColor = AppColors.cardElevated;
        textColor = AppColors.textPrimary;
        break;
      case SlotStatus.maintenance:
        bgColor = AppColors.error.withValues(alpha: 0.15);
        textColor = AppColors.error;
        break;
      case SlotStatus.held:
        bgColor = AppColors.warning.withValues(alpha: 0.15);
        textColor = AppColors.warning;
        break;
      case SlotStatus.available:
        bgColor = AppColors.card;
        textColor = AppColors.textPrimary;
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        onTap: () => _onCellTap(court, slot!),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: slot.status == SlotStatus.maintenance ? AppColors.error : AppColors.divider,
            ),
          ),
          child: Text(
            _timeFmt.format(slot.startTime),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
          ),
        ),
      ),
    );
  }

  void _onCellTap(CourtModel court, TimeSlotModel slot) {
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);

    switch (slot.status) {
      case SlotStatus.available:
        _confirm(
          title: 'Block Slot',
          message: '${court.name} at ${_timeFmt.format(slot.startTime)} — block this for maintenance?',
          confirmLabel: 'Block',
          onConfirm: () => context.read<AdminBloc>().add(BlockSlot(
                venueId: widget.venueId,
                courtId: court.id,
                date: dateStr,
                slotId: slot.id,
              )),
        );
        break;
      case SlotStatus.maintenance:
        _confirm(
          title: 'Unblock Slot',
          message: '${court.name} at ${_timeFmt.format(slot.startTime)} — make this available again?',
          confirmLabel: 'Unblock',
          onConfirm: () => context.read<AdminBloc>().add(UnblockSlot(
                venueId: widget.venueId,
                courtId: court.id,
                date: dateStr,
                slotId: slot.id,
              )),
        );
        break;
      case SlotStatus.booked:
        for (final booking in widget.todaysBookings) {
          if (booking.id == slot.bookingId) {
            widget.onUserTap(booking.userId);
            break;
          }
        }
        break;
      case SlotStatus.held:
        break;
    }
  }

  void _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(confirmLabel),
          ),
        ],
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
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
