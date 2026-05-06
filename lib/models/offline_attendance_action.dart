import 'package:cloud_firestore/cloud_firestore.dart';

import 'attendance_model.dart';

class OfflineAttendanceAction {
  final String id;
  final String uid;
  final AttendanceStatus status;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String source;
  final DateTime createdAt;
  final int syncAttempts;
  final String? lastError;

  const OfflineAttendanceAction({
    required this.id,
    required this.uid,
    required this.status,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.source = 'offline_clock_out',
    required this.createdAt,
    this.syncAttempts = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'status': status.value,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
      'syncAttempts': syncAttempts,
      'lastError': lastError,
    };
  }

  Map<String, dynamic> toFirestoreAttendanceMap() {
    return {
      'uid': uid,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.value,
      'location_coords': GeoPoint(latitude, longitude),
      'source': source,
      'syncedFromOfflineQueue': true,
      'offlineActionId': id,
      'offlineCreatedAt': Timestamp.fromDate(createdAt),
      'syncedAt': FieldValue.serverTimestamp(),
    };
  }

  factory OfflineAttendanceAction.fromMap(Map<dynamic, dynamic> map) {
    return OfflineAttendanceAction(
      id: map['id']?.toString() ?? '',
      uid: map['uid']?.toString() ?? '',
      status: AttendanceStatusExtension.fromString(
        map['status']?.toString() ?? 'Clock-Out',
      ),
      timestamp:
          DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      accuracy: _toNullableDouble(map['accuracy']),
      source: map['source']?.toString() ?? 'offline_clock_out',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      syncAttempts: _toInt(map['syncAttempts']),
      lastError: map['lastError']?.toString(),
    );
  }

  OfflineAttendanceAction copyWith({int? syncAttempts, String? lastError}) {
    return OfflineAttendanceAction(
      id: id,
      uid: uid,
      status: status,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      source: source,
      createdAt: createdAt,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastError: lastError ?? this.lastError,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
