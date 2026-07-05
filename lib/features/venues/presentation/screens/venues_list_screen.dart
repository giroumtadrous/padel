import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/services/location_service.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/core/widgets/notification_bell.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/venues/data/models/venue_model.dart';
import 'package:padel/features/venues/presentation/bloc/venues_bloc.dart';
import 'package:padel/features/venues/presentation/bloc/venues_event.dart';
import 'package:padel/features/venues/presentation/bloc/venues_state.dart';
import 'package:google_fonts/google_fonts.dart';

class VenuesListScreen extends StatefulWidget {
  const VenuesListScreen({super.key});

  @override
  State<VenuesListScreen> createState() => _VenuesListScreenState();
}

class _VenuesListScreenState extends State<VenuesListScreen> {
  final _searchCtrl = TextEditingController();
  final _locationService = LocationService();
  String _selectedSport = 'Padel';
  bool _sortByDistance = false;
  bool _locatingForSort = false;
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    context.read<VenuesBloc>().add(const LoadVenues());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleSortByDistance() async {
    if (_sortByDistance) {
      setState(() => _sortByDistance = false);
      return;
    }

    if (_userLat != null && _userLng != null) {
      setState(() => _sortByDistance = true);
      return;
    }

    setState(() => _locatingForSort = true);
    try {
      final position = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
        _sortByDistance = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _locatingForSort = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildNavyHeader(context),
          Expanded(
            child: BlocBuilder<VenuesBloc, VenuesState>(
              builder: (context, state) {
                if (state is VenuesLoading) return const ShimmerList();
                if (state is VenuesError) {
                  return AppErrorView(
                    message: state.message,
                    onRetry: () => context.read<VenuesBloc>().add(const LoadVenues()),
                  );
                }
                if (state is VenuesLoaded) {
                  final venues = _sortByDistance && _userLat != null && _userLng != null
                      ? (List<VenueModel>.from(state.filtered)
                          ..sort((a, b) => _locationService
                              .distanceKm(_userLat!, _userLng!, a.latitude, a.longitude)
                              .compareTo(_locationService.distanceKm(
                                  _userLat!, _userLng!, b.latitude, b.longitude))))
                      : state.filtered;

                  if (venues.isEmpty) {
                    return const AppEmptyView(
                      title: 'No venues found',
                      subtitle: 'Try a different search term',
                      icon: Icons.search_off_rounded,
                    );
                  }
                  return _buildBody(context, venues);
                }
                return const ShimmerList();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavyHeader(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;
        final name = user?.displayName.split(' ').first ?? '';

        return Container(
          color: AppColors.navy,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isNotEmpty ? 'Hi, $name!' : 'Find a Court',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textOnDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Book your next padel session',
                              style: TextStyle(color: AppColors.textBlueGrey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (user != null) NotificationBell(userId: user.uid),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary,
                          backgroundImage: user?.photoUrl != null
                              ? NetworkImage(user!.photoUrl!)
                              : null,
                          child: user?.photoUrl == null
                              ? Text(
                                  (user?.displayName.isNotEmpty == true)
                                      ? user!.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Search courts, cities...',
                      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textHint),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                context.read<VenuesBloc>().add(const SearchVenues(''));
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear_rounded, size: 16),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onChanged: (v) {
                      context.read<VenuesBloc>().add(SearchVenues(v));
                      setState(() {});
                    },
                  ),
                ),
                // Wave divider
                ClipPath(
                  clipper: _WaveClipper(),
                  child: Container(
                    height: 22,
                    color: AppColors.background,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, List<VenueModel> venues) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _buildSportPills(),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${venues.length} venues',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/venues/map'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 14, color: AppColors.textHint),
                  SizedBox(width: 4),
                  Text('Map', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _locatingForSort ? null : _toggleSortByDistance,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _locatingForSort
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                        )
                      : Icon(
                          Icons.near_me_rounded,
                          size: 14,
                          color: _sortByDistance ? AppColors.primary : AppColors.textHint,
                        ),
                  const SizedBox(width: 4),
                  Text(
                    'Near me',
                    style: TextStyle(
                      fontSize: 12,
                      color: _sortByDistance ? AppColors.primary : AppColors.textHint,
                      fontWeight: _sortByDistance ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...venues.map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _VenueCard(venue: v),
            )),
      ],
    );
  }

  Widget _buildSportPills() {
    final sports = ['Padel', 'Football', 'Tennis'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: sports.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sport = sports[i];
          final selected = sport == _selectedSport;
          return GestureDetector(
            onTap: () => setState(() => _selectedSport = sport),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Text(
                sport,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  final VenueModel venue;

  const _VenueCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/venues/${venue.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dark blue header with court diagram
            Stack(
              children: [
                Container(
                  height: 110,
                  color: AppColors.navyMid,
                  child: Center(
                    child: Opacity(
                      opacity: 0.35,
                      child: CustomPaint(
                        size: const Size(160, 90),
                        painter: _CourtDiagramPainter(),
                      ),
                    ),
                  ),
                ),
                // Indoor/Outdoor badge
                Positioned(
                  top: 10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: venue.amenities.hasShowers ? AppColors.gold : const Color(0xFF757575),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      venue.amenities.hasShowers ? 'Indoor' : 'Outdoor',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Card body
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'EGP 90/hr',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          venue.city,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded, size: 13, color: AppColors.gold),
                      const SizedBox(width: 2),
                      Text(
                        venue.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (venue.reviewCount > 0) ...[
                        const SizedBox(width: 2),
                        Text(
                          '(${venue.reviewCount})',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wave clipper for the navy-to-cream transition
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 0);
    path.cubicTo(
      size.width * 0.25, size.height * 1.2,
      size.width * 0.75, -size.height * 0.2,
      size.width, size.height,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Minimal padel court diagram
class _CourtDiagramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final w = size.width;
    final h = size.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), paint);
    canvas.drawLine(Offset(w * 0.25, h * 0.25), Offset(w * 0.25, h * 0.75), paint);
    canvas.drawLine(Offset(w * 0.75, h * 0.25), Offset(w * 0.75, h * 0.75), paint);
    canvas.drawLine(Offset(w * 0.25, h / 2), Offset(w * 0.75, h / 2), paint);
    paint.strokeWidth = 3;
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
