import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/booking/data/models/time_slot_model.dart';
import 'package:padel/features/booking/data/services/booking_service.dart';
import 'package:padel/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:padel/features/booking/presentation/bloc/booking_event.dart';
import 'package:padel/features/booking/presentation/bloc/booking_state.dart';
import 'package:padel/features/venues/data/models/court_model.dart';
import 'package:padel/features/venues/data/models/venue_model.dart';
import 'package:padel/features/venues/presentation/bloc/venues_bloc.dart';
import 'package:padel/features/venues/presentation/bloc/venues_event.dart';
import 'package:padel/features/venues/presentation/bloc/venues_state.dart';

class VenueDetailScreen extends StatefulWidget {
  final String venueId;
  const VenueDetailScreen({super.key, required this.venueId});

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  DateTime _selectedDate = DateTime.now();
  CourtModel? _selectedCourt;
  final List<TimeSlotModel> _selectedSlots = [];

  // Courts x time grid: loaded once per date change (a one-shot fetch, not a
  // live stream — good enough for browsing/picking; the actual hold/confirm
  // step still re-validates availability atomically server-side).
  Map<String, List<TimeSlotModel>> _slotsByCourt = {};
  bool _gridLoading = false;
  String? _loadedForDateKey;

  static final _dateLabelFmt = DateFormat('EEE');
  static final _dateDayFmt = DateFormat('d');
  static final _timeFmt = DateFormat('HH:mm');
  static final _dateKeyFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    // BookingBloc is a single app-wide instance, so it may still be holding
    // state left over from a previous visit (a completed/errored booking,
    // an unreleased hold, etc). Reset it so this visit always starts fresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BookingBloc>().add(const ResetBooking());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VenuesBloc, VenuesState>(
      builder: (context, state) {
        if (state is VenueDetailLoading || state is VenuesLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: AppLoadingSpinner(),
          );
        }
        if (state is VenuesError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(),
            body: AppErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<VenuesBloc>().add(LoadVenueDetail(widget.venueId)),
            ),
          );
        }
        if (state is VenueDetailLoaded) {
          return _buildContent(context, state.venue, state.courts);
        }
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: AppLoadingSpinner(),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, VenueModel venue, List<CourtModel> courts) {
    _loadGridIfNeeded(venue, courts);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Navy hero header
          _buildHero(context, venue),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Venue name + location
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venue.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final query = '${venue.address}, ${venue.city}';
                            final storedMapsUrl = venue.googleMapsUrl?.trim();
                            final googleMapsUrl = storedMapsUrl != null && storedMapsUrl.isNotEmpty
                              ? Uri.parse(storedMapsUrl)
                              : Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=${venue.latitude},${venue.longitude}');
                            final fallbackUrl = Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');

                            try {
                              if (venue.latitude != 0.0 && venue.longitude != 0.0) {
                                if (await canLaunchUrl(googleMapsUrl)) {
                                  await launchUrl(googleMapsUrl,
                                      mode: LaunchMode.externalApplication);
                                } else {
                                  await launchUrl(fallbackUrl,
                                      mode: LaunchMode.externalApplication);
                                }
                              } else {
                                if (await canLaunchUrl(fallbackUrl)) {
                                  await launchUrl(fallbackUrl,
                                      mode: LaunchMode.externalApplication);
                                }
                              }
                            } catch (_) {
                              if (await canLaunchUrl(fallbackUrl)) {
                                await launchUrl(fallbackUrl);
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 13, color: AppColors.secondary),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    '${venue.address}, ${venue.city}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3 stat boxes
                  _buildStatBoxes(courts),

                  // Date strip
                  _buildDateStrip(venue, courts),

                  // Courts x time grid
                  _buildCourtsTimeGrid(venue, courts),

                  const SizedBox(height: 100), // space for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      // Book button at bottom
      bottomNavigationBar: _buildBookBar(context, venue),
    );
  }

  Widget _buildHero(BuildContext context, VenueModel venue) {
    return Container(
      height: 110,
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Court diagram centered
            Center(
              child: Opacity(
                opacity: 0.4,
                child: CustomPaint(
                  size: const Size(200, 80),
                  painter: _CourtHeroPainter(),
                ),
              ),
            ),
            // Back button
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: () => context.go('/venues'),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.textOnDark),
                ),
              ),
            ),
            // Indoor·AC badge
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.navyLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    venue.amenities.hasShowers ? 'Indoor · AC' : 'Outdoor',
                    style: const TextStyle(
                      color: AppColors.textBlueGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBoxes(List<CourtModel> courts) {
    final minPrice = courts.isNotEmpty
        ? courts.map((c) => c.offPeakPrice).reduce((a, b) => a < b ? a : b)
        : 90.0;
    // We use venue rating from bloc state
    final venueState = context.read<VenuesBloc>().state;
    final rating = venueState is VenueDetailLoaded ? venueState.venue.rating : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          _StatBox(
            label: 'Price',
            value: 'EGP ${minPrice.toInt()}/hr',
            color: AppColors.primary,
            textColor: Colors.white,
          ),
          const SizedBox(width: 10),
          _StatBox(
            label: 'Rating',
            value: rating.toStringAsFixed(1),
            color: AppColors.successLight,
            textColor: AppColors.success,
          ),
          const SizedBox(width: 10),
          _StatBox(
            label: 'Courts',
            value: '${courts.length}',
            color: AppColors.cardElevated,
            textColor: AppColors.textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildDateStrip(VenueModel venue, List<CourtModel> courts) {
    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select date',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final date = today.add(Duration(days: i));
                final isSelected = _selectedDate.year == date.year &&
                    _selectedDate.month == date.month &&
                    _selectedDate.day == date.day;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _selectedSlots.clear();
                      _selectedCourt = null;
                    });
                    context.read<BookingBloc>().add(const ResetBooking());
                    _loadGrid(venue, courts);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.divider,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dateLabelFmt.format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white.withValues(alpha: 0.8) : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dateDayFmt.format(date),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Triggers the grid fetch at most once per date (guarded so rebuilds from
  /// unrelated state changes — e.g. the booking hold listener — don't
  /// refetch on every frame).
  void _loadGridIfNeeded(VenueModel venue, List<CourtModel> courts) {
    final key = _dateKeyFmt.format(_selectedDate);
    if (_loadedForDateKey == key || _gridLoading) return;
    _loadGrid(venue, courts);
  }

  void _loadGrid(VenueModel venue, List<CourtModel> courts) {
    final key = _dateKeyFmt.format(_selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _gridLoading = true);
      try {
        final result = await context.read<BookingService>().getVenueSlotsForDate(
              venueId: venue.id,
              courts: courts,
              date: _selectedDate,
              openingHour: venue.openingHour,
              closingHour: venue.closingHour,
            );
        if (!mounted) return;
        setState(() {
          _slotsByCourt = result;
          _loadedForDateKey = key;
          _gridLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _gridLoading = false);
      }
    });
  }

  Widget _buildCourtsTimeGrid(VenueModel venue, List<CourtModel> courts) {
    if (_gridLoading && _slotsByCourt.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final times = _slotsByCourt.values
        .expand((slots) => slots.map((s) => s.startTime))
        .toSet()
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available slots',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _LegendDot(color: AppColors.primary, label: 'Selected'),
              const SizedBox(width: 12),
              _LegendDot(color: AppColors.textHint, label: 'Booked'),
            ],
          ),
          const SizedBox(height: 10),
          if (times.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No slots available for this date',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            )
          else if (courts.length == 1)
            // Single court: wide centered 2-column grid
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3.2,
              ),
              itemCount: times.length,
              itemBuilder: (_, i) => _buildGridCell(courts.first, times[i]),
            )
          else
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: FixedColumnWidth(
                    courts.length == 2 ? 180 : 140,
                  ),
                  children: [
                    TableRow(
                      children: courts
                          .map((court) => Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    court.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    ...times.map((time) => TableRow(
                          children: courts.map((court) => _buildGridCell(court, time)).toList(),
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridCell(CourtModel court, DateTime time) {
    final slots = _slotsByCourt[court.id] ?? [];
    TimeSlotModel? slot;
    for (final s in slots) {
      if (s.startTime.isAtSameMomentAs(time)) {
        slot = s;
        break;
      }
    }

    if (slot == null) {
      return const Padding(padding: EdgeInsets.all(4), child: SizedBox(height: 54));
    }

    final isSelected = _selectedSlots.any((s) => s.id == slot!.id);
    final isPast = slot.startTime.isBefore(DateTime.now());
    final isBooked = slot.status == SlotStatus.booked ||
        slot.status == SlotStatus.maintenance ||
        (slot.status == SlotStatus.held && slot.heldBy != _currentUserId(context));
    final isUnavailable = isBooked || isPast;

    Color bgColor;
    Color textColor;
    if (isSelected) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
    } else if (isUnavailable) {
      bgColor = AppColors.cardElevated;
      textColor = AppColors.textHint;
    } else {
      bgColor = AppColors.card;
      textColor = AppColors.textPrimary;
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        onTap: isUnavailable ? null : () => _toggleSlot(court, slot!),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _timeFmt.format(slot.startTime),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
              ),
              const SizedBox(width: 8),
              Text(
                'EGP ${slot.price.toInt()}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white70 : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _currentUserId(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated ? authState.user.uid : null;
  }

  /// Toggles a slot in/out of the selection. Tapping an already-selected slot
  /// removes it (from either end of the run); tapping a new slot only adds it
  /// if it's immediately adjacent to the current contiguous selection, so the
  /// resulting booking always spans one continuous time range. Tapping a slot
  /// on a *different* court than the current selection starts a fresh
  /// selection there instead — a booking can only ever be for one court.
  void _toggleSlot(CourtModel court, TimeSlotModel slot) {
    if (_selectedCourt?.id != court.id) {
      setState(() {
        _selectedCourt = court;
        _selectedSlots
          ..clear()
          ..add(slot);
      });
      return;
    }

    setState(() {
      final idx = _selectedSlots.indexWhere((s) => s.id == slot.id);
      if (idx != -1) {
        final isAtEdge =
            slot.id == _selectedSlots.first.id || slot.id == _selectedSlots.last.id;
        if (isAtEdge) {
          _selectedSlots.removeAt(idx);
        } else {
          _showSnack('Remove slots from the start or end of your selection');
        }
        return;
      }

      if (_selectedSlots.isEmpty) {
        _selectedSlots.add(slot);
        return;
      }

      if (slot.startTime.isAtSameMomentAs(_selectedSlots.last.endTime)) {
        _selectedSlots.add(slot);
      } else if (slot.endTime.isAtSameMomentAs(_selectedSlots.first.startTime)) {
        _selectedSlots.insert(0, slot);
      } else {
        _showSnack('Please select consecutive time slots');
      }
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildBookBar(BuildContext context, VenueModel venue) {
    final totalPrice = _selectedSlots.fold(0.0, (sum, s) => sum + s.price);
    final hasSelection = _selectedSlots.isNotEmpty;
    final authState = context.read<AuthBloc>().state;
    final isAuthenticated = authState is AuthAuthenticated;

    return BlocListener<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is SlotHeld) {
          context.push('/booking/confirm', extra: {
            'venueName': venue.name,
            'courtName': _selectedCourt?.name ?? '',
          });
        } else if (state is BookingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SafeArea(
          top: false,
          child: BlocBuilder<BookingBloc, BookingState>(
            builder: (context, bookingState) {
              final isLoading = bookingState is SlotHolding;
              final buttonLabel = !isAuthenticated
                  ? 'Sign in to book'
                  : hasSelection
                      ? 'Book for EGP ${totalPrice.toStringAsFixed(0)}'
                      : 'Select a time slot';
              return ElevatedButton(
                onPressed: hasSelection && !isLoading
                    ? () => isAuthenticated ? _holdSlot(context) : _promptSignIn(context)
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor:
                      hasSelection ? AppColors.primary : AppColors.textHint,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        buttonLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _holdSlot(BuildContext context) {
    if (_selectedSlots.isEmpty) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      _promptSignIn(context);
      return;
    }

    context.read<BookingBloc>().add(HoldSlots(
          slots: List.of(_selectedSlots),
          userId: authState.user.uid,
        ));
  }

  void _promptSignIn(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign in to book'),
        content: const Text(
          'Court availability is public, but booking a court requires an account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push('/login');
            },
            child: const Text('Go to login'),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color textColor;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: textColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
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
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _CourtHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final w = size.width;
    final h = size.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), paint);
    canvas.drawLine(Offset(w * 0.25, h * 0.2), Offset(w * 0.25, h * 0.8), paint);
    canvas.drawLine(Offset(w * 0.75, h * 0.2), Offset(w * 0.75, h * 0.8), paint);
    canvas.drawLine(Offset(w * 0.25, h / 2), Offset(w * 0.75, h / 2), paint);
    paint.strokeWidth = 4;
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
