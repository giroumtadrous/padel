import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
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
  @override
  void initState() {
    super.initState();
    context.read<VenuesBloc>().add(LoadVenueDetail(widget.venueId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VenuesBloc, VenuesState>(
      builder: (context, state) {
        if (state is VenueDetailLoading || state is VenuesLoading) {
          return Scaffold(appBar: AppBar(), body: const AppLoadingSpinner());
        }
        if (state is VenuesError) {
          return Scaffold(
            appBar: AppBar(),
            body: AppErrorView(
              message: state.message,
              onRetry: () => context.read<VenuesBloc>().add(LoadVenueDetail(widget.venueId)),
            ),
          );
        }
        if (state is VenueDetailLoaded) {
          return _VenueDetailContent(venue: state.venue, courts: state.courts);
        }
        return Scaffold(appBar: AppBar(), body: const AppLoadingSpinner());
      },
    );
  }
}

class _VenueDetailContent extends StatelessWidget {
  final VenueModel venue;
  final List<CourtModel> courts;

  const _VenueDetailContent({required this.venue, required this.courts});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVenueInfo(context),
                  const SizedBox(height: 24),
                  _buildAmenities(context),
                  const SizedBox(height: 24),
                  Text('Courts', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _CourtCard(court: courts[i], venueId: venue.id),
              ),
              childCount: courts.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      leading: BackButton(onPressed: () => context.go('/venues')),
      flexibleSpace: FlexibleSpaceBar(
        background: venue.imageUrls.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: venue.imageUrls.first,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ShimmerCard(height: 220, borderRadius: 0),
                errorWidget: (_, __, ___) => Container(color: AppColors.surface),
              )
            : Container(color: AppColors.surface),
      ),
    );
  }

  Widget _buildVenueInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(venue.name, style: Theme.of(context).textTheme.displayMedium)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 4),
                  Text(venue.rating.toStringAsFixed(1),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Expanded(child: Text(venue.address, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.access_time_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              'Open ${venue.openingHour}:00 — ${venue.closingHour}:00',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        if (venue.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(venue.description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }

  Widget _buildAmenities(BuildContext context) {
    final items = <Map<String, dynamic>>[];
    if (venue.amenities.hasShowers) items.add({'icon': Icons.shower_outlined, 'label': 'Showers'});
    if (venue.amenities.hasRacketRental) items.add({'icon': Icons.sports_tennis_rounded, 'label': 'Racket Rental'});
    if (venue.amenities.hasParking) items.add({'icon': Icons.local_parking_rounded, 'label': 'Parking'});
    if (venue.amenities.hasCafe) items.add({'icon': Icons.coffee_rounded, 'label': 'Café'});

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Amenities', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Row(
          children: items.map((item) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(item['icon'] as IconData, color: AppColors.primary, size: 22),
                  const SizedBox(height: 4),
                  Text(item['label'] as String, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }
}

class _CourtCard extends StatelessWidget {
  final CourtModel court;
  final String venueId;

  const _CourtCard({required this.court, required this.venueId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/venues/$venueId/book/${court.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sports_tennis_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(court.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    '${_capitalize(court.courtType)} · ${_capitalize(court.surface)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.offPeak.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'EGP ${court.offPeakPrice.toInt()}',
                    style: const TextStyle(color: AppColors.offPeak, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.peakHour.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Peak: EGP ${court.peakHourPrice.toInt()}',
                    style: const TextStyle(color: AppColors.peakHour, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}
