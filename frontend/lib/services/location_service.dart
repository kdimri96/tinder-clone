import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class LocationService {
  static Future<void> updateUserLocation(ApiService api) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      await api.updateLocation(position.latitude, position.longitude);
    } catch (_) {
      // Location unavailable — app still works, just no distance filter
    }
  }
}
