import 'package:intl/intl.dart';

class ScanLog {
  final int? id;
  final String uid;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;
  final String? userName;
  final String? userClass;
  final String? deviceInfo;
  final bool isSynced;

  ScanLog({
    this.id,
    required this.uid,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.userName,
    this.userClass,
    this.deviceInfo,
    this.isSynced = false,
  });

  // Convert ScanLog to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'user_name': userName,
      'user_class': userClass,
      'device_info': deviceInfo,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  // Create ScanLog from Map (database)
  factory ScanLog.fromMap(Map<String, dynamic> map) {
    return ScanLog(
      id: map['id'] as int?,
      uid: map['uid'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      userName: map['user_name'] as String?,
      userClass: map['user_class'] as String?,
      deviceInfo: map['device_info'] as String?,
      isSynced: map['isSynced'] == 1,
    );
  }

  // Convert to CSV row
  List<String> toCsvRow() {
    final formattedTimestamp =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp.toLocal());
    return [
      uid,
      userName ?? '',
      userClass ?? '',
      deviceInfo ?? '',
      formattedTimestamp,
      latitude?.toString() ?? '',
      longitude?.toString() ?? '',
      address ?? '',
      city ?? '',
      isSynced ? 'Yes' : 'No',
    ];
  }

  // Copy with method for updating fields
  ScanLog copyWith({
    int? id,
    String? uid,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? userName,
    String? userClass,
    String? deviceInfo,
    bool? isSynced,
  }) {
    return ScanLog(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      userName: userName ?? this.userName,
      userClass: userClass ?? this.userClass,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  String get formattedCoordinates {
    if (latitude == null || longitude == null) return 'Unknown';
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }
}
