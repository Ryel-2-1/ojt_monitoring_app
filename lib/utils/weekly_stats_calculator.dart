import '../models/attendance_model.dart';

class WeeklyStats {
  final Duration totalHours;
  final int totalSessions;  // number of completed Clock-In → Clock-Out pairs
  final double approvalRate; // completed pairs / total clock-in events × 100

  const WeeklyStats({
    required this.totalHours,
    required this.totalSessions,
    required this.approvalRate,
  });

  /// Formatted as "Xh Ym" — e.g. "6h 42m"
  String get formattedHours {
    final int h = totalHours.inHours;
    final int m = totalHours.inMinutes.remainder(60);
    return '${h}h ${m}m';
  }

  /// Formatted as "XX.X%" — e.g. "87.5%"
  String get formattedApprovalRate =>
      '${approvalRate.toStringAsFixed(1)}%';
}

class WeeklyStatsCalculator {
  /// Pairs every Clock-In with the next Clock-Out for the same [uid],
  /// sums the durations, and computes a completion rate.
  ///
  /// Logs must be pre-sorted ascending by timestamp (the repository query
  /// already guarantees this via orderBy).
  static WeeklyStats calculate(List<AttendanceModel> logs) {
    Duration total = Duration.zero;
    int completedPairs = 0;
    int clockInCount = 0;

    DateTime? openClockIn;

    for (final AttendanceModel log in logs) {
      if (log.status == AttendanceStatus.clockIn) {
        clockInCount++;
        openClockIn = log.timestamp;
      } else if (log.status == AttendanceStatus.clockOut &&
          openClockIn != null) {
        total += log.timestamp.difference(openClockIn);
        completedPairs++;
        openClockIn = null; // close the pair
      }
    }

    final double rate = clockInCount == 0
        ? 0.0
        : (completedPairs / clockInCount) * 100;

    return WeeklyStats(
      totalHours: total,
      totalSessions: completedPairs,
      approvalRate: rate,
    );
  }
}