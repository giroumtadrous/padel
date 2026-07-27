import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/core/services/notification_service.dart';
import 'package:padel/core/services/payment_proof_storage_service.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/features/auth/data/services/auth_service.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:padel/features/booking/presentation/bloc/booking_event.dart';
import 'package:padel/features/booking/presentation/bloc/booking_state.dart';
import 'package:padel/features/matches/data/models/open_match_model.dart';
import 'package:padel/features/matches/presentation/bloc/matches_bloc.dart';
import 'package:padel/features/matches/presentation/bloc/matches_event.dart';

class BookingConfirmScreen extends StatefulWidget {
  final String venueName;
  final String courtName;

  const BookingConfirmScreen({
    super.key,
    required this.venueName,
    required this.courtName,
  });

  @override
  State<BookingConfirmScreen> createState() => _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends State<BookingConfirmScreen> {
  bool _openToMatchmaking = false;
  double _minSkill = 1.0;
  double _maxSkill = 7.0;
  String _selectedPayment = AppConstants.paymentVodafone;

  final PaymentProofStorageService _proofStorage = PaymentProofStorageService.instance;
  XFile? _proofImage;
  bool _uploadingProof = false;

  // Cached once we have a real hold, so the UI keeps showing the booking
  // summary through BookingInProgress/BookingSuccess instead of flashing a
  // "No slot selected" fallback while the confirmation is in flight.
  SlotHeld? _lastHeld;

  static final _dateFmt = DateFormat('EEE, MMM d');
  static final _timeFmt = DateFormat('HH:mm');

  bool get _isManualPayment => AppConstants.manualPaymentMethods.contains(_selectedPayment);
  bool get _isCardPayment => _selectedPayment == AppConstants.paymentCard;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookingBloc, BookingState>(
      listener: (context, state) async {
        if (state is BookingSuccess) {
          if (_openToMatchmaking) {
            _createOpenMatch(context, state);
          }

          // Record loyalty booking
          final authState = context.read<AuthBloc>().state;
          if (authState is AuthAuthenticated) {
            try {
              await context
                  .read<AuthService>()
                  .recordLoyaltyBooking(authState.user.uid);
            } catch (_) {}
          }

          // Show local notification
          final booking = state.booking;
          await NotificationService().showBookingConfirmation(
            venueName: booking.venueName,
            date: _dateFmt.format(booking.startTime),
            time: _timeFmt.format(booking.startTime),
          );

          if (context.mounted) {
            context.go('/booking/success', extra: booking);
          }
        } else if (state is BookingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
        }
      },
      builder: (context, state) {
        if (state is SlotHeld) _lastHeld = state;
        final held = state is SlotHeld ? state : _lastHeld;

        if (held == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Confirm Booking')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No slot selected.'),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go back'),
                  ),
                ],
              ),
            ),
          );
        }

        final authState = context.read<AuthBloc>().state;
        final user = authState is AuthAuthenticated ? authState.user : null;

        final bool hasLoyaltyDiscount = user?.loyaltyDiscountEligible ?? false;
        final double displayPrice = hasLoyaltyDiscount
            ? held.totalPrice * (1 - AppConstants.loyaltyDiscountPercent)
            : held.totalPrice;
        final double halfPrice = displayPrice / 2.0;
        final double hourlyDeposit = AppConstants.depositPerHour * (held.durationMinutes / 60.0);
        final double depositAmount = halfPrice + hourlyDeposit;
        final double cashDueAmount = displayPrice - halfPrice;
        final bool walletSufficient =
            (user?.walletBalance ?? 0) >= depositAmount;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Confirm Booking'),
            leading: BackButton(
              onPressed: () {
                context.read<BookingBloc>().add(ReleaseHold(authState is AuthAuthenticated ? authState.user.uid : ''));
                context.pop();
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBookingSummary(context, held),
                const SizedBox(height: 20),

                // Loyalty discount banner
                if (hasLoyaltyDiscount) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.card_giftcard_rounded,
                            color: AppColors.success, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Loyalty 50% OFF applied!',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'You\'ve earned a discount for your loyalty',
                                style: TextStyle(
                                    color: AppColors.success.withValues(alpha: 0.8),
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Payment method
                _buildPaymentSection(user?.walletBalance ?? 0, walletSufficient),
                const SizedBox(height: 20),

                // Payment proof (manual transfer methods only)
                if (_isManualPayment) ...[
                  _buildPaymentProofSection(),
                  const SizedBox(height: 20),
                ],

                // Open match section
                _buildOpenMatchSection(context),
                const SizedBox(height: 24),

                // Total row
                _buildTotalRow(context, depositAmount, cashDueAmount, hasLoyaltyDiscount, held.totalPrice),
                const SizedBox(height: 20),

                AppButton(
                  label: _isCardPayment
                      ? 'Enter Card Details (EGP ${depositAmount.toStringAsFixed(0)})'
                      : 'Pay Deposit (EGP ${depositAmount.toStringAsFixed(0)}) & Confirm',
                  isLoading: state is BookingInProgress || _uploadingProof,
                  onPressed: () => _proceed(context, hasLoyaltyDiscount),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Cancel',
                  isOutlined: true,
                  onPressed: () {
                    context.read<BookingBloc>().add(ReleaseHold(authState is AuthAuthenticated ? authState.user.uid : ''));
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

  Widget _buildBookingSummary(BuildContext context, SlotHeld held) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _SummaryRow(icon: Icons.sports_tennis_rounded, label: 'Venue', value: widget.venueName),
          const Divider(height: 20),
          _SummaryRow(icon: Icons.grid_view_rounded, label: 'Court', value: widget.courtName),
          const Divider(height: 20),
          _SummaryRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: _dateFmt.format(held.startTime),
          ),
          const Divider(height: 20),
          _SummaryRow(
            icon: Icons.access_time_rounded,
            label: 'Time',
            value: '${_timeFmt.format(held.startTime)} — ${_timeFmt.format(held.endTime)}',
          ),
          const Divider(height: 20),
          _SummaryRow(
            icon: Icons.timer_outlined,
            label: 'Duration',
            value: '${held.durationMinutes} min${held.slots.length > 1 ? ' (${held.slots.length} slots)' : ''}',
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(double walletBalance, bool walletSufficient) {
    final methods = [
      (AppConstants.paymentVodafone, Icons.phone_android_rounded, 'Vodafone Cash', false, null),
      (AppConstants.paymentInstaPay, Icons.send_rounded, 'InstaPay', false, null),
      (AppConstants.paymentCard, Icons.credit_card_rounded, 'Card (Visa / MC)', true, const Text('Coming soon', style: TextStyle(color: AppColors.textHint, fontSize: 11))),
      (AppConstants.paymentFawry, Icons.account_balance_rounded, 'Fawry', true, const Text('Coming soon', style: TextStyle(color: AppColors.textHint, fontSize: 11))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              ...methods.map((m) {
                final isSelected = _selectedPayment == m.$1;
                return _PaymentOption(
                  icon: m.$2,
                  label: m.$3,
                  isSelected: isSelected,
                  disabled: m.$4,
                  suffix: m.$5,
                  onTap: () => setState(() => _selectedPayment = m.$1),
                );
              }),
              // Wallet option
              _PaymentOption(
                icon: Icons.account_balance_wallet_rounded,
                label:
                    'Wallet (Balance: EGP ${walletBalance.toStringAsFixed(2)})',
                isSelected: _selectedPayment == AppConstants.paymentWallet,
                disabled: !walletSufficient,
                suffix: !walletSufficient
                    ? const Text(
                        'Insufficient',
                        style: TextStyle(color: AppColors.error, fontSize: 11),
                      )
                    : null,
                onTap: walletSufficient
                    ? () => setState(() => _selectedPayment = AppConstants.paymentWallet)
                    : null,
              ),
            ],
          ),
        ),
        if (_isManualPayment) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.secondary, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please send the money to the number the admin assigns to his court, then upload the screenshot below.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOpenMatchSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_add_rounded, color: AppColors.secondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Open to Community',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Let other players join & split the cost',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 10),
            const Text(
              'Skill Range',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${_minSkill.toStringAsFixed(1)} – ${_maxSkill.toStringAsFixed(1)}',
              style: const TextStyle(color: AppColors.secondary, fontSize: 12),
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
          ],
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    BuildContext context,
    double depositAmount,
    double cashDueAmount,
    bool hasDiscount,
    double originalPrice,
  ) {
    final grandTotal = depositAmount + cashDueAmount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Court price (cash at venue)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              Row(
                children: [
                  if (hasDiscount) ...[
                    Text(
                      'EGP ${originalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textHint,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    'EGP ${cashDueAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Booking deposit (pay now)',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Text(
                'EGP ${depositAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'You\'ll pay in total',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              Text(
                'EGP ${grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentProofSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment screenshot',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upload proof of your transfer for the deposit amount above.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          if (_proofImage == null)
            Container(
              height: 120,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.cardElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'No screenshot yet',
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
            )
          else
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: FutureBuilder<Uint8List>(
                    future: _proofImage!.readAsBytes(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 160,
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        );
                      }
                      return Image.memory(
                        snapshot.data!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    onPressed: _uploadingProof ? null : () => setState(() => _proofImage = null),
                    icon: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploadingProof ? null : () => _pickProofImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Take photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploadingProof ? null : () => _pickProofImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickProofImage(ImageSource source) async {
    try {
      final image = source == ImageSource.camera
          ? await _proofStorage.pickFromCamera()
          : await _proofStorage.pickFromGallery();
      if (image == null || !mounted) return;
      setState(() => _proofImage = image);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  /// Card payment needs its own details screen; every other method confirms
  /// right here (manual transfer methods just need the proof photo above;
  /// wallet needs nothing extra at all).
  Future<void> _proceed(BuildContext context, bool useLoyaltyDiscount) async {
    if (_isCardPayment) {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) return;
      context.push('/booking/card-payment', extra: {
        'venueName': widget.venueName,
        'courtName': widget.courtName,
        'useLoyaltyDiscount': useLoyaltyDiscount,
      });
      return;
    }
    await _confirm(context, useLoyaltyDiscount);
  }

  Future<void> _confirm(BuildContext context, bool useLoyaltyDiscount) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    if (_isManualPayment && _proofImage == null) {
      _showSnack(context, 'Please add a photo of your payment screenshot.');
      return;
    }

    final bookingBloc = context.read<BookingBloc>();
    final bookingState = bookingBloc.state;
    if (bookingState is! SlotHeld) return;

    String? proofUrl;
    if (_isManualPayment) {
      setState(() => _uploadingProof = true);
      try {
        proofUrl = await _proofStorage.uploadPaymentProof(
          image: _proofImage!,
          userId: authState.user.uid,
          bookingId: '${bookingState.venueId}_${bookingState.courtId}_${bookingState.slots.first.id}',
        );
      } catch (e) {
        if (!context.mounted) return;
        _showSnack(context, 'Failed to upload payment screenshot: $e');
        setState(() => _uploadingProof = false);
        return;
      }
      if (!context.mounted) return;
      setState(() => _uploadingProof = false);
    }

    bookingBloc.add(ConfirmBooking(
          userId: authState.user.uid,
          venueName: widget.venueName,
          courtName: widget.courtName,
          paymentMethod: _selectedPayment,
          useLoyaltyDiscount: useLoyaltyDiscount,
          paymentProofUrl: proofUrl,
        ));
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _createOpenMatch(BuildContext context, BookingSuccess state) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

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
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool disabled;
  final Widget? suffix;
  final VoidCallback? onTap;

  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.disabled = false,
    this.suffix,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: disabled
                    ? AppColors.textHint
                    : isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: disabled ? AppColors.textHint : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (suffix != null) suffix!,
            if (!disabled)
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppColors.primary : AppColors.textHint,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
