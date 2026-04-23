import 'package:cloud_firestore/cloud_firestore.dart';

class LiveLocationModel {
  final String uid;
  final String fullName;
  final String email;
  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isClockedIn;
  final DateTime updatedAt;
  final String lastStatus;

  const LiveLocationModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isClockedIn,
    required this.updatedAt,
    required this.lastStatus,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'fullName': fullName,
        'email': email,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'isClockedIn': isClockedIn,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastStatus': lastStatus,
      };

  factory LiveLocationModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawUpdatedAt = map['updatedAt'];

    return LiveLocationModel(
      uid: id ?? map['uid'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      accuracy: (map['accuracy'] ?? 0).toDouble(),
      isClockedIn: map['isClockedIn'] ?? false,
      updatedAt: rawUpdatedAt is Timestamp
          ? rawUpdatedAt.toDate()
          : DateTime.now(),
      lastStatus: map['lastStatus'] ?? '',
    );
  }

  LiveLocationModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    double? latitude,
    double? longitude,
    double? accuracy,
    bool? isClockedIn,
    DateTime? updatedAt,
    String? lastStatus,
  }) {
    return LiveLocationModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      isClockedIn: isClockedIn ?? this.isClockedIn,
      updatedAt: updatedAt ?? this.updatedAt,
      lastStatus: lastStatus ?? this.lastStatus,
    );
  }
}