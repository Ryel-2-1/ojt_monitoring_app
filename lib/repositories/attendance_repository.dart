import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_model.dart';
import '../services/firestore_service.dart';

class AttendanceTransitionException implements Exception {
  final String message;

  const AttendanceTransitionException(this.message);

  @override
  String toString() => message;
}

class AttendanceRepository {
  final FirestoreService _firestoreService;

  AttendanceRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _collection = 'attendance';

  Stream<Map<String, AttendanceModel>> streamLatestLogsByUser() {
    return _firestoreService
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final Map<String, AttendanceModel> latestByUser = {};

      for (final doc in snapshot.docs) {
        final model = AttendanceModel.fromMap(doc.data(), id: doc.id);
        latestByUser.putIfAbsent(model.uid, () => model);
      }

      return latestByUser;
    });
  }

  Stream<List<AttendanceModel>> streamAllAttendanceLogs() {
    return _firestoreService
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AttendanceModel.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }

 Future<String> logAttendance({
  required String uid,
  required AttendanceStatus status,
  GeoPoint? locationCoords,
}) async {
  await _validateAttendanceTransition(uid: uid, nextStatus: status);

  final log = AttendanceModel(
    uid: uid,
    timestamp: DateTime.now(),
    status: status,
    locationCoords: locationCoords,
  );

  return await _firestoreService.addDocument(
    path: _collection,
    data: log.toMap(),
  );
}


  Future<void> _validateAttendanceTransition({
    required String uid,
    required AttendanceStatus nextStatus,
  }) async {
    final latestLog = await getLatestLog(uid);

    if (nextStatus == AttendanceStatus.clockIn) {
      if (latestLog?.status == AttendanceStatus.clockIn) {
        throw const AttendanceTransitionException(
          'You are already clocked in. Please clock out before starting a new session.',
        );
      }

      return;
    }

    if (nextStatus == AttendanceStatus.clockOut) {
      if (latestLog == null || latestLog.status != AttendanceStatus.clockIn) {
        throw const AttendanceTransitionException(
          'No active clock-in session found. Please clock in first.',
        );
      }

      return;
    }
  }

  Future<AttendanceModel?> getLatestLog(String uid) async {
    final snapshot = await _firestoreService
        .collection(_collection)
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return AttendanceModel.fromMap(doc.data(), id: doc.id);
  }

  Future<List<AttendanceModel>> getAttendanceByStudent(String uid) async {
    final snapshot = await _firestoreService
        .collection(_collection)
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => AttendanceModel.fromMap(doc.data(), id: doc.id))
        .toList();
  }

  Stream<List<AttendanceModel>> streamAttendanceByStudent(String uid) {
    return _firestoreService
        .collection(_collection)
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AttendanceModel.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }

  Future<List<AttendanceModel>> getTodayAttendance(String uid) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final snapshot = await _firestoreService
        .collection(_collection)
        .where('uid', isEqualTo: uid)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => AttendanceModel.fromMap(doc.data(), id: doc.id))
        .toList();
  }

  Future<bool> isCurrentlyClockedIn(String uid) async {
    final latestLog = await getLatestLog(uid);
    return latestLog?.status == AttendanceStatus.clockIn;
  }

  Stream<double> watchWeeklyTotal(String uid) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startTimestamp = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    return _firestoreService
        .collection(_collection)
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      final logs = snapshot.docs
          .map((doc) => AttendanceModel.fromMap(doc.data(), id: doc.id))
          .where((log) => !log.timestamp.isBefore(startTimestamp))
          .toList();

      double totalHours = 0;
      DateTime? lastClockIn;

      for (final log in logs) {
        if (log.status == AttendanceStatus.clockIn) {
          lastClockIn = log.timestamp;
        } else if (log.status == AttendanceStatus.clockOut &&
            lastClockIn != null) {
          totalHours +=
              log.timestamp.difference(lastClockIn).inMinutes / 60.0;
          lastClockIn = null;
        }
      }

      return totalHours;
    });
  }

  Stream<AttendanceModel?> watchLatestLog(String uid) {
    return _firestoreService
        .collection(_collection)
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return AttendanceModel.fromMap(doc.data(), id: doc.id);
    });
  }

  Future<List<AttendanceModel>> getLogsForCurrentWeek(String uid) async {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final snapshot = await _firestoreService
        .collection(_collection)
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => AttendanceModel.fromMap(doc.data(), id: doc.id))
        .where((log) => !log.timestamp.isBefore(startOfWeek))
        .toList();
  }
}