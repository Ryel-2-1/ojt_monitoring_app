import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/attendance_model.dart';
import '../models/offline_attendance_action.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/live_location_repository.dart';

class OfflineAttendanceQueueService {
  final AttendanceRepository attendanceRepository;
  final LiveLocationRepository liveLocationRepository;

  OfflineAttendanceQueueService({
    required this.attendanceRepository,
    required this.liveLocationRepository,
  });

  static const String _boxName = 'offline_attendance_queue';

  Box<Map>? _box;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  Future<void> init() async {
    _box ??= await Hive.openBox<Map>(_boxName);

    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any(
        (result) => result != ConnectivityResult.none,
      );

      if (hasNetwork) {
        syncPendingActions();
      }
    });

    await syncPendingActions();
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<int> pendingCount() async {
    final box = await _ensureBox();
    return box.length;
  }

  Future<List<OfflineAttendanceAction>> getPendingActions() async {
    final box = await _ensureBox();

    return box.values
        .map((raw) => OfflineAttendanceAction.fromMap(raw))
        .where((action) => action.id.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> enqueueClockOut({
    required String uid,
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    double? accuracy,
    String source = 'offline_clock_out',
  }) async {
    final box = await _ensureBox();

    final action = OfflineAttendanceAction(
      id: '${uid}_${DateTime.now().microsecondsSinceEpoch}',
      uid: uid,
      status: AttendanceStatus.clockOut,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      source: source,
      createdAt: DateTime.now(),
    );

    await box.put(action.id, action.toMap());

    debugPrint('Offline queue: saved ${action.status.value} for ${action.uid}');
  }

  Future<void> syncPendingActions() async {
    if (_isSyncing) return;

    _isSyncing = true;

    try {
      final box = await _ensureBox();
      final actions = await getPendingActions();

      for (final action in actions) {
        try {
          await _syncSingleAction(action);
          await box.delete(action.id);
          debugPrint('Offline queue: synced ${action.id}');
        } catch (e) {
          final failed = action.copyWith(
            syncAttempts: action.syncAttempts + 1,
            lastError: e.toString(),
          );

          await box.put(action.id, failed.toMap());
          debugPrint('Offline queue: failed to sync ${action.id}: $e');
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncSingleAction(OfflineAttendanceAction action) async {
    if (action.status != AttendanceStatus.clockOut) {
      throw Exception('Only offline clock-out is supported for now.');
    }

    final alreadySynced = await _alreadySynced(action.id);
    if (alreadySynced) return;

    await attendanceRepository.addRawAttendance(
      action.toFirestoreAttendanceMap(),
    );

    await liveLocationRepository.upsertLiveLocation(
      uid: action.uid,
      fullName: 'Intern',
      email: '',
      latitude: action.latitude,
      longitude: action.longitude,
      accuracy: action.accuracy ?? 0,
      isClockedIn: false,
      lastStatus: 'Offline Clock-Out Synced',
    );
  }

  Future<bool> _alreadySynced(String offlineActionId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('offlineActionId', isEqualTo: offlineActionId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<Box<Map>> _ensureBox() async {
    return _box ??= await Hive.openBox<Map>(_boxName);
  }
}
