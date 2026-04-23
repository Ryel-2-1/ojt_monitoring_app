import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../models/attendance_model.dart';
import '../models/live_location_model.dart';
import '../models/user_model.dart';

class LiveMonitoringScreen extends StatefulWidget {
  const LiveMonitoringScreen({super.key});

  @override
  State<LiveMonitoringScreen> createState() => _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends State<LiveMonitoringScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();

  String _selectedFilter = 'All Partner Companies';
  String _searchQuery = '';

  final List<String> _filters = const [
    'All Partner Companies',
    'Assigned Geofence Only',
    'Active Sessions Only',
  ];

  static const LatLng _fallbackCenter = LatLng(14.5995, 120.9842);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userRepo = AppServices.of(context).userRepository;
    final attendanceRepo = AppServices.of(context).attendanceRepository;
    final liveLocationRepo = AppServices.of(context).liveLocationRepository;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopToolbar(),
          const SizedBox(height: 18),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: userRepo.streamInternUsers(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (userSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load interns: ${userSnapshot.error}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.red[700],
                        fontSize: 13,
                      ),
                    ),
                  );
                }

                final users = userSnapshot.data ?? [];

                return StreamBuilder<Map<String, AttendanceModel>>(
                  stream: attendanceRepo.streamLatestLogsByUser(),
                  builder: (context, logSnapshot) {
                    if (logSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (logSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load activity: ${logSnapshot.error}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.red[700],
                            fontSize: 13,
                          ),
                        ),
                      );
                    }

                    final latestLogs = logSnapshot.data ?? {};

                    final activeUsers = users.where((user) {
                      final latest = latestLogs[user.uid];
                      return latest?.status == AttendanceStatus.clockIn;
                    }).toList();

                    final filteredActiveUsers = activeUsers.where((user) {
                      final q = _searchQuery.trim().toLowerCase();
                      final hasGeofence = user.assignedLatitude != null &&
                          user.assignedLongitude != null &&
                          user.allowedRadius != null;

                      if (_selectedFilter == 'Assigned Geofence Only' &&
                          !hasGeofence) {
                        return false;
                      }

                      if (q.isEmpty) return true;

                      return user.fullName.toLowerCase().contains(q) ||
                          user.email.toLowerCase().contains(q);
                    }).toList();

                    return StreamBuilder<List<LiveLocationModel>>(
                      stream: liveLocationRepo.streamActiveLocations(),
                      builder: (context, locationSnapshot) {
                        if (locationSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (locationSnapshot.hasError) {
                          return Center(
                            child: Text(
                              'Failed to load live locations: ${locationSnapshot.error}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Colors.red[700],
                              ),
                            ),
                          );
                        }

                        final allLocations = locationSnapshot.data ?? [];
                        final activeUids =
                            filteredActiveUsers.map((u) => u.uid).toSet();

                        final filteredLocations = allLocations.where((location) {
                          if (!activeUids.contains(location.uid)) return false;

                          final q = _searchQuery.trim().toLowerCase();
                          if (q.isEmpty) return true;

                          return location.fullName.toLowerCase().contains(q) ||
                              location.email.toLowerCase().contains(q);
                        }).toList();

                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFE7ECF3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 18, 14, 18),
                                  child: Column(
                                    children: [
                                      _buildMapHeaderCard(
                                          filteredLocations.length),
                                      const SizedBox(height: 16),
                                      Expanded(
                                        child: _buildLiveMapPanel(
                                          filteredLocations: filteredLocations,
                                          activeUsers: filteredActiveUsers,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                color: const Color(0xFFE7ECF3),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 18, 20, 18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildActiveSessionsHeader(
                                        filteredActiveUsers.length,
                                      ),
                                      const SizedBox(height: 14),
                                      Expanded(
                                        child: _buildActiveSessionsList(
                                          filteredActiveUsers,
                                          latestLogs,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildCoverageCard(
                                        activeCount:
                                            filteredActiveUsers.length,
                                        totalUsers: users.length,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            decoration: InputDecoration(
              hintText: 'Search students by name...',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey[500],
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: Colors.grey[500],
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE7ECF3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE7ECF3)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Text(
          'FILTER:',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 10),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedFilter,
            borderRadius: BorderRadius.circular(12),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0A2351),
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: _filters.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedFilter = value);
              }
            },
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
          color: const Color(0xFF6B7280),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.help_outline_rounded),
          color: const Color(0xFF6B7280),
        ),
        const SizedBox(width: 8),
        Text(
          'Live View',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D4DB3),
          ),
        ),
      ],
    );
  }

  Widget _buildMapHeaderCard(int activeCount) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.radar_rounded,
              size: 18,
              color: const Color(0xFF0D4DB3),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVE PINGS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$activeCount Students',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0A2351),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMapPanel({
    required List<LiveLocationModel> filteredLocations,
    required List<UserModel> activeUsers,
  }) {
    final center = filteredLocations.isNotEmpty
        ? LatLng(
            filteredLocations.first.latitude,
            filteredLocations.first.longitude,
          )
        : _fallbackCenter;

    final markers = filteredLocations.map((item) {
      return Marker(
        point: LatLng(item.latitude, item.longitude),
        width: 130,
        height: 78,
        child: _buildMapMarker(item),
      );
    }).toList();

    final geofenceCircles = activeUsers
        .where((user) =>
            user.assignedLatitude != null &&
            user.assignedLongitude != null &&
            user.allowedRadius != null)
        .map(
          (user) => CircleMarker(
            point: LatLng(
              user.assignedLatitude!,
              user.assignedLongitude!,
            ),
            radius: user.allowedRadius!,
            useRadiusInMeter: true,
            color: const Color(0xFF0D4DB3).withOpacity(0.12),
            borderStrokeWidth: 2,
            borderColor: const Color(0xFF0D4DB3).withOpacity(0.60),
          ),
        )
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: filteredLocations.isNotEmpty ? 16 : 6,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.ojt_monitoring_app',
                ),
                CircleLayer(circles: geofenceCircles),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          if (filteredLocations.isEmpty)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.55),
                child: Center(
                  child: Text(
                    'No live location updates yet.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 14,
            bottom: 14,
            child: Column(
              children: [
                _buildControlButton(
                  icon: Icons.add_rounded,
                  onTap: () {
                    final current = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      current + 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildControlButton(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    final current = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      current - 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildControlButton(
                  icon: Icons.my_location_rounded,
                  filled: true,
                  onTap: () {
                    if (filteredLocations.isNotEmpty) {
                      _mapController.move(
                        LatLng(
                          filteredLocations.first.latitude,
                          filteredLocations.first.longitude,
                        ),
                        16,
                      );
                    } else {
                      _mapController.move(_fallbackCenter, 6);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapMarker(LiveLocationModel item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 110),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            item.fullName,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0A2351),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF0D4DB3),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D4DB3).withOpacity(0.25),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF0D4DB3) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled
                ? const Color(0xFF0D4DB3)
                : const Color(0xFFE7ECF3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 22,
          color: filled ? Colors.white : const Color(0xFF0A2351),
        ),
      ),
    );
  }

  Widget _buildActiveSessionsHeader(int count) {
    return Row(
      children: [
        Text(
          'Active Sessions',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0A2351),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count LIVE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0D4DB3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSessionsList(
    List<UserModel> activeUsers,
    Map<String, AttendanceModel> latestLogs,
  ) {
    if (activeUsers.isEmpty) {
      return Center(
        child: Text(
          'No active sessions right now.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.grey[500],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: activeUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = activeUsers[index];
        final latest = latestLogs[user.uid];
        final sessionText = latest == null
            ? '--:--:--'
            : _formatElapsed(DateTime.now().difference(latest.timestamp));

        final hasGeofence = user.assignedLatitude != null &&
            user.assignedLongitude != null &&
            user.allowedRadius != null;

        return _buildSessionCard(
          initials: _initialsOf(user.fullName),
          name: user.fullName,
          company: hasGeofence ? 'Geofence Configured' : user.email,
          timeLabel: sessionText,
          statusColor: const Color(0xFF14A44D),
        );
      },
    );
  }

  Widget _buildSessionCard({
    required String initials,
    required String name,
    required String company,
    required String timeLabel,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE8F0FF),
                child: Text(
                  initials,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D4DB3),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C2434),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  company,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverageCard({
    required int activeCount,
    required int totalUsers,
  }) {
    final double coverage = totalUsers == 0 ? 0 : activeCount / totalUsers;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D4DB3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL COVERAGE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(coverage * 100).toStringAsFixed(1)}%',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Sync Status',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              Text(
                activeCount > 0 ? 'Live' : 'Idle',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: coverage.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFF6E92D8),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _formatElapsed(Duration duration) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(duration.inHours)}:${pad(duration.inMinutes.remainder(60))}:${pad(duration.inSeconds.remainder(60))}';
  }
}