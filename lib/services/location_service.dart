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
        AppLogger.warning('Location services are disabled');
        throw Exception('Location services are disabled');
      }

      // Check permission
      bool hasPerms = await hasPermission();
      if (!hasPerms) {
        hasPerms = await requestPermission();
        if (!hasPerms) {
          AppLogger.warning('Location permission denied');
          throw Exception('Location permission denied');
        }
      }

      AppLogger.info('Attempting to get high accuracy position...');
      
      // Try high accuracy first with shorter timeout
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        ).timeout(
          const Duration(seconds: 15),
        );
        AppLogger.info('Got high accuracy position');
        return position;
      } catch (e) {
        AppLogger.warning('High accuracy timeout, trying low accuracy...');
        
        // Fallback to low accuracy (network-based)
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 10),
          ).timeout(
            const Duration(seconds: 10),
          );
          AppLogger.info('Got low accuracy position');
          return position;
        } catch (e2) {
          AppLogger.warning('Low accuracy also failed, trying last known position...');
          
          // Last resort: get last known position
          final lastPosition = await Geolocator.getLastKnownPosition();
          if (lastPosition != null) {
            AppLogger.info('Using last known position');
            return lastPosition;
          }
          throw Exception('Unable to get any location');
        }
      }
    } catch (e) {
      AppLogger.error('Error getting location', e);
      return null;
    }
  }

  // Get address from coordinates (reverse geocoding)
  Future<Map<String, String?>> getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      AppLogger.info('Starting reverse geocoding for: $latitude, $longitude');
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        AppLogger.info('Geocoding result - Locality: ${place.locality}, SubLocality: ${place.subLocality}, SubAdminArea: ${place.subAdministrativeArea}, AdminArea: ${place.administrativeArea}, Country: ${place.country}');
        
        String? fullAddress = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((s) => s != null && s.isNotEmpty).join(', ');

        // Determine city name: prefer subAdministrativeArea else fallback to locality directly
        String? cityName;
        if (place.subAdministrativeArea != null && place.subAdministrativeArea!.trim().isNotEmpty) {
          cityName = place.subAdministrativeArea!.trim();
        } else if (place.locality != null && place.locality!.trim().isNotEmpty) {
          cityName = place.locality!.trim();
        }

        return {
          'address': fullAddress.isEmpty ? null : fullAddress,
          'city': cityName,
          'country': place.country,
          'street': place.street,
          'postalCode': place.postalCode,
        };
      } else {
        AppLogger.warning('No placemarks found for coordinates');
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
      AppLogger.info('Getting complete location data...');
      Position? position = await getCurrentPosition();
      if (position == null) {
        AppLogger.warning('Position is null');
        return null;
      }

      AppLogger.info('Position obtained: ${position.latitude}, ${position.longitude}');
      Map<String, String?> addressData = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final locationData = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: addressData['address'],
        city: addressData['city'],
        country: addressData['country'],
      );
      
      AppLogger.info('Location data complete - City: ${locationData.city}, Address: ${locationData.address}');
      return locationData;
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

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lon: $longitude, city: ${city ?? 'null'}, address: ${address ?? 'null'}, country: ${country ?? 'null'})';
  }

  String get formattedCoordinates {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
}
