// lib/services/location_service.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_model.dart';
import '../repositories/attendance_repository.dart';

// ─────────────────────────────────────────────
// Custom Exceptions
// ─────────────────────────────────────────────

class LocationPermissionDeniedException implements Exception {
  final String message;
  const LocationPermissionDeniedException(
      [this.message = 'Location permission was denied.']);
  @override
  String toString() => message;
}

class LocationServiceDisabledException implements Exception {
  final String message;
  const LocationServiceDisabledException(
      [this.message = 'GPS / Location services are disabled on this device.']);
  @override
  String toString() => message;
}

class OutsideGeofenceException implements Exception {
  final String message;
  final double distanceInMeters;
  const OutsideGeofenceException({
    required this.distanceInMeters,
    this.message = 'You are outside the allowed check-in zone.',
  });
  @override
  String toString() =>
      '$message (${distanceInMeters.toStringAsFixed(0)}m away from zone)';
}

// ─────────────────────────────────────────────
// LocationService
// ─────────────────────────────────────────────

class LocationService {
  final AttendanceRepository _attendanceRepository;

  LocationService({required AttendanceRepository attendanceRepository})
      : _attendanceRepository = attendanceRepository {
    assert(!kIsWeb, 'LocationService must only be used on the mobile platform.');
  }

  // ── 1. Permission Handling ─────────────────────────────────────────

  /// Checks and requests GPS permissions.
  /// Throws [LocationServiceDisabledException] if GPS hardware is off.
  /// Throws [LocationPermissionDeniedException] if user denies.
  Future<void> ensurePermissions() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionDeniedException(
            'Location permission was denied by the user.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException(
          'Location permission is permanently denied. Please enable it in app settings.');
    }
  }

  // ── 2. Location Fetching ───────────────────────────────────────────

  /// Returns the device's current [Position] with high accuracy.
  /// Always call [ensurePermissions] before this.
  Future<Position> getCurrentPosition() async {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  // ── 3. Geofence Validation ─────────────────────────────────────────

  /// Returns the straight-line distance in meters from [userPosition]
  /// to the target coordinate. Used both for the boolean check and
  /// for surfacing a human-readable "Xm away" message in the UI.
  double getDistanceToTarget({
    required Position userPosition,
    required double targetLatitude,
    required double targetLongitude,
  }) {
    return Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      targetLatitude,
      targetLongitude,
    );
  }

  /// Returns `true` if [userPosition] is within [radiusInMeters] of the target.
  bool isWithinGeofence({
    required Position userPosition,
    required double targetLatitude,
    required double targetLongitude,
    required double radiusInMeters,
  }) {
    return getDistanceToTarget(
          userPosition: userPosition,
          targetLatitude: targetLatitude,
          targetLongitude: targetLongitude,
        ) <=
        radiusInMeters;
  }

  // ── 4. verifyAndClockIn ────────────────────────────────────────────

  /// Orchestrates the full clock-in / clock-out flow:
  ///   1. Ensure GPS permissions are granted.
  ///   2. Fetch the current device position.
  ///   3. Validate the intern is within the assigned geofence.
  ///   4. Write the attendance log via [AttendanceRepository].
  ///   5. Return the confirmed [DateTime] from the written log so the
  ///      caller can anchor its live timer to the server-side record.
  ///
  /// Throws:
  ///   - [LocationServiceDisabledException]  → GPS hardware is off.
  ///   - [LocationPermissionDeniedException] → Permission denied or permanent.
  ///   - [OutsideGeofenceException]          → Intern is outside the zone.
  Future<DateTime> verifyAndClockIn({
    required String uid,
    required AttendanceStatus status,
    required double targetLatitude,
    required double targetLongitude,
    double radiusInMeters = 200.0,
  }) async {
    // Step 1 — Permissions
    await ensurePermissions();

    // Step 2 — Fetch position
    final Position position = await getCurrentPosition();

    // Step 3 — Geofence check
    final double distance = getDistanceToTarget(
      userPosition: position,
      targetLatitude: targetLatitude,
      targetLongitude: targetLongitude,
    );

    if (distance > radiusInMeters) {
      throw OutsideGeofenceException(distanceInMeters: distance);
    }

    // Step 4 — Write to Firestore
    // Capture the local time immediately before the write so the returned
    // timestamp closely matches the server timestamp (within network latency).
    // We do NOT use DateTime.now() after the await — that would include
    // the full round-trip delay.
    final DateTime clockedAt = DateTime.now();

    await _attendanceRepository.logAttendance(
      uid: uid,
      status: status,
      locationCoords: GeoPoint(position.latitude, position.longitude),
    );

    // Step 5 — Return the timestamp so the UI can anchor its live timer
    // to this moment rather than a second call to DateTime.now().
    return clockedAt;
  }
}
