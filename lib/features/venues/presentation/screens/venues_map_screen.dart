import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/services/location_service.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/venues/data/models/venue_model.dart';
import 'package:padel/features/venues/presentation/bloc/venues_bloc.dart';
import 'package:padel/features/venues/presentation/bloc/venues_event.dart';
import 'package:padel/features/venues/presentation/bloc/venues_state.dart';

/// Cairo, Egypt — used as the map's default center when the user's location
/// isn't available yet (permission not granted, or still resolving).
const _fallbackCenter = LatLng(30.0444, 31.2357);

class VenuesMapScreen extends StatefulWidget {
  const VenuesMapScreen({super.key});

  @override
  State<VenuesMapScreen> createState() => _VenuesMapScreenState();
}

class _VenuesMapScreenState extends State<VenuesMapScreen> {
  final _locationService = LocationService();
  final _mapController = MapController();

  LatLng? _userLocation;
  String? _locationError;
  bool _locating = true;
  VenueModel? _selectedVenue;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final position = await _locationService.getCurrentLocation();
      final location = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _userLocation = location;
        _locating = false;
      });
      _mapController.move(location, 13);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString().replaceFirst('Exception: ', '');
        _locating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Courts Near Me'),
        actions: [
          IconButton(
            onPressed: _resolveLocation,
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Use my location',
          ),
        ],
      ),
      body: BlocBuilder<VenuesBloc, VenuesState>(
        builder: (context, state) {
          if (state is VenuesLoading) return const AppLoadingSpinner();
          if (state is VenuesError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<VenuesBloc>().add(const LoadVenues()),
            );
          }
          if (state is! VenuesLoaded) return const AppLoadingSpinner();

          final venues = state.filtered.where((v) => v.latitude != 0 || v.longitude != 0).toList();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _userLocation ?? _fallbackCenter,
                  initialZoom: _userLocation != null ? 13 : 6,
                  onTap: (_, __) => setState(() => _selectedVenue = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.padel.app',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_userLocation != null)
                        Marker(
                          point: _userLocation!,
                          width: 22,
                          height: 22,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.secondary,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      for (final venue in venues)
                        Marker(
                          point: LatLng(venue.latitude, venue.longitude),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedVenue = venue),
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 40,
                              color: _selectedVenue?.id == venue.id
                                  ? AppColors.primary
                                  : AppColors.navy,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (_locating)
                const Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(child: _LocatingBanner()),
                ),
              if (_locationError != null)
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: _ErrorBanner(message: _locationError!, onRetry: _resolveLocation),
                ),
              if (_selectedVenue != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _VenuePreviewCard(
                    venue: _selectedVenue!,
                    distanceKm: _userLocation != null
                        ? _locationService.distanceKm(
                            _userLocation!.latitude,
                            _userLocation!.longitude,
                            _selectedVenue!.latitude,
                            _selectedVenue!.longitude,
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LocatingBanner extends StatelessWidget {
  const _LocatingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 10),
          Text('Finding your location…', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _VenuePreviewCard extends StatelessWidget {
  final VenueModel venue;
  final double? distanceKm;
  const _VenuePreviewCard({required this.venue, this.distanceKm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        venue.address.isNotEmpty ? venue.address : venue.city,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (distanceKm != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${distanceKm!.toStringAsFixed(1)} km away',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppButton(
            label: 'View',
            width: 90,
            onPressed: () => context.push('/venues/${venue.id}'),
          ),
        ],
      ),
    );
  }
}
