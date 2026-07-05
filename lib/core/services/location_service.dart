import 'package:geolocator/geolocator.dart';

/// Wraps [Geolocator] permission handling so callers get either a position
/// or a clear reason it's unavailable, instead of dealing with the
/// service-enabled/permission-denied/denied-forever branches themselves.
class LocationService {
  Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable them to find courts near you.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permission is permanently denied. Please enable it from your device settings.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  }

  /// Distance in kilometers between two coordinates.
  double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }
}
