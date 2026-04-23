import '../models/attendance_model.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRepository {
  final FirestoreService _firestoreService;

  AttendanceRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _collection = 'attendance';

  // ─────────────────────────────────────────────
  // LOG ATTENDANCE (Clock-In / Clock-Out)
  // ─────────────────────────────────────────────

  Stream<Map<String, AttendanceModel>> streamLatestLogsByUser() {
  return _firestoreService
      .collection(_collection)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) {
    final Map<String, AttendanceModel> latestByUser = {};

    for (final doc in snapshot.docs) {
      final model = AttendanceModel.fromMap(doc.data(), id: doc.id);

      // Since docs are already ordered DESC by timestamp,
      // the first log we see for a uid is the latest one.
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

  // ─────────────────────────────────────────────
  // GET ALL ATTENDANCE (History)
  // ─────────────────────────────────────────────
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

  // ─────────────────────────────────────────────
  // STREAM ALL ATTENDANCE (Realtime)
  // ─────────────────────────────────────────────
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

  // ─────────────────────────────────────────────
  // GET TODAY'S ATTENDANCE
  // ─────────────────────────────────────────────
  Future<List<AttendanceModel>> getTodayAttendance(String uid) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final snapshot = await _firestoreService
        .collection(_collection)
        .where('uid', isEqualTo: uid)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => AttendanceModel.fromMap(doc.data(), id: doc.id))
        .toList();
  }

  // ─────────────────────────────────────────────
  // CHECK IF CURRENTLY CLOCKED IN
  // ─────────────────────────────────────────────
  Future<bool> isCurrentlyClockedIn(String uid) async {
    final todayLogs = await getTodayAttendance(uid);
    if (todayLogs.isEmpty) return false;
    return todayLogs.first.status == AttendanceStatus.clockIn;
  }

  // ─────────────────────────────────────────────
  // STREAM WEEKLY TOTAL HOURS (FOR DASHBOARD)
  // ─────────────────────────────────────────────
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

  // ─────────────────────────────────────────────
  // STREAM LATEST LOG (for dashboard live status)
  // ─────────────────────────────────────────────
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

  // ─────────────────────────────────────────────
  // GET CURRENT WEEK LOGS
  // ─────────────────────────────────────────────
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
