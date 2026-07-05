import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/booking/data/services/booking_service.dart';
import 'package:padel/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:padel/features/booking/presentation/bloc/booking_event.dart';
import 'package:padel/features/booking/presentation/bloc/booking_state.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  void _loadHistory() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<BookingBloc>().add(LoadBookingHistory(authState.user.uid));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: BlocBuilder<BookingBloc, BookingState>(
        builder: (context, state) {
          if (state is BookingHistoryLoading) return const ShimmerList();
          if (state is BookingError) {
            return AppErrorView(message: state.message, onRetry: _loadHistory);
          }
          if (state is BookingHistoryLoaded) {
            final authState = context.read<AuthBloc>().state;
            final userId = authState is AuthAuthenticated ? authState.user.uid : '';

            return TabBarView(
              controller: _tabController,
              children: [
                _BookingList(
                  bookings: state.upcoming,
                  emptyTitle: 'No upcoming bookings',
                  emptySubtitle: 'Book a court to get started',
                  showCancel: true,
                  userId: userId,
                ),
                _BookingList(
                  bookings: state.past,
                  emptyTitle: 'No past bookings',
                  emptySubtitle: 'Your completed games will appear here',
                  showRate: true,
                  userId: userId,
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final String emptyTitle;
  final String emptySubtitle;
  final bool showCancel;
  final bool showRate;
  final String userId;

  const _BookingList({
    required this.bookings,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.showCancel = false,
    this.showRate = false,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return AppEmptyView(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: Icons.calendar_today_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _BookingCard(
        booking: bookings[i],
        showCancel: showCancel,
        showRate: showRate,
        userId: userId,
      ),
    );
  }
}

class _BookingCard extends StatefulWidget {
  final BookingModel booking;
  final bool showCancel;
  final bool showRate;
  final String userId;

  static final _dateFmt = DateFormat('EEE, MMM d');
  static final _timeFmt = DateFormat('HH:mm');

  const _BookingCard({
    required this.booking,
    required this.showCancel,
    required this.showRate,
    required this.userId,
  });

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  bool _hasReview = false;
  bool _checkingReview = true;

  @override
  void initState() {
    super.initState();
    if (widget.showRate) {
      _checkReviewStatus();
    } else {
      _checkingReview = false;
    }
  }

  Future<void> _checkReviewStatus() async {
    try {
      final service = BookingService();
      final has = await service.hasReviewForBooking(widget.booking.id, widget.userId);
      if (mounted) setState(() { _hasReview = has; _checkingReview = false; });
    } catch (_) {
      if (mounted) setState(() => _checkingReview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final statusColor = _statusColor(booking.status);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showBookingDetails(context, booking),
          child: Column(
        children: [
          // Colored status accent bar
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        booking.venueName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _StatusBadge(status: booking.status),
                  ],
                ),
                const SizedBox(height: 2),
                Text(booking.courtName, style: Theme.of(context).textTheme.bodyMedium),
                if (booking.paymentStatus == AppConstants.paymentPending ||
                    booking.paymentStatus == AppConstants.paymentRejected) ...[
                  const SizedBox(height: 6),
                  _PaymentStatusBadge(paymentStatus: booking.paymentStatus),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _InfoChip(Icons.calendar_today_rounded,
                        _BookingCard._dateFmt.format(booking.startTime)),
                    const SizedBox(width: 8),
                    _InfoChip(
                      Icons.access_time_rounded,
                      '${_BookingCard._timeFmt.format(booking.startTime)} — ${_BookingCard._timeFmt.format(booking.endTime)}',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _InfoChip(Icons.payments_outlined,
                        'EGP ${booking.totalPrice.toInt()} total'),
                    if (booking.status == BookingStatus.upcoming &&
                        booking.paymentStatus != AppConstants.paymentRejected &&
                        booking.cashDueAmount > 0) ...[
                      const SizedBox(width: 8),
                      _InfoChip(Icons.money_rounded,
                          'EGP ${booking.cashDueAmount.toInt()} cash due',
                          color: AppColors.warning),
                    ],
                    if (booking.isOpenMatch) ...[
                      const SizedBox(width: 8),
                      _InfoChip(Icons.group_rounded, 'Open Match',
                          color: AppColors.secondary),
                    ],
                    const Spacer(),
                    // Cancel button
                    if (widget.showCancel &&
                        booking.status == BookingStatus.upcoming)
                      TextButton(
                        onPressed: () => _cancelBooking(context),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4)),
                        child: const Text('Cancel',
                            style: TextStyle(fontSize: 12)),
                      ),
                    // Rate button
                    if (widget.showRate && !_checkingReview && !_hasReview)
                      TextButton.icon(
                        onPressed: () {
                          context.push(
                            '/booking/${booking.id}/review',
                            extra: {
                              'venueId': booking.venueId,
                              'venueName': booking.venueName,
                            },
                          );
                        },
                        icon: const Icon(Icons.star_outline_rounded, size: 14),
                        label: const Text('Rate', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.gold,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    if (widget.showRate && !_checkingReview && _hasReview)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 13, color: AppColors.gold),
                            SizedBox(width: 3),
                            Text('Rated',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  void _showBookingDetails(BuildContext context, BookingModel booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BookingDetailsSheet(booking: booking),
    );
  }

  void _cancelBooking(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Keep')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context
                  .read<BookingBloc>()
                  .add(CancelBooking(widget.booking.id));
            },
            child: const Text('Cancel Booking',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.upcoming:
        return AppColors.secondary;
      case BookingStatus.completed:
        return AppColors.success;
      case BookingStatus.cancelled:
        return AppColors.error;
    }
  }
}

class _BookingDetailsSheet extends StatelessWidget {
  final BookingModel booking;
  const _BookingDetailsSheet({required this.booking});

  static final _dateFmt = DateFormat('EEE, MMM d, yyyy');
  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final ref = booking.id.length >= 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      booking.venueName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _StatusBadge(status: booking.status),
                ],
              ),
              const SizedBox(height: 2),
              Text(booking.courtName, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              _DetailRow(icon: Icons.calendar_today_rounded, label: 'Date', value: _dateFmt.format(booking.startTime)),
              _DetailRow(
                icon: Icons.access_time_rounded,
                label: 'Time',
                value: '${_timeFmt.format(booking.startTime)} — ${_timeFmt.format(booking.endTime)}',
              ),
              _DetailRow(icon: Icons.timer_outlined, label: 'Duration', value: '${booking.durationMinutes} min'),
              _DetailRow(icon: Icons.tag_rounded, label: 'Reference', value: ref),
              if (booking.isOpenMatch)
                const _DetailRow(icon: Icons.group_rounded, label: 'Open Match', value: 'Yes'),
              if (booking.status == BookingStatus.cancelled && booking.cancelledAt != null)
                _DetailRow(
                  icon: Icons.cancel_outlined,
                  label: 'Cancelled on',
                  value: _dateFmt.format(booking.cancelledAt!),
                ),
              const Divider(height: 28),
              _DetailRow(
                icon: Icons.credit_card_rounded,
                label: 'Payment method',
                value: _paymentMethodLabel(booking.paymentMethod),
              ),
              _DetailRow(
                icon: Icons.payments_outlined,
                label: 'Total price',
                value: 'EGP ${booking.totalPrice.toStringAsFixed(0)}',
              ),
              _DetailRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Deposit paid',
                value: 'EGP ${booking.depositAmount.toStringAsFixed(0)}',
              ),
              _DetailRow(
                icon: Icons.money_rounded,
                label: 'Cash due at venue',
                value: 'EGP ${booking.cashDueAmount.toStringAsFixed(0)}',
              ),
              if (booking.paymentStatus == AppConstants.paymentPending ||
                  booking.paymentStatus == AppConstants.paymentRejected) ...[
                const SizedBox(height: 10),
                _PaymentStatusBadge(paymentStatus: booking.paymentStatus),
              ],
              if (booking.paymentProofUrl != null && booking.paymentProofUrl!.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Payment screenshot',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                ClipRRect(
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
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case AppConstants.paymentCard:
        return 'Card';
      case AppConstants.paymentWallet:
        return 'Wallet';
      case AppConstants.paymentVodafone:
        return 'Vodafone Cash';
      case AppConstants.paymentFawry:
        return 'Fawry';
      case AppConstants.paymentInstaPay:
        return 'InstaPay';
      default:
        return method;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

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
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final BookingStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late Color bgColor;
    late String label;
    switch (status) {
      case BookingStatus.upcoming:
        color = AppColors.secondary;
        bgColor = AppColors.secondary.withValues(alpha: 0.1);
        label = 'Upcoming';
        break;
      case BookingStatus.completed:
        color = AppColors.success;
        bgColor = AppColors.successLight;
        label = 'Completed';
        break;
      case BookingStatus.cancelled:
        color = AppColors.error;
        bgColor = AppColors.error.withValues(alpha: 0.1);
        label = 'Cancelled';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  final String paymentStatus;
  const _PaymentStatusBadge({required this.paymentStatus});

  @override
  Widget build(BuildContext context) {
    final isPending = paymentStatus == AppConstants.paymentPending;
    final color = isPending ? AppColors.warning : AppColors.error;
    final label = isPending ? 'Payment pending verification' : 'Payment rejected';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }
}
