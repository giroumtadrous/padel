import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/booking/data/services/booking_service.dart';

class PaymentVerificationScreen extends StatefulWidget {
  final String venueId;
  const PaymentVerificationScreen({super.key, required this.venueId});

  @override
  State<PaymentVerificationScreen> createState() => _PaymentVerificationScreenState();
}

class _PaymentVerificationScreenState extends State<PaymentVerificationScreen> {
  static final _dateFmt = DateFormat('EEE, MMM d');
  static final _timeFmt = DateFormat('HH:mm');
  String? _actioningBookingId;

  Future<void> _verify(BookingModel booking, bool approved) async {
    setState(() => _actioningBookingId = booking.id);
    try {
      await context.read<BookingService>().verifyPayment(
            bookingId: booking.id,
            approved: approved,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approved ? 'Payment approved' : 'Payment rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _actioningBookingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Verification'),
        leading: BackButton(onPressed: () => context.go('/admin')),
      ),
      body: StreamBuilder<List<BookingModel>>(
        stream: context.read<BookingService>().pendingPaymentBookings(widget.venueId),
        builder: (context, snap) {
          if (!snap.hasData) return const AppLoadingSpinner();
          final bookings = snap.data!;
          if (bookings.isEmpty) {
            return const AppEmptyView(
              title: 'Nothing to review',
              subtitle: 'Manual payment proofs awaiting approval will show up here',
              icon: Icons.receipt_long_rounded,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _PendingPaymentCard(
              booking: bookings[i],
              dateFmt: _dateFmt,
              timeFmt: _timeFmt,
              isActioning: _actioningBookingId == bookings[i].id,
              onApprove: () => _verify(bookings[i], true),
              onReject: () => _verify(bookings[i], false),
            ),
          );
        },
      ),
    );
  }
}

class _PendingPaymentCard extends StatelessWidget {
  final BookingModel booking;
  final DateFormat dateFmt;
  final DateFormat timeFmt;
  final bool isActioning;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingPaymentCard({
    required this.booking,
    required this.dateFmt,
    required this.timeFmt,
    required this.isActioning,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(booking.courtName, style: Theme.of(context).textTheme.titleMedium),
              Text(
                booking.paymentMethod,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${dateFmt.format(booking.startTime)} • ${timeFmt.format(booking.startTime)} - ${timeFmt.format(booking.endTime)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Deposit: EGP ${booking.depositAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              Text(
                'Cash due: EGP ${booking.cashDueAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (booking.paymentProofUrl != null && booking.paymentProofUrl!.isNotEmpty)
            GestureDetector(
              onTap: () => _openProof(context, booking.paymentProofUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  booking.paymentProofUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 100,
                    alignment: Alignment.center,
                    color: AppColors.cardElevated,
                    child: const Text('Could not load screenshot'),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isActioning ? null : onReject,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: isActioning ? null : onApprove,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  child: isActioning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openProof(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }
}
