class GeofenceSettings {
  final String uid;
  final double latitude;
  final double longitude;
  final double radiusInMeters;

  GeofenceSettings({
    required this.uid,
    required this.latitude,
    required this.longitude,
    required this.radiusInMeters,
  });
}

class GeofenceNotAssignedException implements Exception {
  final String message;
  GeofenceNotAssignedException([this.message = 'A Supervisor must assign your location before you can clock in.']);
  @override
  String toString() => message;
}