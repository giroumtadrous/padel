import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/admin/data/services/admin_service.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';

class RevenueScreen extends StatefulWidget {
  final String venueId;
  const RevenueScreen({super.key, required this.venueId});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  DateTime _selectedDate = DateTime.now();
  static final _headerFmt = DateFormat('MMMM d, yyyy');
  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue'),
        leading: BackButton(onPressed: () => context.go('/admin')),
        actions: [
          IconButton(
            onPressed: () => _pickDate(context),
            icon: const Icon(Icons.calendar_today_rounded),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: context.read<AdminService>().getDailyRevenueStream(widget.venueId, _selectedDate),
        builder: (context, snap) {
          if (!snap.hasData) return const AppLoadingSpinner();

          final data = snap.data!;
          final total = data['total'] as double;
          final count = data['count'] as int;
          final bookings = data['bookings'] as List<BookingModel>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_headerFmt.format(_selectedDate),
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 20),
                _buildRevenueBanner(context, total, count),
                const SizedBox(height: 24),
                Text('Booking Breakdown', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                if (bookings.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No bookings on this date',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                else
                  ...bookings.map((b) => _RevenueRow(booking: b, timeFmt: _timeFmt)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRevenueBanner(BuildContext context, double total, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.success.withOpacity(0.3), AppColors.success.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text('Daily Revenue', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'EGP ${total.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(color: AppColors.success),
          ),
          const SizedBox(height: 4),
          Text(
            '$count booking${count != 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
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

class _RevenueRow extends StatelessWidget {
  final BookingModel booking;
  final DateFormat timeFmt;

  const _RevenueRow({required this.booking, required this.timeFmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  '${timeFmt.format(booking.startTime)} – ${timeFmt.format(booking.endTime)} · ${booking.durationMinutes} min',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            'EGP ${booking.totalPrice.toInt()}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.success),
          ),
        ],
      ),
    );
  }
}
