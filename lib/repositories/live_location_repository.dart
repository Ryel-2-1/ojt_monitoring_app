import '../models/live_location_model.dart';
import '../services/firestore_service.dart';

class LiveLocationRepository {
  final FirestoreService _firestoreService;

  LiveLocationRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _collection = 'live_locations';

  Future<void> upsertLiveLocation({
    required String uid,
    required String fullName,
    required String email,
    required double latitude,
    required double longitude,
    required double accuracy,
    required bool isClockedIn,
    required String lastStatus,
  }) async {
    try {
      final location = LiveLocationModel(
        uid: uid,
        fullName: fullName,
        email: email,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        isClockedIn: isClockedIn,
        updatedAt: DateTime.now(),
        lastStatus: lastStatus,
      );

      await _firestoreService.setDocument(
        path: _collection,
        docId: uid,
        data: location.toMap(),
        merge: true,
      );
    } catch (e) {
      throw Exception('Failed to update live location: $e');
    }
  }

  Future<void> setClockedOut(String uid) async {
    try {
      await _firestoreService.updateDocument(
        path: _collection,
        docId: uid,
        data: {
          'isClockedIn': false,
          'lastStatus': 'Clock-Out',
        },
      );
    } catch (e) {
      throw Exception('Failed to mark live location as clocked out: $e');
    }
  }

  Stream<List<LiveLocationModel>> streamActiveLocations() {
    return _firestoreService
        .collection(_collection)
        .where('isClockedIn', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LiveLocationModel.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }

  Stream<List<LiveLocationModel>> streamAllLocations() {
    return _firestoreService
        .collection(_collection)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LiveLocationModel.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }
}