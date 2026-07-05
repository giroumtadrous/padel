import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:google_fonts/google_fonts.dart';

class BookingSuccessScreen extends StatelessWidget {
  final BookingModel booking;

  const BookingSuccessScreen({super.key, required this.booking});

  static final _dateFmt = DateFormat('EEE, MMM d, yyyy');
  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final ref = booking.id.substring(0, 8).toUpperCase();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Green check circle
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Booking Confirmed!',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your court is reserved',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),

              // Dark navy booking card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              booking.venueName,
                              style: const TextStyle(
                                color: AppColors.textOnDark,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PADEL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Details grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _DetailCell(
                                label: 'DATE',
                                value: _dateFmt.format(booking.startTime),
                              ),
                              _DetailCell(
                                label: 'TIME',
                                value:
                                    '${_timeFmt.format(booking.startTime)} – ${_timeFmt.format(booking.endTime)}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _DetailCell(label: 'COURT', value: booking.courtName),
                              _DetailCell(
                                label: 'DEPOSIT PAID',
                                value: 'EGP ${booking.depositAmount.toStringAsFixed(0)}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // QR code placeholder
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.navyLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CustomPaint(painter: _QrPlaceholderPainter()),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Show at venue entrance',
                            style: TextStyle(
                              color: AppColors.textBlueGrey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Cash-due / verification banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: booking.paymentStatus == AppConstants.paymentPending
                      ? AppColors.warning.withValues(alpha: 0.12)
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: booking.paymentStatus == AppConstants.paymentPending
                        ? AppColors.warning
                        : AppColors.divider,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (booking.paymentStatus == AppConstants.paymentPending)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Your payment screenshot is awaiting verification. '
                          'We\'ll confirm your deposit shortly.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pay at venue (cash)',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        Text(
                          'EGP ${booking.cashDueAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Booking ref
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Booking Reference',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 2),
                          Text(
                            ref,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: ref));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reference copied!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Share intent placeholder
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Share feature coming soon')),
                        );
                      },
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Calendar feature coming soon')),
                        );
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: const Text('Calendar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/bookings'),
                  child: const Text('View My Bookings'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCell extends StatelessWidget {
  final String label;
  final String value;
  const _DetailCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textOnDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Custom painter that draws a simple QR-like pattern placeholder.
class _QrPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final bgPaint = Paint()
      ..color = const Color(0xFF112840)
      ..style = PaintingStyle.fill;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final cellSize = size.width / 12;

    // Draw random-looking cells to simulate QR
    final rng = math.Random(42); // fixed seed for consistency
    for (int row = 0; row < 12; row++) {
      for (int col = 0; col < 12; col++) {
        // Always draw corners
        final isTopLeft = row < 3 && col < 3;
        final isTopRight = row < 3 && col >= 9;
        final isBottomLeft = row >= 9 && col < 3;

        bool drawCell;
        if (isTopLeft || isTopRight || isBottomLeft) {
          // Corner finder pattern — always solid
          drawCell = !(row >= 1 && row <= 1 && col >= 1 && col <= 1) || rng.nextBool();
        } else {
          drawCell = rng.nextBool();
        }

        if (drawCell) {
          canvas.drawRect(
            Rect.fromLTWH(
              col * cellSize + 1,
              row * cellSize + 1,
              cellSize - 2,
              cellSize - 2,
            ),
            paint,
          );
        }
      }
    }

    // Draw corner markers (3x3 squares with border)
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final offset in [
      const Offset(0, 0),
      Offset(size.width - cellSize * 4, 0),
      Offset(0, size.height - cellSize * 4),
    ]) {
      canvas.drawRect(
        Rect.fromLTWH(offset.dx + 1, offset.dy + 1, cellSize * 4 - 2, cellSize * 4 - 2),
        borderPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
            offset.dx + cellSize + 2, offset.dy + cellSize + 2, cellSize * 2 - 4, cellSize * 2 - 4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
