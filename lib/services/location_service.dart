import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Request location permission
  Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  // Check if location permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check permission
      bool hasPerms = await hasPermission();
      if (!hasPerms) {
        hasPerms = await requestPermission();
        if (!hasPerms) {
          throw Exception('Location permission denied');
        }
      }

      // Get position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return position;
    } catch (e) {
      AppLogger.error('Error getting location', e);
      return null;
    }
  }

  // Get address from coordinates (reverse geocoding)
  Future<Map<String, String?>> getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        
        String? fullAddress = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((s) => s != null && s.isNotEmpty).join(', ');

        return {
          'address': fullAddress.isEmpty ? null : fullAddress,
          'city': place.locality ?? place.administrativeArea,
          'country': place.country,
          'street': place.street,
          'postalCode': place.postalCode,
        };
      }
    } catch (e) {
      AppLogger.error('Error reverse geocoding', e);
    }

    return {
      'address': null,
      'city': null,
      'country': null,
      'street': null,
      'postalCode': null,
    };
  }

  // Get complete location data (position + address)
  Future<LocationData?> getCompleteLocationData() async {
    try {
      Position? position = await getCurrentPosition();
      if (position == null) return null;

      Map<String, String?> addressData = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: addressData['address'],
        city: addressData['city'],
        country: addressData['country'],
      );
    } catch (e) {
      AppLogger.error('Error getting complete location data', e);
      return null;
    }
  }

  // Open location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}

// Location data model
class LocationData {
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? country;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.country,
  });

  String get formattedCoordinates {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
}
